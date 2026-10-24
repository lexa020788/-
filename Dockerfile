# syntax=docker/dockerfile:1
FROM linuxserver/prowlarr:latest

WORKDIR /app

# 1. Устанавливаем Node.js и bash
RUN apk add --no-cache nodejs bash

# 2. Переписываем сервер: интеграция через Lampa.Component
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
            console.log('[Личный Про-Плагин]: Активация нативного модуля.'); 
            
            // Настройка TorrServer и Поиска
            Lampa.Storage.set('torrserver_use', true); 
            Lampa.Storage.set('torrserver_url', 'http://127.0.0.1:8090'); 
            Lampa.Storage.set('parser_use', true); 
            Lampa.Storage.set('parser_torrent_url', '\${myDomain}/search'); 
            
            // МАКСИМАЛЬНЫЙ УРОВЕНЬ ПРОФИ: Создаем официальный плагин-балансер.
            // Lampa сама добавит пункт "Личный Онлайн" во встроенное меню выбора источников!
            var inline_balancer = {
                name: 'Личный Онлайн',
                id: 'personal_reader',
                main: function(component, movie) {
                    var type = movie.number_of_seasons ? 'tv' : 'movie';
                    var id = movie.imdb_id || movie.kinopoisk_id;
                    
                    if (!id) {
                        Lampa.Noty.show('У этого фильма нет KP или IMDB ID.');
                        return;
                    }

                    // Передаем фокус нашему Ридеру внутри родного интерфейса
                    Lampa.Component.add('reader', { 
                        title: 'Личный Онлайн', 
                        url: '\${myDomain}/reader-api?type=' + type + '&id=' + id
                    });
                }
            };

            // Регистрируем наш плагин в глобальном списке онлайна Lampa
            if (window.cloud_plugins) {
                window.cloud_plugins.push(inline_balancer);
            } else {
                // Если Lampa запущена в базовом режиме, добавляем кнопку в левое меню как резерв
                Lampa.Component.add('personal_online_menu', function(){
                    this.create = function(){
                        Lampa.Noty.show('Откройте карточку любого фильма для просмотра через Ридер.');
                    };
                });
                // Добавляем пункт в главное левое меню
                Lampa.MainMenu.add({
                    id: 'personal_online_btn',
                    index: 3,
                    title: 'Личный Онлайн',
                    icon: '<svg viewBox="0 0 24 24" fill="none" xmlns="http://w3.org" style="width:100%;height:100%"><path d="M21 7V17C21 18.1 20.1 19 19 19H5C3.9 19 3 18.1 3 17V7C3 5.9 3.9 5 5 5H19C20.1 5 21 5.9 21 7Z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/><path d="M10 15L15 12L10 9V15Z" fill="currentColor"/></svg>',
                    onSelect: function(){
                        Lampa.Activity.push({
                            title: 'Личный Онлайн',
                            component: 'personal_online_menu',
                            page: 1
                        });
                    }
                });
            }
        })();\`;
        
        res.end(plugin);
        return;
    }
    
    // ТОЧКА 2: Выдача онлайн потоков
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
    
    // ТОЧКА 3: Поиск торрентов
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
