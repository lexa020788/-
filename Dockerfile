# syntax=docker/dockerfile:1
FROM linuxserver/prowlarr:latest

WORKDIR /app

# 1. Устанавливаем Node.js и bash
RUN apk add --no-cache nodejs bash

# 2. Переписываем сервер. Теперь он сам рулит портами и убирает 404 ошибку
COPY <<EOF /app/server.js
const http = require('http');
const url = require('url');

// Koyeb всегда дает порт в переменную process.env.PORT, обычно это 8080
const PORT = process.env.PORT || 8080;

const server = http.createServer((req, res) => {
    // Включаем CORS заголовки, чтобы Smart TV не блокировал плагин
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', '*');
    if (req.method === 'OPTIONS') { res.writeHead(200); return res.end(); }
    
    const parsedUrl = url.parse(req.url, true);
    const myDomain = 'https://' + req.headers.host;
    
    // ТОЧКА 1: Отдача плагина для Лампы по чистому пути
    if (parsedUrl.pathname === '/online.js') {
        res.writeHead(200, { 'Content-Type': 'application/javascript; charset=utf-8' });
        
        const plugin = \`(function () { 
            'use strict'; 
            if (!window.Lampa) return; 
            console.log('[Личный Про-Плагин]: Ридер запущен.'); 
            Lampa.Storage.set('torrserver_use', true); 
            Lampa.Storage.set('torrserver_url', 'http://127.0.0.1:8090'); 
            Lampa.Storage.set('parser_use', true); 
            Lampa.Storage.set('parser_torrent_url', '\${myDomain}/search'); 
            
            Lampa.Listener.follow('full', function (e) { 
                if (e.type == 'complite') { 
                    var movie = e.data.movie; 
                    if (!movie.kinopoisk_id && !movie.imdb_id) return; 
                    if (e.object.find('.class_personal_reader').length) return; 
                    var button = jQuery('<div class="full-start__button class_personal_reader selector">Личный Ридер (Онлайн)</div>'); 
                    button.on('hover:enter', function () { 
                        var type = movie.number_of_seasons ? 'tv' : 'movie'; 
                        var id = movie.imdb_id || movie.kinopoisk_id; 
                        Lampa.Component.add('reader', { 
                            title: 'Личный Онлайн', 
                            url: '\${myDomain}/reader-api?type=' + type + '&id=' + id
                        }); 
                    }); 
                    var container = e.object.find('.full-start__buttons').length ? e.object.find('.full-start__buttons') : e.object.find('.card__buttons'); 
                    container.append(button); 
                } 
            }); 
        })();\`;
        
        res.end(plugin);
        return;
    }
    
    // ТОЧКА 2: Выдача онлайн потоков в плеер Lampa
    if (parsedUrl.pathname === '/reader-api') {
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
    
    // ТОЧКА 3: Поиск торрентов (Проксирование на Prowlarr, который у нас на порту 9696)
    if (parsedUrl.pathname === '/search') {
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        const q = parsedUrl.query.query || '';
        const prowlarrUrl = 'http://127.0.0' + encodeURIComponent(q);
        
        const http = require('http');
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
    
    // Точка проверки для Koyeb
    if (parsedUrl.pathname === '/health' || parsedUrl.pathname === '/') { 
        res.writeHead(200, { 'Content-Type': 'text/plain' }); 
        return res.end('OK'); 
    }
    
    res.writeHead(404);
    res.end('Not Found');
});

server.listen(PORT, () => console.log('Proxy Bridge active on port ' + PORT));
EOF

# 3. Скрипт гарантированного старта: Prowlarr убираем на порт 9696, Node.js ставим на главный порт
COPY <<EOF /app/entrypoint.sh
#!/bin/bash
mkdir -p /config
# Меняем порт Prowlarr внутри XML, чтобы он не воровал порт 8080 у Node.js
echo '<Config><Port>9696</Port><ApiKey>1234567890abcdef1234567890abcdef</ApiKey><AuthenticationMethod>None</AuthenticationMethod></Config>' > /config/config.xml
/usr/bin/prowlarr -nobrowser -data=/config &
sleep 4
exec node /app/server.js
EOF

RUN chmod +x /app/entrypoint.sh

# Открываем только главный порт шлюза наружу
EXPOSE 8080
ENTRYPOINT ["/app/entrypoint.sh"]
