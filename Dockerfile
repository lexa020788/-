# 1. Используем официальный готовый контейнер с Prowlarr как донора
FROM linuxserver/prowlarr:latest AS prowlarr_source

# 2. Переходим на официальный легкий образ Node.js (база для нашего моста)
FROM node:20-slim

WORKDIR /app

# 3. Устанавливаем системные зависимости для работы .NET ядра Prowlarr
RUN apt-get update && apt-get install -y --no-install-recommends \
    sqlite3 \
    libicu70 \
    && rm -rf /var/lib/apt/lists/*

# 4. Копируем готовый, распакованный Prowlarr напрямую из первого контейнера
# Без скачиваний из интернета, без curl и без ломающихся ссылок!
COPY --from=prowlarr_source /app/prowlarr /app/prowlarr

# 5. Записываем код нашего сервера-моста под Ридер
COPY <<EOF /app/server.js
const http = require('http');
const url = require('url');

const PORT = process.env.PORT || 8080;
const TOKEN = process.env.SECRET_TOKEN || 'my_lampa_secret_2026';

const server = http.createServer((req, res) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    if (req.method === 'OPTIONS') { res.writeHead(200); return res.end(); }
    
    const parsedUrl = url.parse(req.url, true);
    const myDomain = 'https://' + req.headers.host;
    
    if (parsedUrl.pathname === '/online.js' && parsedUrl.query.token === TOKEN) {
        res.writeHead(200, { 'Content-Type': 'application/javascript; charset=utf-8' });
        
        const plugin = "(function () { " +
            "'use strict'; " +
            "if (!window.Lampa) return; " +
            "console.log('[Личный Про-Плагин]: Ридер активирован.'); " +
            "Lampa.Storage.set('torrserver_use', true); " +
            "Lampa.Storage.set('torrserver_url', 'http://127.0.0.1:8090'); " +
            "Lampa.Storage.set('parser_use', true); " +
            "Lampa.Storage.set('parser_torrent_url', '" + myDomain + "/search?token=" + TOKEN + "'); " +
            "Lampa.Listener.follow('full', function (e) { " +
                "if (e.type == 'complite') { " +
                    "var movie = e.data.movie; " +
                    "if (!movie.kinopoisk_id && !movie.imdb_id) return; " +
                    "if (e.object.find('.class_personal_reader').length) return; " +
                    "var button = jQuery('<div class=\"full-start__button class_personal_reader selector\">Личный Ридер (Онлайн)</div>'); " +
                    "button.on('hover:enter', function () { " +
                        "var type = movie.number_of_seasons ? 'tv' : 'movie'; " +
                        "var id = movie.imdb_id || movie.kinopoisk_id; " +
                        "Lampa.Component.add('reader', { " +
                            "title: 'Личный Онлайн', " +
                            "url: '" + myDomain + "/reader-api?type=' + type + '&id=' + id + '&token=" + TOKEN + "' " +
                        "}); " +
                    "}); " +
                    "var container = e.object.find('.full-start__buttons').length ? e.object.find('.full-start__buttons') : e.object.find('.card__buttons'); " +
                    "container.append(button); " +
                "} " +
            "}); " +
        "})();";
        
        res.end(plugin);
        return;
    }
    
    if (parsedUrl.pathname === '/reader-api' && parsedUrl.query.token === TOKEN) {
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        const id = parsedUrl.query.id;
        const type = parsedUrl.query.type || 'movie';
        let readerResponse = [];
        if (type === 'movie') {
            readerResponse = [{
                title: 'Смотреть Фильм (Поток 1080p)',
                url: 'https://vidsrc.sh' + id,
                quality: '1080p',
                ready: true
            }];
        } else {
            readerResponse = [
                { title: 'Сезон 1, Серия 1', url: 'https://vidsrc.sh' + id + '/1/1', ready: true },
                { title: 'Сезон 1, Серия 2', url: 'https://vidsrc.sh' + id + '/1/2', ready: true }
            ];
        }
        return res.end(JSON.stringify(readerResponse));
    }
    
    if (parsedUrl.pathname === '/search' && parsedUrl.query.token === TOKEN) {
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        const q = parsedUrl.query.query || '';
        const prowlarrUrl = 'http://127.0.0' + encodeURIComponent(q);
        http.get(prowlarrUrl, (pRes) => {
            let body = '';
            pRes.on('data', chunk => body += chunk);
            pRes.on('end', () => {
                try {
                    const results = JSON.parse(body);
                    const lampaFormat = results.map(item => ({
                        title: item.title,
                        seeders: item.seeders || 0,
                        leechers: (item.peers - item.seeders) || 0,
                        size: item.size,
                        magnet: item.magnetUrl || item.downloadUrl,
                        tracker: item.indexer
                    }));
                    res.end(JSON.stringify({ reasult: lampaFormat }));
                } catch(e) { res.end(JSON.stringify({ reasult: [] })); }
            });
        }).on('error', () => res.end(JSON.stringify({ reasult: [] })));
        return;
    }
    
    if (parsedUrl.pathname === '/health') { res.writeHead(200); return res.end('OK'); }
    res.writeHead(403); res.end('Forbidden');
});

server.listen(PORT, () => console.log('Bridge ready'));
EOF

# 6. Записываем скрипт запуска
COPY <<EOF /app/entrypoint.sh
#!/bin/bash
mkdir -p /config
echo '<Config><ApiKey>1234567890abcdef1234567890abcdef</ApiKey><AuthenticationMethod>None</AuthenticationMethod></Config>' > /config/config.xml
/app/prowlarr/Prowlarr -nobrowser -data=/config &
sleep 3
exec node /app/server.js
EOF

RUN chmod +x /app/entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/app/entrypoint.sh"]
