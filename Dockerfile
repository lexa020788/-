# syntax=docker/dockerfile:1
FROM linuxserver/prowlarr:latest

WORKDIR /app

# 1. Устанавливаем Node.js, bash и curl для работы автонастройки
RUN apk add --no-cache nodejs bash curl

# 2. Переписываем бэкенд-сервер
COPY <<EOF /app/server.js
const http = require('http');
const https = require('https');
const url = require('url');

const PORT = process.env.PORT || 8080;

function fetchJson(targetUrl) {
    return new Promise((resolve, reject) => {
        const client = targetUrl.startsWith('https') ? https : http;
        client.get(targetUrl, { timeout: 4000 }, (res) => {
            let body = '';
            res.on('data', chunk => body += chunk);
            res.on('end', () => {
                try { resolve(JSON.parse(body)); } 
                catch(e) { resolve(null); }
            });
        }).on('error', () => resolve(null));
    });
}

const server = http.createServer(async (req, res) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', '*');
    if (req.method === 'OPTIONS') { res.writeHead(200); return res.end(); }
    
    const parsedUrl = url.parse(req.url, true);
    const myDomain = 'https://' + req.headers.host;
    
    // ТОЧКА 1: Выдача вашего личного JS-скрипта для Lampa
    if (parsedUrl.pathname === '/online.js') {
        res.writeHead(200, { 'Content-Type': 'application/javascript; charset=utf-8' });
        
        const plugin = \`(function () { 
            'use strict'; 
            if (!window.Lampa) return; 
            
            console.log('[Личный Комбайн]: Плагин активирован.'); 
            
            // Синхронизируем настройки встроенного торрент-парсера на себя
            Lampa.Storage.set('torrserver_use', true); 
            Lampa.Storage.set('torrserver_url', 'http://127.0.0.1:8090'); 
            Lampa.Storage.set('parser_use', true); 
            Lampa.Storage.set('parser_torrent_url', '\${myDomain}/search'); 
            
            function ЛичныйРепозиторий(object) {
                var comp = this;
                var movie = object.card || {};
                var type = movie.number_of_seasons ? 'tv' : 'movie';
                var kp_id = movie.kinopoisk_id || '';
                var imdb_id = movie.imdb_id || '';
                var scroll = new Lampa.Scroll({mask: true, over: true});
                var files = new Lampa.Files(object);
                
                this.create = function () {
                    if (!kp_id && !imdb_id) {
                        Lampa.Noty.show('У карточки отсутствуют KP и IMDB ID.');
                        return;
                    }
                    
                    Lampa.network.silent('\${myDomain}/reader-api?type=' + type + '&kp=' + kp_id + '&imdb=' + imdb_id, function(data) {
                        if (data && data.length) {
                            var playlist = data.map(function(item) {
                                return {
                                    title: item.title,
                                    url: item.url,
                                    quality: item.quality || '1080p'
                                };
                            });
                            
                            files.append({list: playlist});
                            scroll.append(files.render());
                            comp.activity.render().append(scroll.render());
                            comp.activity.loader(false);
                            files.back(scroll.render());
                        } else {
                            Lampa.Noty.show('Потоков онлайна не найдено.');
                        }
                    }, function() {
                        Lampa.Noty.show('Ошибка бэкенда.');
                    });
                };

                this.destroy = function () {
                    scroll.destroy();
                    files.destroy();
                };
                
                this.render = function() {
                    return comp.activity.render();
                };
            }

            Lampa.Component.add('my_private_online', ЛичныйРепозиторий);

            Lampa.Listener.follow('activity', function (e) {
                if (e.type === 'create' && e.component === 'full') {
                    var info = e.object.card;
                    if (info.kinopoisk_id || info.imdb_id) {
                        setTimeout(function() {
                            var render = e.object.render();
                            var buttons = render.find('.full-start-buttons');
                            
                            if (buttons.length && !buttons.find('.view--my-online').length) {
                                var btn = $('<div class="full-start-new-button selector view--my-online" style="background:#2196f3!important; color:#fff!important;"><span>Посмотреть Онлайн</span></div>');
                                
                                btn.on('hover:enter', function() {
                                    Lampa.Activity.push({
                                        title: 'Личный Онлайн',
                                        component: 'my_private_online',
                                        card: e.object.card,
                                        page: 1
                                    });
                                });
                                
                                buttons.append(btn);
                                if(Lampa.Controller.collection && Lampa.Controller.collection.full) {
                                    Lampa.Controller.collection.full.update();
                                }
                            }
                        }, 300);
                    }
                }
            });
        })();\`;
        
        res.end(plugin);
        return;
    }
    
    // ТОЧКА 2: Агрегатор онлайн видеопотоков (работает без сторонних плагинов)
    if (parsedUrl.pathname === '/reader-api') {
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        
        const kpId = parsedUrl.query.kp || '';
        const imdbId = parsedUrl.query.imdb || '';
        const type = parsedUrl.query.type || 'movie';
        
        let streams = [];

        if (imdbId) {
            streams.push({
                title: '🌐 Зарубежный источник (Eng/Sub) [Vidsrc]',
                url: \`https://vidsrc.to\${type}/\${imdbId}\`
            });
            streams.push({
                title: '🌐 Зарубежный источник (Multi) [Vidsrc.xyz]',
                url: \`https://vidsrc.xyz\${type}/\${imdbId}\`
            });
        }

        if (kpId) {
            const kinoboxData = await fetchJson(\`https://kinobox.tv\${kpId}\\`);
            if (kinoboxData && Array.isArray(kinoboxData)) {
                kinoboxData.forEach(player => {
                    if (player.link) {
                        streams.push({
                            title: \`🍿 Русская озвучка [\${player.source.toUpperCase()}]\`,
                            url: player.link,
                            quality: '1080p'
                        });
                    }
                });
            }
        }

        return res.end(JSON.stringify(streams));
    }
    
    // ТОЧКА 3: Поиск торрентов через локальный Prowlarr
    if (parsedUrl.pathname === '/search') {
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        const q = parsedUrl.query.query || '';
        const prowlarrUrl = 'http://127.0.0' + encodeURIComponent(q);
        
        const http = require('http');
        http.get(prowlarrUrl, { headers: { 'X-Api-Key': '1234567890abcdef1234567890abcdef' } }, (pRes) => {
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
                    res.end(JSON.stringify({ result: lampaFormat }));
                } catch(e) { res.end(JSON.stringify({ result: [] })); }
            });
        }).on('error', () => res.end(JSON.stringify({ result: [] })));
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

# 3. Переписываем entrypoint.sh: добавляем умный авто-запуск и инжект трекеров
COPY <<EOF /app/entrypoint.sh
#!/bin/bash
mkdir -p /config

# Генерируем дефолтный конфиг Prowlarr с фиксированным API-ключом
echo '<Config><Port>9696</Port><ApiKey>1234567890abcdef1234567890abcdef</ApiKey><AuthenticationMethod>None</AuthenticationMethod></Config>' > /config/config.xml

# Запускаем Prowlarr в фоновом режиме
/usr/bin/prowlarr -nobrowser -data=/config &

echo "Ожидание инициализации Prowlarr..."
sleep 8

# === АВТОМАТИЧЕСКАЯ НАСТРОЙКА ТРЕКЕРОВ ЧЕРЕЗ API ===
API_KEY="1234567890abcdef1234567890abcdef"
PROWLARR_API="http://127.0.0"

add_indexer() {
    local payload=\$1
    curl -s -X POST "\$PROWLARR_API" \\
         -H "Content-Type: application/json" \\
         -H "X-Api-Key: \$API_KEY" \\
         -d "\$payload" > /dev/null
}

