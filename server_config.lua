-- ============================================================
--  Server only (players never see this file)
--  Solo servidor (los jugadores nunca ven este archivo)
-- ============================================================
ServerConfig = {}

-- YouTube Data API v3 key (optional). See README.md.
--   Empty  -> players paste YouTube links.
--   With key -> players search songs by name.
-- Clave de YouTube Data API v3 (opcional). Ver README.md.
--   Vacía   -> los jugadores pegan links de YouTube.
--   Con clave -> los jugadores buscan canciones por nombre.
ServerConfig.YouTubeApiKey = ''

-- Country for search results (MX, US, ES, AR, CO...) / País para los resultados
ServerConfig.Region = 'MX'

-- Per player: 1 search every X seconds and max per hour / Por jugador: 1 búsqueda cada X segundos y máximo por hora
ServerConfig.SearchCooldown = 4
ServerConfig.MaxSearchesPerHour = 25

-- Days a search is cached (repeated searches don't use API quota) / Días que se guarda una búsqueda
ServerConfig.CacheDays = 7
