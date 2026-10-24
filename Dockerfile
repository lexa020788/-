# ==========================================
# ФИНАЛЬНЫЙ МОНОЛИТНЫЙ DOCKERFILE ДЛЯ KOYEB
# ==========================================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app

# 1. Устанавливаем минимальный софт и Node.js
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    sqlite3 \
    libicu70 \
    nodejs \
    && rm -rf /var/lib/apt/lists/*

# 2. Скачиваем и распаковываем поисковый движок Prowlarr
RUN curl -L "https://servarr.com" -o prowlarr.tar.gz \
    && tar -xvzf prowlarr.tar.gz \
    && rm prowlarr.tar.gz

# 3. Записываем весь управляющий код моста прямо внутрь контейнера.
# Docker заменяет $$ на одинарный знак доллара, чтобы код остался рабочим для Lampa.
RUN echo "const http = require('http'); \
const url = require('url'); \
const PORT = process.env.PORT || 8080; \
const TOKEN = process.env.SECRET_TOKEN || 'my_lampa_secret_2026'; \
const server = http.createServer((req, res) => { \
    res.setHeader('Access-Control-Allow-Origin', '*'); \
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS'); \
    if (req.method === 'OPTIONS') { res.writeHead(200); return res.end(); } \
    const parsedUrl = url.parse(req.url, true); \
    const myDomain = 'https://' + req.headers.host; \
    if (parsedUrl.pathname === '/online.js' && parsedUrl.query.token === TOKEN) { \
        res.writeHead(200, { 'Content-Type': 'application/javascript; charset=utf-8' }); \
        res.end(\`(function () { \
            'use strict'; \
            if (!window.Lampa) return; \
            console.log('[Личный Про-Плагин]: Подключен.'); \
            Lampa.Storage.set('torrserver_use', true); \
            Lampa.Storage.set('torrserver_url', 'http://127.0.0.1:8090'); \
            Lampa.Storage.set('parser_use', true); \
            Lampa.Storage.set('parser_torrent_url', '\${myDomain}/search?token=\${TOKEN}'); \
            Lampa.Listener.follow('full', function (e) { \
                if (e.type == 'complite') { \
                    var movie = e.data.movie; \
                    if (!movie.kinopoisk_id && !movie.imdb_id) return; \
                    var button = \\\$\\\$('<div class=\\\"full-start__button class_personal_online selector\\\">Личный Онлайн</div>'); \
                    button.on('hover:enter', function () { \
                        var type = movie.number_of_seasons ? 'tv' : 'movie'; \
                        var id = movie.imdb_id || movie.kinopoisk_id; \
                        Lampa.Platform.openURL('https://vidsrc.sh' + type + '/' + id); \
                    }); \
                    e.object.find('.full-start__buttons').append(button); \
                } \
            }); \
        })();\`); \
        return; \
    } \
    if (parsedUrl.pathname === '/search' && parsedUrl.query.token === TOKEN) { \
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' }); \
        const q = parsedUrl.query.query || ''; \
        const prowlarrUrl = 'http://127.0.0' + encodeURIComponent(q); \
        http.get(prowlarrUrl, (pRes) => { \
            let body = ''; \
            pRes.on('data', chunk => body += chunk); \
            pRes.on('end', () => { \
                try { \
                    const results = JSON.parse(body); \
                    const lampaFormat = results.map(item => ({ \
                        title: item.title, \
                        seeders: item.seeders || 0, \
                        leechers: (item.peers - item.seeders) || 0, \
                        size: item.size, \
                        magnet: item.magnetUrl || item.downloadUrl, \
                        tracker: item.indexer \
                    })); \
                    res.end(JSON.stringify({ reasult: lampaFormat })); \
                } catch(e) { res.end(JSON.stringify({ reasult: [] })); } \
            }); \
        }).on('error', () => res.end(JSON.stringify({ reasult: [] }))); \
        return; \
    } \
    if (parsedUrl.pathname === '/health') { res.writeHead(200); return res.end('OK'); } \
    res.writeHead(403); res.end('Forbidden'); \
}); \
server.listen(PORT, () => console.log('Bridge ready'));" > server.js

# 4. Записываем автоматический скрипт запуска двух программ одновременно
RUN echo "#!/bin/bash\n\
mkdir -p /config\n\
# Принудительно выставляем фиксированный API-ключ в настройки Prowlarr для безопасности\n\
echo '<Config><ApiKey>1234567890abcdef1234567890abcdef</ApiKey><AuthenticationMethod>None</AuthenticationMethod></Config>' > /config/config.xml\n\
/app/prowlarr/Prowlarr -nobrowser -data=/config &\n\
sleep 3\n\
exec node /app/server.js" > entrypoint.sh && chmod +x entrypoint.sh

# 5. Открываем только один порт наружу (требование бесплатного Koyeb)
EXPOSE 8080

ENTRYPOINT ["/app/entrypoint.sh"]

# Сброс кэша сборки
# force-rebuild-2026
