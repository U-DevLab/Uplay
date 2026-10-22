-- ============================================================
--  U-Play (client)
--  Screen (NUI) + playback with xsound
-- ============================================================

local isOpen = false
local clockOffset = 0

-- ------------------------------------------------------------
--  Reloj compartido con el servidor
-- ------------------------------------------------------------
local clockSet = false
local function updateClock(value)
    if not value then return end
    local nuevo = value - GetCloudTimeAsInt()
    if not clockSet or math.abs(nuevo - clockOffset) > 2 then
        clockOffset = nuevo
        clockSet = true
    end
end
updateClock(GlobalState.uplayClock)
AddStateBagChangeHandler('uplayClock', 'global', function(_, _, value) updateClock(value) end)

local function serverNow()
    return GetCloudTimeAsInt() + clockOffset
end

-- ------------------------------------------------------------
--  Utilidades
-- ------------------------------------------------------------
local function notify(text, nType)
    lib.notify({ title = 'U-Play', description = text, type = nType or 'inform' })
end

-- Devuelve el carro si vas de conductor o copiloto
local function controlVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return nil end
    if GetPedInVehicleSeat(veh, -1) ~= ped and GetPedInVehicleSeat(veh, 0) ~= ped then return nil end
    return veh
end

local function close()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    -- Evita que el ESC con el que cerraste abra también el menú de pausa
    CreateThread(function()
        local hasta = GetGameTimer() + 600
        while GetGameTimer() < hasta do
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 199, true)
            Wait(0)
        end
    end)
end

-- ------------------------------------------------------------
--  Abrir
-- ------------------------------------------------------------
local function open()
    if isOpen then return close() end
    if not controlVehicle() then return notify(L('not_in_seat'), 'error') end

    local state = lib.callback.await('uplay:getState', false)
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', state = state, locale = UILocale() })

    -- Cerrar si te bajas o te cambias de asiento
    CreateThread(function()
        while isOpen do
            if not controlVehicle() then close() end
            Wait(500)
        end
    end)
end

RegisterCommand(Config.Command, open, false)
RegisterCommand('uplay_key', open, false)
RegisterKeyMapping('uplay_key', L('key_desc'), 'keyboard', Config.DefaultKey or '')

-- ------------------------------------------------------------
--  Pantalla -> juego
-- ------------------------------------------------------------
RegisterNUICallback('close', function(_, cb)
    close()
    cb('ok')
end)

RegisterNUICallback('search', function(data, cb)
    local res = lib.callback.await('uplay:search', false, data and data.q or '')
    cb(res or { error = L('search_error') })
end)

RegisterNUICallback('action', function(data, cb)
    local res = lib.callback.await('uplay:action', false, data.action, data.data)
    if res and res.error then notify(res.error, 'error') end
    cb(res or {})
end)

RegisterNetEvent('uplay:client:state', function(state)
    SendNUIMessage({ action = 'state', state = state })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)

-- ------------------------------------------------------------
--  Reproducción (todos los jugadores cerca del carro la oyen)
-- ------------------------------------------------------------
-- Optimizado: busca carros con música 1 vez por segundo, mueve el sonido
-- 4 veces por segundo solo si el carro se movió, y reacciona al momento
-- cuando cambia la canción, la pausa o el volumen (statebag).
local sounds = {}  -- [netId] = { id, name, veh, started, createdAt, reported, lastSync, seq, volume, paused, pos, durationSent }

local function xs(fn, ...)
    local ok, res = pcall(function(...) return exports.xsound[fn](exports.xsound, ...) end, ...)
    if ok then return res end
    return nil
end

local function dbg(...)
    if Config.Debug then print('^5[U-Play]^7', ...) end
end

local function seekTo(name, from, to, why)
    dbg(('salto %s: %.1fs -> %.1fs'):format(why, from or -1, to))
    xs('setTimeStamp', name, to)
end

local function destroySound(netId)
    local s = sounds[netId]
    if not s then return end
    dbg('sonido destruido', s.name)
    xs('Destroy', s.name)
    sounds[netId] = nil
end

local function expectedPos(st)
    if st.pausedPos then return st.pausedPos end
    return math.max(0, serverNow() - (st.startedAt or 0))
end

local function createSound(netId, veh, st)
    local name = 'uplay_' .. netId
    if xs('soundExists', name) then xs('Destroy', name) end

    local coords = GetEntityCoords(veh)
    local s = { id = st.id, name = name, veh = veh, started = false, createdAt = GetGameTimer(), reported = false,
                lastSync = GetGameTimer(), seq = st.seq, volume = st.volume, paused = st.pausedPos ~= nil, pos = coords }
    sounds[netId] = s

    local pos = expectedPos(st)
    if st.duration and st.duration > 0 and pos >= st.duration then return end -- ya terminó

    dbg('nueva cancion', st.id)
    xs('PlayUrlPos', name, 'https://www.youtube.com/watch?v=' .. st.id, (st.volume or 50) / 100, coords, false)
    xs('Distance', name, Config.SoundDistance)

    xs('onPlayStart', name, function()
        s.started = true
        local current = Entity(veh).state.uplay
        if not current or current.id ~= s.id then return end
        local p = expectedPos(current)
        if p > 2 then seekTo(name, 0, p, 'al empezar (entraste con la cancion ya sonando)') end
        if current.pausedPos then xs('Pause', name) end
    end)
end

-- Aplica cambios de canción / pausa / volumen / adelantar (solo cuando cambian)
local function applyState(netId, veh, st)
    local s = sounds[netId]
    if not s or s.id ~= st.id then
        destroySound(netId)
        return createSound(netId, veh, st)
    end
    if not s.started then return end

    if s.volume ~= st.volume then
        s.volume = st.volume
        xs('setVolumeMax', s.name, (st.volume or 50) / 100)
    end

    local paused = st.pausedPos ~= nil
    if paused ~= s.paused then
        s.paused = paused
        if paused then xs('Pause', s.name) else xs('Resume', s.name) end
    end

    if s.seq ~= st.seq then
        s.seq = st.seq
        s.lastSync = GetGameTimer()
        if not paused then
            local cur = xs('getTimeStamp', s.name)
            local exp = expectedPos(st)
            if cur and math.abs(cur - exp) > 1.5 then seekTo(s.name, cur, exp, 'por cambio (pausa/adelantar/cancion)') end
        end
    end
end

-- Revisiones lentas (1 vez por segundo)
local function slowCheck(netId, veh, st)
    local s = sounds[netId]
    if not s then return end
    local isController = controlVehicle() == veh

    if not s.started then
        if xs('isPlaying', s.name) or (xs('getTimeStamp', s.name) or 0) > 0 then
            s.started = true
            s.paused = false
            applyState(netId, veh, st)
        elseif not s.reported and isController and GetGameTimer() - s.createdAt > 20000 then
            -- No arrancó en 20 s: el video está bloqueado fuera de YouTube
            s.reported = true
            TriggerServerEvent('uplay:server:failed', netId, st.id)
        end
        return
    end

    -- Duración desconocida (link sin clave): la reporta el conductor/copiloto
    if not s.durationSent and (st.duration or 0) == 0 and isController then
        local d = xs('getMaxDuration', s.name)
        if d and d > 0 then
            s.durationSent = true
            TriggerServerEvent('uplay:server:duration', netId, st.id, d)
        end
    end

    -- (Sin revisión periódica: movía la canción cada 15 s. Solo se sincroniza al empezar,
    --  al pausar, al adelantar o al cambiar de canción.)
end

-- Cambios al momento (alguien pausó, adelantó, cambió canción o volumen)
AddStateBagChangeHandler('uplay', nil, function(bagName, _, value)
    local veh = GetEntityFromStateBagName(bagName)
    if veh == 0 then return end
    local netId = NetworkGetEntityIsNetworked(veh) and NetworkGetNetworkIdFromEntity(veh)
    if not netId or not sounds[netId] then return end
    if not value or not value.id then
        destroySound(netId)
        return
    end
    SetTimeout(0, function() applyState(netId, veh, value) end)
end)

-- Buscar carros con música cerca (1 vez por segundo)
CreateThread(function()
    while GetResourceState('xsound') ~= 'started' do Wait(1000) end
    while true do
        local myCoords = GetEntityCoords(PlayerPedId())
        local range = Config.SoundDistance + 15.0
        local seen = {}

        for _, veh in ipairs(GetGamePool('CVehicle')) do
            local st = Entity(veh).state.uplay
            if st and st.id and NetworkGetEntityIsNetworked(veh) and #(GetEntityCoords(veh) - myCoords) <= range then
                local netId = NetworkGetNetworkIdFromEntity(veh)
                seen[netId] = true
                local s = sounds[netId]
                if not s or s.id ~= st.id or s.veh ~= veh then
                    applyState(netId, veh, st)
                else
                    slowCheck(netId, veh, st)
                end
            end
        end

        for netId in pairs(sounds) do
            if not seen[netId] then destroySound(netId) end
        end

        Wait(1000)
    end
end)

-- Mover el sonido con el carro.
-- El carro en el que vas: 20 veces por segundo (si no, a alta velocidad el volumen sube y baja).
-- Los demás carros: 4 veces por segundo. Solo si el carro se movió.
CreateThread(function()
    local tick = 0
    while true do
        if next(sounds) then
            tick = tick + 1
            local myVeh = GetVehiclePedIsIn(PlayerPedId(), false)
            for netId, s in pairs(sounds) do
                if DoesEntityExist(s.veh) then
                    if s.veh == myVeh or tick % 5 == 0 then
                        local c = GetEntityCoords(s.veh)
                        if #(c - s.pos) > 0.3 then
                            s.pos = c
                            xs('Position', s.name, c)
                        end
                    end
                else
                    destroySound(netId)
                end
            end
            Wait(50)
        else
            tick = 0
            Wait(1000)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for netId in pairs(sounds) do destroySound(netId) end
end)
