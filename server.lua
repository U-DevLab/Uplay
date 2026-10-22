-- ============================================================
--  U-Play (server)
--  Searches YouTube (optional API key) and controls what plays in
--  each car. Clients only play what the server says.
-- ============================================================

-- Nombre del personaje según el framework (ESX / QBCore / Qbox / standalone)
local function playerName(src)
    if GetResourceState('es_extended') == 'started' then
        local ok, name = pcall(function()
            local xPlayer = exports['es_extended']:getSharedObject().GetPlayerFromId(src)
            return xPlayer and xPlayer.getName()
        end)
        if ok and name then return name end
    end
    if GetResourceState('qbx_core') == 'started' then
        local ok, name = pcall(function()
            local p = exports.qbx_core:GetPlayer(src)
            local c = p and p.PlayerData.charinfo
            return c and (c.firstname .. ' ' .. c.lastname)
        end)
        if ok and name then return name end
    elseif GetResourceState('qb-core') == 'started' then
        local ok, name = pcall(function()
            local p = exports['qb-core']:GetCoreObject().Functions.GetPlayer(src)
            local c = p and p.PlayerData.charinfo
            return c and (c.firstname .. ' ' .. c.lastname)
        end)
        if ok and name then return name end
    end
    return GetPlayerName(src) or '?'
end

local function hasKey()
    return type(ServerConfig.YouTubeApiKey) == 'string' and ServerConfig.YouTubeApiKey ~= ''
end

local radios = {}       -- [netId] = { current, queue, history, startedAt, pausedPos, volume }
local meta = {}         -- [videoId] = { id, title, artist, thumb, duration }
local cache = {}        -- [busqueda] = { t = os.time(), ids = {...} }
local lastSearch = {}   -- [src] = os.time()
local hourly = {}       -- [src] = { hour = n, count = n }
local cuotaAgotadaHasta = 0

local CACHE_FILE = 'cache.json'

-- ------------------------------------------------------------
--  Cache en archivo
-- ------------------------------------------------------------
do
    local raw = LoadResourceFile(GetCurrentResourceName(), CACHE_FILE)
    local data = raw and json.decode(raw) or nil
    if type(data) == 'table' then
        cache = data.cache or {}
        meta = data.meta or {}
    end
end

local saveQueued = false
local function saveCache()
    if saveQueued then return end
    saveQueued = true
    SetTimeout(10000, function()
        saveQueued = false
        -- Limpiar búsquedas viejas
        local limite = os.time() - (ServerConfig.CacheDays * 86400)
        local usados = {}
        for q, c in pairs(cache) do
            if (c.t or 0) < limite then
                cache[q] = nil
            else
                for _, id in ipairs(c.ids or {}) do usados[id] = true end
            end
        end
        for _, r in pairs(radios) do
            if r.current then usados[r.current.id] = true end
            for _, it in ipairs(r.queue) do usados[it.id] = true end
            for _, it in ipairs(r.history) do usados[it.id] = true end
        end
        for id in pairs(meta) do
            if not usados[id] then meta[id] = nil end
        end
        SaveResourceFile(GetCurrentResourceName(), CACHE_FILE, json.encode({ cache = cache, meta = meta }), -1)
    end)
end

-- Al prender el script, quitar música que se quedó de antes (reinicio del recurso)
CreateThread(function()
    Wait(1000)
    for _, veh in ipairs(GetAllVehicles()) do
        if Entity(veh).state.uplay then Entity(veh).state:set('uplay', nil, true) end
    end
end)

-- Reloj compartido para que todos los clientes calculen igual el tiempo de la canción
CreateThread(function()
    while true do
        GlobalState.uplayClock = os.time()
        Wait(15000)
    end
end)

-- ------------------------------------------------------------
--  Utilidades
-- ------------------------------------------------------------
local function notify(src, text, nType)
    TriggerClientEvent('ox_lib:notify', src, { title = 'U-Play', description = text, type = nType or 'inform' })
end

local function urlencode(str)
    return (str:gsub('\n', ' '):gsub('([^%w%-%_%.%~ ])', function(c)
        return string.format('%%%02X', string.byte(c))
    end):gsub(' ', '+'))
end

local entidades = { ['&amp;'] = '&', ['&quot;'] = '"', ['&#39;'] = "'", ['&lt;'] = '<', ['&gt;'] = '>', ['&#039;'] = "'" }
local function decodeHtml(s)
    s = s or ''
    s = s:gsub('&#[xX](%x+);', function(h)
        local n = tonumber(h, 16)
        if not n then return '' end
        if n < 256 then return string.char(n) end
        return utf8 and utf8.char(n) or ''
    end)
    s = s:gsub('&#(%d+);', function(n)
        n = tonumber(n)
        if n and n < 256 then return string.char(n) end
        return utf8 and utf8.char(n) or ''
    end)
    return (s:gsub('&%a+;', function(e) return entidades[e] or e end))
end

-- Quita "(Official Video)", "[Video Oficial]", "Letra", etc.
local basura = {
    '%s*[%(%[][^%)%]]*[Oo]fficial[^%)%]]*[%)%]]',
    '%s*[%(%[][^%)%]]*[Oo]ficial[^%)%]]*[%)%]]',
    '%s*[%(%[][^%)%]]*[Vv]ideo[^%)%]]*[%)%]]',
    '%s*[%(%[][^%)%]]*[Ll]yric[^%)%]]*[%)%]]',
    '%s*[%(%[][^%)%]]*[Ll]etra[^%)%]]*[%)%]]',
    '%s*[%(%[][^%)%]]*[Aa]udio[^%)%]]*[%)%]]',
    '%s*[%(%[][^%)%]]*[Vv]isualizer[^%)%]]*[%)%]]',
    '%s*[%(%[]%s*4[Kk]%s*[%)%]]',
    '%s*[%(%[]%s*HD%s*[%)%]]',
}

local function cleanTitle(title, channel)
    title = decodeHtml(title)
    for _, p in ipairs(basura) do title = title:gsub(p, '') end
    title = title:gsub('%s+$', ''):gsub('^%s+', '')

    channel = decodeHtml(channel or '')
    channel = channel:gsub('%s*%-%s*Topic$', ''):gsub('VEVO$', ''):gsub('%s+$', '')

    for _, sep in ipairs({ ' - ', ' – ', ' — ', ' | ', ' ●● ', ' ● ', ' • ', ' ~ ' }) do
        local i = title:find(sep, 1, true)
        if i then
            local artista = title:sub(1, i - 1):gsub('%s+$', '')
            local cancion = title:sub(i + #sep):gsub('^%s+', '')
            if #artista > 0 and #cancion > 0 then return cancion, artista end
        end
    end
    return title, channel
end

-- "PT3M23S" -> 203
local function isoDuration(iso)
    if type(iso) ~= 'string' then return 0 end
    local h = tonumber(iso:match('(%d+)H')) or 0
    local m = tonumber(iso:match('(%d+)M')) or 0
    local s = tonumber(iso:match('(%d+)S')) or 0
    return h * 3600 + m * 60 + s
end

local function httpGet(url)
    local p = promise.new()
    PerformHttpRequest(url, function(status, body)
        p:resolve({ status = status, body = body })
    end, 'GET', '', { ['Accept'] = 'application/json' })
    return Citizen.Await(p)
end

local function apiError(res)
    local data = res.body and json.decode(res.body) or nil
    local reason = data and data.error and data.error.errors and data.error.errors[1] and data.error.errors[1].reason
    return reason or ('http_' .. tostring(res.status))
end

-- ------------------------------------------------------------
--  Búsqueda en YouTube
-- ------------------------------------------------------------
local function youtubeSearch(q)
    local key = ServerConfig.YouTubeApiKey
    local function buscar(conCategoria)
        local url = ('https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&videoEmbeddable=true&maxResults=12&regionCode=%s&q=%s&key=%s%s')
            :format(ServerConfig.Region or 'MX', urlencode(q), key, conCategoria and '&videoCategoryId=10' or '')
        return httpGet(url)
    end

    local res = buscar(true)
    if res.status ~= 200 then return nil, apiError(res) end
    local data = json.decode(res.body or '{}') or {}
    local items = data.items or {}

    -- Si en la categoría "Música" no hay nada, buscar en todo YouTube
    if #items == 0 then
        res = buscar(false)
        if res.status ~= 200 then return nil, apiError(res) end
        data = json.decode(res.body or '{}') or {}
        items = data.items or {}
    end

    local ids, lista = {}, {}
    for _, it in ipairs(items) do
        local id = it.id and it.id.videoId
        if id and it.snippet and it.snippet.liveBroadcastContent ~= 'live' then
            local titulo, artista = cleanTitle(it.snippet.title, it.snippet.channelTitle)
            local thumb = ('https://i.ytimg.com/vi/%s/mqdefault.jpg'):format(id) -- 16:9 sin franjas negras
            lista[#lista + 1] = { id = id, title = titulo, artist = artista, thumb = thumb, duration = 0 }
            ids[#ids + 1] = id
        end
    end

    -- Duraciones (cuesta 1 punto por todas)
    if #ids > 0 then
        local r2 = httpGet(('https://www.googleapis.com/youtube/v3/videos?part=contentDetails&id=%s&key=%s'):format(table.concat(ids, ','), key))
        if r2.status == 200 then
            local d = json.decode(r2.body or '{}') or {}
            local dur = {}
            for _, v in ipairs(d.items or {}) do
                dur[v.id] = isoDuration(v.contentDetails and v.contentDetails.duration)
            end
            for _, it in ipairs(lista) do it.duration = dur[it.id] or 0 end
        end
    end

    -- Quitar videos sin duración (en vivo) o demasiado largos
    local final, finalIds = {}, {}
    for _, it in ipairs(lista) do
        if it.duration > 0 and it.duration <= Config.MaxDuration then
            final[#final + 1] = it
            finalIds[#finalIds + 1] = it.id
            meta[it.id] = it
        end
    end
    return final, nil, finalIds
end

-- ------------------------------------------------------------
--  Links de YouTube (funciona con o sin clave)
-- ------------------------------------------------------------
local function parseVideoId(s)
    s = (s or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local id = s:match('youtu%.be/([%w_%-]+)')
        or s:match('[?&]v=([%w_%-]+)')
        or s:match('/shorts/([%w_%-]+)')
        or s:match('/embed/([%w_%-]+)')
        or s:match('/live/([%w_%-]+)')
    if not id and s:match('^[%w_%-]+$') and #s == 11 then id = s end
    if id and #id == 11 then return id end
    return nil
end

local function resolveVideo(id)
    if meta[id] then return meta[id] end

    if hasKey() then
        -- Con clave: datos completos y duración (cuesta 1 punto)
        local res = httpGet(('https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails,status&id=%s&key=%s'):format(id, ServerConfig.YouTubeApiKey))
        if res.status ~= 200 then return nil end
        local d = json.decode(res.body or '{}') or {}
        local v = d.items and d.items[1]
        if not v or (v.status and v.status.embeddable == false) then return nil end
        local titulo, artista = cleanTitle(v.snippet.title, v.snippet.channelTitle)
        local item = { id = id, title = titulo, artist = artista, thumb = ('https://i.ytimg.com/vi/%s/mqdefault.jpg'):format(id), duration = isoDuration(v.contentDetails and v.contentDetails.duration) }
        meta[id] = item
        return item
    end

    -- Sin clave: oEmbed público de YouTube (no da la duración, la reporta el juego al empezar)
    local res = httpGet(('https://www.youtube.com/oembed?format=json&url=%s'):format(urlencode('https://www.youtube.com/watch?v=' .. id)))
    if res.status ~= 200 then return nil end
    local d = json.decode(res.body or '{}') or {}
    if not d.title then return nil end
    local titulo, artista = cleanTitle(d.title, d.author_name)
    local item = { id = id, title = titulo, artist = artista, thumb = ('https://i.ytimg.com/vi/%s/mqdefault.jpg'):format(id), duration = 0 }
    meta[id] = item
    return item
end

local function normalizar(q)
    q = q:lower():gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return q
end

-- ------------------------------------------------------------
--  Carro y permisos
-- ------------------------------------------------------------
-- Solo conductor (-1) o copiloto (0)
local function getControlVehicle(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return nil end
    if GetPedInVehicleSeat(veh, -1) ~= ped and GetPedInVehicleSeat(veh, 0) ~= ped then return nil end
    return veh, NetworkGetNetworkIdFromEntity(veh)
end

local function getRadio(netId)
    if not radios[netId] then
        radios[netId] = { current = nil, queue = {}, history = {}, startedAt = 0, pausedPos = nil, volume = Config.DefaultVolume }
    end
    return radios[netId]
end

local function occupants(veh)
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(id)
        if ped ~= 0 and GetVehiclePedIsIn(ped, false) == veh then
            list[#list + 1] = tonumber(id)
        end
    end
    return list
end

local function position(r)
    if not r.current then return 0 end
    if r.pausedPos then return r.pausedPos end
    return math.max(0, os.time() - r.startedAt)
end

local function uiPayload(r)
    return {
        current = r.current,
        queue = r.queue,
        history = r.history,
        paused = r.pausedPos ~= nil,
        position = position(r),
        volume = r.volume,
        canSearch = hasKey(),
    }
end

-- Actualiza el statebag (para que suene en todos) y la pantalla de los que van adentro
local function push(netId)
    local r = radios[netId]
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) then
        radios[netId] = nil
        return
    end

    if r and r.current then
        -- seq solo cambia si cambió el tiempo (canción, adelantar, pausa), no al agregar a la fila
        local timingKey = r.current.id .. ':' .. tostring(r.startedAt) .. ':' .. tostring(r.pausedPos)
        if timingKey ~= r.lastTimingKey then
            r.lastTimingKey = timingKey
            r.seq = (r.seq or 0) + 1
        end
        Entity(veh).state:set('uplay', {
            seq = r.seq,
            id = r.current.id,
            startedAt = r.startedAt,
            pausedPos = r.pausedPos,
            volume = r.volume,
            duration = r.current.duration,
        }, true)
    else
        Entity(veh).state:set('uplay', nil, true)
    end

    local payload = r and uiPayload(r) or { queue = {}, history = {}, volume = Config.DefaultVolume, canSearch = hasKey() }
    for _, id in ipairs(occupants(veh)) do
        TriggerClientEvent('uplay:client:state', id, payload)
    end
end

local function addHistory(r, item)
    if not item then return end
    for i = #r.history, 1, -1 do
        if r.history[i].id == item.id then table.remove(r.history, i) end
    end
    table.insert(r.history, 1, item)
    while #r.history > Config.MaxRecent do table.remove(r.history) end
end

local function playNow(netId, item, by)
    local r = getRadio(netId)
    if r.current then addHistory(r, r.current) end
    local it = {}
    for k, v in pairs(item) do it[k] = v end
    it.by = by
    r.current = it
    r.startedAt = os.time()
    r.pausedPos = nil
    push(netId)
end

local function nextSong(netId)
    local r = radios[netId]
    if not r then return end
    if r.current then addHistory(r, r.current) end
    if #r.queue > 0 then
        r.current = table.remove(r.queue, 1)
        r.startedAt = os.time()
        r.pausedPos = nil
    else
        r.current = nil
        r.pausedPos = nil
    end
    push(netId)
end

-- Pasar a la siguiente cuando se termina la canción
CreateThread(function()
    while true do
        Wait(1000)
        local now = os.time()
        for netId, r in pairs(radios) do
            local veh = NetworkGetEntityFromNetworkId(netId)
            if veh == 0 or not DoesEntityExist(veh) then
                radios[netId] = nil
            elseif r.current and not r.pausedPos and (r.current.duration or 0) > 0 and now - r.startedAt >= r.current.duration + 1 then
                nextSong(netId)
            end
        end
    end
end)

AddEventHandler('entityRemoved', function(entity)
    if GetEntityType(entity) ~= 2 then return end
    for netId in pairs(radios) do
        if NetworkGetEntityFromNetworkId(netId) == entity then
            radios[netId] = nil
        end
    end
end)

-- ------------------------------------------------------------
--  Callbacks para la pantalla
-- ------------------------------------------------------------
lib.callback.register('uplay:search', function(src, q)
    if not getControlVehicle(src) then return { error = L('not_in_seat') } end
    if type(q) ~= 'string' then return { error = L('search_error') } end
    -- ¿Pegaron un link?
    local linkId = parseVideoId(q)
    if linkId then
        local now = os.time()
        if lastSearch[src] and now - lastSearch[src] < 2 then return { error = L('wait') } end
        lastSearch[src] = now
        local item = resolveVideo(linkId)
        if not item then return { error = L('bad_link') } end
        if item.duration > Config.MaxDuration then return { error = L('too_long') } end
        saveCache()
        return { results = { item } }
    end

    q = normalizar(q):sub(1, 80)
    if #q < 2 then return { results = {} } end

    -- 1) Cache (no gasta clave)
    local c = cache[q]
    if c and (os.time() - (c.t or 0)) < ServerConfig.CacheDays * 86400 then
        local lista = {}
        for _, id in ipairs(c.ids or {}) do
            if meta[id] then lista[#lista + 1] = meta[id] end
        end
        if #lista > 0 then return { results = lista, cached = true } end
    end

    if not hasKey() then
        return { error = L('needs_link') }
    end
    if os.time() < cuotaAgotadaHasta then return { error = L('quota') } end

    -- 2) Límites por jugador
    local now = os.time()
    if lastSearch[src] and now - lastSearch[src] < ServerConfig.SearchCooldown then
        return { error = L('wait') }
    end
    local hora = math.floor(now / 3600)
    hourly[src] = (hourly[src] and hourly[src].hour == hora) and hourly[src] or { hour = hora, count = 0 }
    if hourly[src].count >= ServerConfig.MaxSearchesPerHour then
        return { error = L('wait') }
    end
    lastSearch[src] = now
    hourly[src].count = hourly[src].count + 1

    -- 3) YouTube
    local lista, err, ids = youtubeSearch(q)
    if not lista then
        if err == 'quotaExceeded' or err == 'dailyLimitExceeded' then
            cuotaAgotadaHasta = now + 3600
            return { error = L('quota') }
        end
        print(('^1[U-Play]^7 Error de YouTube: %s'):format(tostring(err)))
        return { error = L('search_error') }
    end

    cache[q] = { t = now, ids = ids }
    saveCache()
    return { results = lista }
end)

lib.callback.register('uplay:getState', function(src)
    local _, netId = getControlVehicle(src)
    if not netId then return nil end
    return uiPayload(getRadio(netId))
end)

lib.callback.register('uplay:action', function(src, action, data)
    local veh, netId = getControlVehicle(src)
    if not netId then return { error = L('not_in_seat') } end
    local r = getRadio(netId)
    local name = playerName(src)

    local function itemFrom(id)
        if type(id) ~= 'string' or not id:match('^[%w%-_]+$') then return nil end
        return meta[id]
    end

    if action == 'play' then
        local item = itemFrom(data and data.id)
        if not item then return { error = L('search_error') } end
        if (item.duration or 0) > Config.MaxDuration then return { error = L('too_long') } end
        playNow(netId, item, name)

    elseif action == 'queue' then
        local item = itemFrom(data and data.id)
        if not item then return { error = L('search_error') } end
        if not r.current then
            playNow(netId, item, name)
        else
            if #r.queue >= Config.MaxQueue then return { error = L('queue_full') } end
            local it = {}
            for k, v in pairs(item) do it[k] = v end
            it.by = name
            r.queue[#r.queue + 1] = it
            push(netId)
        end

    elseif action == 'remove' then
        local i = tonumber(data and data.index)
        if i and r.queue[i] then table.remove(r.queue, i) end
        push(netId)

    elseif action == 'playQueued' then
        local i = tonumber(data and data.index)
        if i and r.queue[i] then
            local it = table.remove(r.queue, i)
            if r.current then addHistory(r, r.current) end
            r.current = it
            r.startedAt = os.time()
            r.pausedPos = nil
            push(netId)
        end

    elseif action == 'next' then
        nextSong(netId)

    elseif action == 'prev' then
        if r.current and position(r) > 5 then
            r.startedAt = os.time()
            if r.pausedPos then r.pausedPos = 0 end
            push(netId)
        elseif r.history[1] then
            local prev = table.remove(r.history, 1)
            if r.current then table.insert(r.queue, 1, r.current) end
            r.current = prev
            r.startedAt = os.time()
            r.pausedPos = nil
            push(netId)
        end

    elseif action == 'toggle' then
        if not r.current then return {} end
        if r.pausedPos then
            r.startedAt = os.time() - r.pausedPos
            r.pausedPos = nil
        else
            r.pausedPos = position(r)
        end
        push(netId)

    elseif action == 'seek' then
        local s = tonumber(data and data.position)
        if r.current and s then
            s = math.max(0, math.min(math.floor(s), (r.current.duration or 0) - 1))
            if r.pausedPos then r.pausedPos = s else r.startedAt = os.time() - s end
            push(netId)
        end

    elseif action == 'volume' then
        local v = tonumber(data and data.volume)
        if v then
            r.volume = math.max(0, math.min(100, math.floor(v)))
            push(netId)
        end

    elseif action == 'stop' then
        if r.current then addHistory(r, r.current) end
        r.current = nil
        r.queue = {}
        r.pausedPos = nil
        push(netId)
    end

    return uiPayload(r)
end)

-- El conductor o copiloto avisa si el video no se pudo reproducir (bloqueado fuera de YouTube)
RegisterNetEvent('uplay:server:failed', function(netId, id)
    local src = source
    local _, myNet = getControlVehicle(src)
    if not myNet or myNet ~= netId then return end
    local r = radios[netId]
    if not r or not r.current or r.current.id ~= id then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    for _, p in ipairs(occupants(veh)) do notify(p, L('unavailable'), 'error') end
    r.current = nil -- no se guarda en recientes
    nextSong(netId)
end)

-- El conductor/copiloto avisa cuánto dura la canción (cuando no se sabía)
RegisterNetEvent('uplay:server:duration', function(netId, id, seconds)
    local src = source
    local _, myNet = getControlVehicle(src)
    if not myNet or myNet ~= netId then return end
    local r = radios[netId]
    seconds = tonumber(seconds)
    if not r or not r.current or r.current.id ~= id or not seconds then return end
    if (r.current.duration or 0) > 0 then return end
    seconds = math.floor(seconds)
    if seconds < 5 then return end
    if seconds > Config.MaxDuration then
        nextSong(netId)
        return
    end
    r.current.duration = seconds
    if meta[id] then meta[id].duration = seconds end
    push(netId)
end)

AddEventHandler('playerDropped', function()
    lastSearch[source] = nil
    hourly[source] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SaveResourceFile(GetCurrentResourceName(), CACHE_FILE, json.encode({ cache = cache, meta = meta }), -1)
end)
