# syntax=docker/dockerfile:1
FROM linuxserver/prowlarr:latest

WORKDIR /app

# 1. Устанавливаем Node.js и bash
RUN apk add --no-cache nodejs bash

# 2. Создаем исправленный сервер-мост (Торренты + Чистый онлайн)
COPY <<EOF /app/server.js
const http = require('http');
const url = require('url');

const PORT = process.env.PORT || 8080;
const PROWLARR_API_KEY = '1234567890abcdef1234567890abcdef';

const server = http.createServer((req, res) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', '*');
    if (req.method === 'OPTIONS') { res.writeHead(200); return res.end(); }
    
    const parsedUrl = url.parse(req.url, true);
    const myDomain = 'https://' + req.headers.host;
    
    // ТОЧКА 1: Выдача JS-скрипта (Плагина) для Лампы
    if (parsedUrl.pathname === '/online.js') {
        res.writeHead(200, { 'Content-Type': 'application/javascript; charset=utf-8' });
        
        const plugin = \`(function () { 
            'use strict'; 
            if (!window.Lampa) return; 
            
            console.log('[Личный Про-Плагин]: Инициализирован успешно.'); 
            
            // Настройка Торрент-Парсера Лампы на ваш Koyeb
            Lampa.Storage.set('parser_use', true); 
            Lampa.Storage.set('parser_torrent_url', '\${myDomain}/search'); 
            
            // Перехват кнопки "Онлайн" и перенаправление в чистый Ридер
            function ЛичныйОнлайнПарсер(object) {
                var movie = object.movie || object.card || {};
                var type = movie.number_of_seasons ? 'tv' : 'movie';
                var id = movie.kinopoisk_id || movie.imdb_id;

                this.create = function () {
                    if (!id) {
                        Lampa.Noty.show('Нет KP или IMDB ID для этого фильма.');
                        return;
                    }
                    
                    Lampa.Component.add('reader', { 
                        title: 'Чистый Онлайн', 
                        url: '\${myDomain}/reader-api?type=' + type + '&id=' + id + '&title=' + encodeURIComponent(movie.title || movie.name)
                    });
                    
                    Lampa.Activity.push({
                        title: 'Чистый Онлайн',
                        component: 'reader',
                        page: 1
                    });
                };
                this.destroy = function () {};
            }

            Lampa.Component.add('online', ЛичныйОнлайнПарсер);
        })();\`;
        
        res.end(plugin);
        return;
    }
    
    // ТОЧКА 2: Ридер-API (Прямые видео-потоки без рекламы через Alloha)
    if (parsedUrl.pathname === '/reader-api') {
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        const id = parsedUrl.query.id;
        const title = parsedUrl.query.title || 'Видео';
        
        const https = require('https');
        // Запрос к бесплатному открытому зеркалу Alloha, которое делится прямыми потоками
        const allohaUrl = 'https://alloha.tv' + id;
        
        https.get(allohaUrl, (apiRes) => {
            let body = '';
            apiRes.on('data', chunk => body += chunk);
            apiRes.on('end', () => {
                try {
                    const data = JSON.parse(body);
                    let readerResponse = [];
                    
                    if (data && data.data && data.data.files) {
                        // Парсим переводы и вытаскиваем чистые .m3u8 ссылки
                        Object.keys(data.data.files).forEach(translation => {
                            const fileData = data.data.files[translation];
                            if (fileData.link) {
                                readerResponse.push({
                                    title: title + ' (' + translation + ')',
                                    url: fileData.link, // Чистый видеопоток .m3u8 без рекламы
                                    quality: '1080p',
                                    ready: true
                                });
                            }
                        });
                    }
                    
                    // Если база ничего не вернула, отдаем пустой массив
                    res.end(JSON.stringify(readerResponse));
                } catch(e) { res.end(JSON.stringify([])); }
            });
        }).on('error', () => res.end(JSON.stringify([])));
        return;
    }
    
    // ТОЧКА 3: Поиск торрентов через локальный Prowlarr
    if (parsedUrl.pathname === '/search') {
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        const query = parsedUrl.query.query || '';
        
        const prowlarrUrl = 'http://127.0.0' + PROWLARR_API_KEY + '&query=' + encodeURIComponent(query);
        
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
                    // ИСПРАВЛЕНО: Было reasult, теперь правильное слово result
                    res.end(JSON.stringify({ result: lampaFormat }));
                } catch(e) { res.end(JSON.stringify({ result: [] })); }
            });
        }).on('error', () => res.end(JSON.stringify({ result: [] })));
        return;
    }
    
    if (parsedUrl.pathname === '/health' || parsedUrl.pathname === '/') { 
        res.writeHead(200, { 'Content-Type': 'text/plain' }); 
        return res.end('Cherry Prowlarr Bridge is Alive!'); 
    }
    res.writeHead(404); res.end('Not Found');
});

server.listen(PORT, () => console.log('Proxy Bridge active on port ' + PORT));
EOF

# 3. Точка входа
COPY <<EOF /app/entrypoint.sh
#!/bin/bash
mkdir -p /config
echo '<Config><Port>9696</Port><ApiKey>1234567890abcdef1234567890abcdef</ApiKey><AuthenticationMethod>None</AuthenticationMethod></Config>' > /config/config.xml
/usr/bin/prowlarr -nobrowser -data=/config &
sleep 5
exec node /app/server.js
EOF

RUN chmod +x /app/entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/app/entrypoint.sh"]
