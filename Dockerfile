# syntax=docker/dockerfile:1
FROM linuxserver/prowlarr:latest

WORKDIR /app

# 1. Устанавливаем Node.js, bash и скачиваем веб-версию Lampa для автозапуска
RUN apk add --no-cache nodejs bash curl unzip && \
    mkdir -p /app/lampa && \
    curl -L -o /tmp/lampa.zip https://github.com && \
    unzip /tmp/lampa.zip -d /tmp && \
    cp -r /tmp/lampa-main/* /app/lampa/ && \
    rm -rf /tmp/lampa.zip /tmp/lampa-main

# 2. Создаем сервер-мост (Автозапуск Lampa + Торренты + Чистый онлайн)
COPY <<EOF /app/server.js
const http = require('http');
const url = require('url');
const fs = require('fs');
const path = require('path');

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
            
            // Настройка встроенного Торрент-Парсера Лампы на ваш Koyeb
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
    
    // ТОЧКА 2: Ридер-API (Прямые видео-потоки без рекламы)
    if (parsedUrl.pathname === '/reader-api') {
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        const id = parsedUrl.query.id;
        const type = parsedUrl.query.type || 'movie';
        const title = parsedUrl.query.title || 'Видео';
        
        const https = require('https');
        // Запрос к бесплатному открытому API балансера Alloha
        const allohaUrl = 'https://alloha.tv' + id;
        
        https.get(allohaUrl, (apiRes) => {
            let body = '';
            apiRes.on('data', chunk => body += chunk);
            apiRes.on('end', () => {
                try {
                    const data = JSON.parse(body);
                    let readerResponse = [];
                    
                    if (data && data.data) {
                        if (type === 'movie' && data.data.files) {
                            // Для фильмов собираем разные переводы
                            Object.keys(data.data.files).forEach(translation => {
                                const fileData = data.data.files[translation];
                                if (fileData.link) {
                                    readerResponse.push({
                                        title: title + ' (' + translation + ')',
                                        url: fileData.link,
                                        quality: '1080p',
                                        ready: true
                                    });
                                }
                            });
                        } else if (type === 'tv' && data.data.seasons) {
                            // Для сериалов разворачиваем структуру сезонов и серий
                            Object.keys(data.data.seasons).forEach(sNum => {
                                const season = data.data.seasons[sNum];
                                if (season.episodes) {
                                    Object.keys(season.episodes).forEach(eNum => {
                                        const episode = season.episodes[eNum];
                                        // Берем первый доступный перевод для простоты вывода
                                        const firstTranslation = Object.keys(episode.translations || {})[0];
                                        if (firstTranslation && episode.translations[firstTranslation].link) {
                                            readerResponse.push({
                                                title: \`Сезон \${sNum}, Серия \${eNum} (\${firstTranslation})\`,
                                                url: episode.translations[firstTranslation].link,
                                                ready: true
                                            });
                                        }
                                    });
                                }
                            });
                        }
                    }
                    res.end(JSON.stringify(readerResponse));
                } catch(e) { res.end(JSON.stringify([])); }
            });
        }).on('error', () => res.end(JSON.stringify([])));
        return;
    }
    
    // ТОЧКА 3: Поиск торрентов через Prowlarr
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
                    res.end(JSON.stringify({ result: lampaFormat }));
                } catch(e) { res.end(JSON.stringify({ result: [] })); }
            });
        }).on('error', () => res.end(JSON.stringify({ result: [] })));
        return;
    }
    
    // ТОЧКА 4: Раздача веб-интерфейса Lampa напрямую с Koyeb
    let filePath = path.join('/app/lampa', parsedUrl.pathname === '/' ? 'index.html' : parsedUrl.pathname);
    
    // Если файл не существует, пробуем отдать index.html (для SPA роутинга Lampa)
    if (!fs.existsSync(filePath)) {
        filePath = path.join('/app/lampa', 'index.html');
    }

    fs.readFile(filePath, (err, data) => {
        if (err) {
            res.writeHead(404);
            return res.end('Not Found');
        }
        
        // Автоматически внедряем наш плагин при загрузке главной страницы Lampa
        if (parsedUrl.pathname === '/' || parsedUrl.pathname === '/index.html') {
            let html = data.toString();
            const injectScript = \`<script>
                setTimeout(function() {
                    if (window.Lampa) {
                        // Авто-подключение нашего онлайн и торрент плагина
                        Lampa.Plugins.add({
                            url: '\${myDomain}/online.js',
                            name: 'Cherry Proxy Inline',
                            status: 1
                        });
                    }
                }, 1000);
            </script>\`;
            html = html.replace('</head>', injectScript + '</head>');
            res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
            return res.end(html);
        }

        // Простая установка MIME-типов для статики Лампы
        const ext = path.extname(filePath);
        let contentType = 'text/plain';
        if (ext === '.html') contentType = 'text/html';
        if (ext === '.js') contentType = 'application/javascript';
        if (ext === '.css') contentType = 'text/css';
        if (ext === '.json') contentType = 'application/json';
        if (ext === '.png') contentType = 'image/png';
        
        res.writeHead(200, { 'Content-Type': contentType });
        res.end(data);
    });
});

server.listen(PORT, () => console.log('Proxy Bridge active on port ' + PORT));
EOF

# 3. Точка входа
COPY <<EOF /app/entrypoint.sh
#!/bin/bash
mkdir -p /config
echo '<Config><Port>9696</Port><ApiKey>1234567890abcdef1234567890abcdef</ApiKey><AuthenticationMethod>None</AuthenticationMethod></Config>' > /config/config.xml
