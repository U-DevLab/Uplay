# U-Play

Car music for FiveM with a built-in song search. No more copying YouTube links.

🇲🇽 [Español abajo](#español)

## Features
- Search songs by name (optional YouTube API key) or paste a YouTube link (no key needed)
- Queue, recently played, pause, skip, seek and volume
- Heard inside and outside the car, synced for every player nearby
- Only the driver and front passenger can open and control it
- Works with ESX, QBCore, Qbox or standalone
- Spanish and English

## Requirements
- [ox_lib](https://github.com/overextended/ox_lib)
- [xsound](https://github.com/Xogy/xsound)
- Optional: free YouTube Data API v3 key (for search by name)

## Installation
1. Put the `uplay` folder in your resources.
2. Add `ensure uplay` to your server.cfg **after** `ox_lib` and `xsound`.
3. (Optional) Paste your YouTube key in `server_config.lua`.
4. Change the language in `config.lua` (`Config.Locale = 'en'`).

Open it with `/carplay` while driving or as front passenger. You can set a key in
Settings → Key Bindings → FiveM → "Open U-Play".

## YouTube API key (optional)
1. Go to https://console.cloud.google.com and sign in.
2. Create a new project.
3. Search **YouTube Data API v3** and click **Enable**.
4. Go to **Credentials → Create credentials → API key**.
5. (Recommended) Restrict the key to **YouTube Data API v3**.
6. Paste it in `server_config.lua`:
   ```lua
   ServerConfig.YouTubeApiKey = 'AIza...'
   ```

The free quota is 10,000 units per day. Each new search costs 100 (about 100 searches
per day for the whole server). Repeated searches are cached for 7 days and cost nothing.
Playing music does not use quota.

Never share your key or upload it to GitHub.

## Notes
- Music plays through YouTube's embedded player. Some videos are blocked from
  embedding by their owner; those are skipped automatically.
- Server owners are responsible for the content played on their server.

## License
MIT. Font: Inter (SIL Open Font License).

---

## Español

Música en el carro para FiveM con buscador de canciones. Ya no hay que copiar links de YouTube.

### Qué hace
- Busca canciones por nombre (con clave de YouTube opcional) o pega un link de YouTube (sin clave)
- Fila, recientes, pausa, siguiente, adelantar y volumen
- Se oye dentro y fuera del carro, sincronizado para todos los que estén cerca
- Solo el conductor y el copiloto lo pueden abrir y controlar
- Funciona con ESX, QBCore, Qbox o sin framework
- Español e inglés

### Requisitos
- [ox_lib](https://github.com/overextended/ox_lib)
- [xsound](https://github.com/Xogy/xsound)
- Opcional: clave gratis de YouTube Data API v3 (para buscar por nombre)

### Instalación
1. Pon la carpeta `uplay` en tus resources.
2. Agrega `ensure uplay` en tu server.cfg **después** de `ox_lib` y `xsound`.
3. (Opcional) Pega tu clave de YouTube en `server_config.lua`.
4. El idioma se cambia en `config.lua` (`Config.Locale = 'es'`).

Se abre con `/carplay` yendo de conductor o copiloto. La tecla se pone en
Configuración → Teclas → FiveM → "Abrir U-Play".

### Clave de YouTube (opcional)
1. Entra a https://console.cloud.google.com con tu cuenta de Google.
2. Crea un proyecto nuevo.
3. Busca **YouTube Data API v3** y dale **Habilitar**.
4. Ve a **Credenciales → Crear credenciales → Clave de API**.
5. (Recomendado) Restringe la clave a **YouTube Data API v3**.
6. Pégala en `server_config.lua`:
   ```lua
   ServerConfig.YouTubeApiKey = 'AIza...'
   ```

La cuota gratis es de 10,000 puntos al día. Cada búsqueda nueva gasta 100 (unas 100
búsquedas al día para todo el server). Las búsquedas repetidas se guardan 7 días y no
gastan nada. Reproducir no gasta.

Nunca compartas tu clave ni la subas a GitHub.

### Notas
- La música usa el reproductor de YouTube. Algunos videos están bloqueados por su
  dueño para reproducirse fuera de YouTube; esos se saltan solos.
- Cada servidor es responsable de lo que se reproduce en él.

### Licencia
MIT. Fuente: Inter (SIL Open Font License).
