# syntax=docker/dockerfile:1
FROM linuxserver/prowlarr:latest

WORKDIR /app

# 1. Устанавливаем Node.js и bash
RUN apk add --no-cache nodejs bash

# 2. Переписываем сервер: создаем полноценный онлайн-парсер (балансер)
COPY <<EOF /app/server.js
const http = require('http');
const url = require('url');

const PORT = process.env.PORT || 8080;

const server = http.createServer((req, res) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', '*');
    if (req.method === 'OPTIONS') { res.writeHead(200); return res.end(); }
    
    const parsedUrl = url.parse(req.url, true);
    const myDomain = 'https://' + req.headers.host;
    
    // ТОЧКА 1: Выдача JS-скрипта, который регистрирует ОНЛАЙН-ПАРСЕР
    if (parsedUrl.pathname === '/online.js') {
        res.writeHead(200, { 'Content-Type': 'application/javascript; charset=utf-8' });
        
        const plugin = \`(function () { 
            'use strict'; 
            if (!window.Lampa) return; 
            
            console.log('[Личный Про-Плагин]: Онлайн-парсер успешно интегрирован.'); 
            
            // Настройка TorrServer и Торрент-Парсера в облаке
            Lampa.Storage.set('torrserver_use', true); 
            Lampa.Storage.set('torrserver_url', 'http://127.0.0.1:8090'); 
            Lampa.Storage.set('parser_use', true); 
            Lampa.Storage.set('parser_torrent_url', '\${myDomain}/search'); 
            
            // РЕГИСТРАЦИЯ ОФИЦИАЛЬНОГО ОНЛАЙН-ПАРСЕРА ДЛЯ КНОПКИ "ОНЛАЙН"
            // Теперь ЛАМПА знает, что за онлайном нужно ходить на ваш Koyeb!
            function ЛичныйПарсер(object) {
                var comp = this;
                var movie = object.card || {};
                var type = movie.number_of_seasons ? 'tv' : 'movie';
                var id = movie.imdb_id || movie.kinopoisk_id;

                this.create = function () {
                    if (!id) {
                        Lampa.Noty.show('У этого фильма нет KP или IMDB ID.');
                        return;
                    }

                    // Вызываем встроенный Ридер-плеер Лампы, передавая ему структуру папок с Koyeb
                    Lampa.Component.add('reader', { 
                        title: 'Личный Онлайн', 
                        url: '\${myDomain}/reader-api?type=' + type + '&id=' + id
                    });
                    
                    Lampa.Activity.push({
                        title: 'Личный Онлайн',
                        component: 'reader',
                        page: 1
                    });
                };

                this.destroy = function () {};
            }

            // Внедряем наш парсер в систему онлайна Lampa
            Lampa.Component.add('online', ЛичныйПарсер);
        })();\`;
        
        res.end(plugin);
        return;
    }
    
    // ТОЧКА 2: Ридер-API (Выдача онлайн потоков во встроенный плеер Ридера)
    if (parsedUrl.pathname === '/reader-api') {
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        const id = parsedUrl.query.id;
        const type = parsedUrl.query.type || 'movie';
        let readerResponse = [];
        if (type === 'movie') {
            readerResponse = [{
                title: 'Смотреть Фильм (Личный Поток 1080p)',
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
    
    // ТОЧКА 3: Поиск торрентов через Prowlarr
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
    
    if (parsedUrl.pathname === '/health' || parsedUrl.pathname === '/') { 
        res.writeHead(200, { 'Content-Type': 'text/plain' }); 
        return res.end('OK'); 
    }
    res.writeHead(404); res.end('Not Found');
});

server.listen(PORT, () => console.log('Proxy Bridge active on port ' + PORT));
EOF

COPY <<EOF /app/entrypoint.sh
#!/bin/bash
mkdir -p /config
echo '<Config><Port>9696</Port><ApiKey>1234567890abcdef1234567890abcdef</ApiKey><AuthenticationMethod>None</AuthenticationMethod></Config>' > /config/config.xml
/usr/bin/prowlarr -nobrowser -data=/config &
sleep 4
exec node /app/server.js
EOF

RUN chmod +x /app/entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/app/entrypoint.sh"]
