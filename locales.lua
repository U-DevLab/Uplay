Locales = {}

Locales.es = {
    -- Notificaciones
    not_in_seat = 'Tienes que ir de conductor o copiloto',
    quota = 'Se acabaron las búsquedas de hoy. Mañana se reinician (lo que está en la fila sigue sonando)',
    wait = 'Espera un momento antes de buscar otra vez',
    search_error = 'No se pudo buscar en este momento',
    needs_link = 'Pega un link de YouTube (la búsqueda por nombre no está activada en este servidor)',
    bad_link = 'Ese link no es válido o el video no se puede reproducir',
    queue_full = 'La fila está llena',
    unavailable = 'Esa canción no se puede reproducir, se saltó',
    too_long = 'Esa canción es demasiado larga',
    key_desc = 'Abrir U-Play (música del carro)',

    -- Pantalla
    ui_placeholder_search = 'Busca una canción o artista',
    ui_placeholder_link = 'Pega un link de YouTube',
    ui_tab_results = 'Resultados',
    ui_tab_queue = 'Fila',
    ui_tab_recent = 'Recientes',
    ui_empty_start_search = 'Escribe el nombre de una canción o artista<br>y presiona Enter.',
    ui_empty_start_link = 'Pega un link de YouTube<br>y presiona Enter.',
    ui_empty_none = 'No se encontró nada.<br>Prueba con otro nombre.',
    ui_empty_queue = 'La fila está vacía.<br>Usa el botón + en una canción para agregarla.',
    ui_empty_recent = 'Aquí salen las últimas canciones<br>que sonaron en este carro.',
    ui_nothing = 'Nada sonando',
    ui_nothing_sub = 'Busca una canción para empezar',
    ui_added_by = 'Puesta por',
    ui_added = 'Agregada a la fila',
    ui_add = 'Agregar a la fila',
    ui_play = 'Reproducir',
    ui_remove = 'Quitar',
    ui_play_now = 'Reproducir ahora',
}

Locales.en = {
    -- Notifications
    not_in_seat = 'You must be the driver or front passenger',
    quota = 'Daily searches used up. They reset tomorrow (the queue keeps playing)',
    wait = 'Wait a moment before searching again',
    search_error = 'Search is not available right now',
    needs_link = 'Paste a YouTube link (search by name is not enabled on this server)',
    bad_link = 'That link is invalid or the video cannot be played',
    queue_full = 'The queue is full',
    unavailable = 'That song cannot be played, skipped',
    too_long = 'That song is too long',
    key_desc = 'Open U-Play (car music)',

    -- Screen
    ui_placeholder_search = 'Search a song or artist',
    ui_placeholder_link = 'Paste a YouTube link',
    ui_tab_results = 'Results',
    ui_tab_queue = 'Queue',
    ui_tab_recent = 'Recent',
    ui_empty_start_search = 'Type a song or artist name<br>and press Enter.',
    ui_empty_start_link = 'Paste a YouTube link<br>and press Enter.',
    ui_empty_none = 'Nothing found.<br>Try another name.',
    ui_empty_queue = 'The queue is empty.<br>Use the + button on a song to add it.',
    ui_empty_recent = 'The last songs played<br>in this car show up here.',
    ui_nothing = 'Nothing playing',
    ui_nothing_sub = 'Search a song to start',
    ui_added_by = 'Added by',
    ui_added = 'Added to queue',
    ui_add = 'Add to queue',
    ui_play = 'Play',
    ui_remove = 'Remove',
    ui_play_now = 'Play now',
}

function L(key)
    local lang = Locales[Config.Locale] or Locales.en
    return lang[key] or Locales.en[key] or key
end

function UILocale()
    local lang = Locales[Config.Locale] or Locales.en
    local out = {}
    for k, v in pairs(Locales.en) do
        if k:sub(1, 3) == 'ui_' then out[k] = lang[k] or v end
    end
    return out
end
