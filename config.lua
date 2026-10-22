Config = {}

-- 'es' = Español | 'en' = English
Config.Locale = 'es'

-- Command to open U-Play / Comando para abrir U-Play
Config.Command = 'carplay'

-- Default key ('' = none, command only). Players can change it in Settings > Key Bindings > FiveM.
-- Tecla por defecto ('' = ninguna, solo comando). Cada jugador la cambia en Configuración > Teclas > FiveM.
Config.DefaultKey = ''

Config.SoundDistance = 25.0  -- Meters the music can be heard outside the car / Metros que se oye fuera del carro
Config.DefaultVolume = 50    -- 0 - 100
Config.MaxQueue = 20         -- Max songs in queue / Máximo de canciones en la fila
Config.MaxRecent = 15        -- "Recent" songs per car / Canciones en "Recientes" por carro
Config.MaxDuration = 600     -- Max video length in seconds (10 min) / Duración máxima en segundos

-- true = prints in F8 every time U-Play moves the song time (to find skips) / muestra en F8 cada vez que U-Play mueve la canción
Config.Debug = false

-- Music keeps playing while the car exists, even if everyone gets out.
-- La música sigue mientras el carro exista, aunque todos se bajen.
