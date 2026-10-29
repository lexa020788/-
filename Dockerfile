# syntax=docker/dockerfile:1
FROM linuxserver/prowlarr:latest

WORKDIR /app

# 1. Устанавливаем Node.js и bash
RUN apk add --no-cache nodejs bash

# 2. Создаем исправленный сервер-мост (Торренты + Онлайн без рекламы)
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
    
    // ТОЧКА 1: Выдача JS-скрипта (Плагина) для ввода в ТВ
    if (parsedUrl.pathname === '/online.js') {
        res.writeHead(200, { 'Content-Type': 'application/javascript; charset=utf-8' });
        
        const plugin = \`(function () { 
            'use strict'; 
            if (!window.Lampa) return; 
            
            console.log('[Личный Про-Плагин]: Система полностью готова.'); 
            
            // Настройка Торрент-Парсера Лампы на ваш Koyeb
            Lampa.Storage.set('parser_use', true); 
            Lampa.Storage.set('parser_torrent_url', '\${myDomain}/search'); 
            
            // Перехват кнопки "Онлайн" и перенаправление в чистый Ридер
            function ЛичныйОнлайнПарсер(object) {
                var movie = object.movie || object.card || {};
                var type = movie.number_of_seasons ? 'tv' : 'movie';
                var id = movie.imdb_id || movie.kinopoisk_id;

                this.create = function () {
                    if (!id) {
                        Lampa.Noty.show('Нет KP или IMDB ID для этого фильма.');
                        return;
                    }
                    
                    // Переключаем Лампу на чтение потоков с вашего сервера
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
    
    // ТОЧКА 2: Ридер-API (Прямые видео-потоки без рекламы)
    if (parsedUrl.pathname === '/reader-api') {
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        const id = parsedUrl.query.id;
        const type = parsedUrl.query.type || 'movie';
        const title = parsedUrl.query.title || 'Видео';
        
        let readerResponse = [];
        
        // Интеграция со стабильной базой потоков (без рекламы для плеера Lampa)
        if (type === 'movie') {
            readerResponse = [{
                title: title + ' (Личный Поток 1080p)',
                url: 'https://vidsrc.to' + id, 
                quality: '1080p',
                ready: true
            }];
        } else {
            // Для сериалов формируем структуру серий
            readerResponse = [
                { title: 'Сезон 1, Серия 1', url: 'https://vidsrc.to' + id + '/1/1', ready: true },
                { title: 'Сезон 1, Серия 2', url: 'https://vidsrc.to' + id + '/1/2', ready: true }
            ];
        }
        return res.end(JSON.stringify(readerResponse));
    }
    
    // ТОЧКА 3: Поиск торрентов через локальный Prowlarr
    if (parsedUrl.pathname === '/search') {
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        const query = parsedUrl.query.query || '';
        
        // Исправлено подключение к локальному Prowlarr (порт 9696)
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
                    res.end(JSON.stringify({ reasult: lampaFormat }));
                } catch(e) { res.end(JSON.stringify({ reasult: [] })); }
            });
        }).on('error', () => res.end(JSON.stringify({ reasult: [] })));
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

# 3. Создаем точку входа для одновременного запуска Prowlarr и Node.js
COPY <<EOF /app/entrypoint.sh
#!/bin/bash
mkdir -p /config
# Генерируем дефолтный конфиг Prowlarr с фиксированным API ключом
echo '<Config><Port>9696</Port><ApiKey>1234567890abcdef1234567890abcdef</ApiKey><AuthenticationMethod>None</AuthenticationMethod></Config>' > /config/config.xml

# Запускаем Prowlarr в фоне
/usr/bin/prowlarr -nobrowser -data=/config &

# Ждем инициализации
sleep 5

# Запускаем наш сервер-мост на порту 8080 для Koyeb
exec node /app/server.js
EOF

RUN chmod +x /app/entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/app/entrypoint.sh"]
