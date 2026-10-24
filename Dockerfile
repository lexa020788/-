# syntax=docker/dockerfile:1
FROM linuxserver/prowlarr:latest

WORKDIR /app

# 1. Устанавливаем Node.js и bash
RUN apk add --no-cache nodejs bash

# 2. Переписываем сервер: полная замена стандартного модуля онлайн на наш Ридер
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
    
    if (parsedUrl.pathname === '/online.js') {
        res.writeHead(200, { 'Content-Type': 'application/javascript; charset=utf-8' });
        
        const plugin = \`(function () { 
            'use strict'; 
            if (!window.Lampa) return; 
            
            console.log('[Личный Про-Плагин]: Нативная интеграция в модуль Онлайн.'); 
            
            // Настройка TorrServer и Поиска в облаке
            Lampa.Storage.set('torrserver_use', true); 
            Lampa.Storage.set('torrserver_url', 'http://127.0.0.1:8090'); 
            Lampa.Storage.set('parser_use', true); 
            Lampa.Storage.set('parser_torrent_url', '\${myDomain}/search'); 
            
            // ХАК ПРОФИ: Перехватываем стандартный компонент онлайна Лампы.
            // Теперь при нажатии на родную кнопку "Онлайн" в карточке запустится НАШ код!
            var original_online = Lampa.Component.get('online');
            
            Lampa.Component.add('online', function (object, params) {
                var movie = object.card || {};
                var type = movie.number_of_seasons ? 'tv' : 'movie';
                var id = movie.imdb_id || movie.kinopoisk_id;
                
                if (id) {
                    // Перенаправляем пользователя во встроенный Ридер-плеер Лампы
                    Lampa.Component.add('reader', { 
                        title: 'Личный Онлайн', 
                        url: '\${myDomain}/reader-api?type=' + type + '&id=' + id
                    });
                    
                    // Вызываем Ридер вместо стандартного пустого экрана
                    Lampa.Activity.push({
                        title: 'Личный Онлайн',
                        component: 'reader',
                        page: 1
                    });
                } else if (original_online) {
                    // Если у фильма нет ID, вызываем стандартный поиск Lampa (резерв)
                    return new original_online(object, params);
                } else {
                    Lampa.Noty.show('ID фильма не найден.');
                }
                
                this.create = function () {};
                this.destroy = function () {};
            });
        })();\`;
        
        res.end(plugin);
        return;
    }
    
    // ТОЧКА 2: Выдача онлайн потоков в плеер Ридера
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
