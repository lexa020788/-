const http = require('http');
const https = require('https');
const url = require('url');

const PORT = process.env.PORT || 8080;

function fetchJson(targetUrl) {
    return new Promise((resolve) => {
        const client = targetUrl.startsWith('https') ? https : http;
        client.get(targetUrl, { timeout: 4000 }, (res) => {
            let body = '';
            res.on('data', chunk => body += chunk);
            res.on('end', () => {
                try { resolve(JSON.parse(body)); } catch(e) { resolve(null); }
            });
        }).on('error', () => resolve(null));
    });
}

const server = http.createServer(async (req, res) => {
    // Выставляем жесткие CORS-заголовки для борьбы с блокировками браузеров
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', '*');
    res.setHeader('Access-Control-Allow-Private-Network', 'true');
    
    if (req.method === 'OPTIONS') { 
        res.writeHead(200); 
        return res.end(); 
    }
    
    const parsedUrl = url.parse(req.url, true);
    const myDomain = 'https://' + req.headers.host;
    
    // ТОЧКА 1: Выдача плагина со встроенной поддержкой CORS
    if (parsedUrl.pathname === '/online.js') {
        res.writeHead(200, { 'Content-Type': 'application/javascript; charset=utf-8' });
        
        const plugin = `(function () { 
            'use strict'; 
            if (!window.Lampa) return; 
            
            console.log('[Личный Про-Плагин]: Мобильный и ТВ плагин запущен.'); 
            
            // Синхронизация торрент-поиска на себя
            Lampa.Storage.set('torrserver_use', true); 
            Lampa.Storage.set('torrserver_url', 'http://127.0.0.1:8090'); 
            Lampa.Storage.set('parser_use', true); 
            Lampa.Storage.set('parser_torrent_url', '${myDomain}/search'); 
            
            function ЛичныйПарсер(object) {
                var comp = this;
                var movie = object.card || {};
                var type = movie.number_of_seasons ? 'tv' : 'movie';
                var kp_id = movie.kinopoisk_id || '';
                var imdb_id = movie.imdb_id || '';
                
                this.create = function () {
                    if (!kp_id && !imdb_id) {
                        Lampa.Noty.show('Нет KP или IMDB ID');
                        return;
                    }
                    comp.activity.loader(true);
                    Lampa.network.silent('${myDomain}/reader-api?type=' + type + '&kp=' + kp_id + '&imdb=' + imdb_id, function (data) {
                        comp.activity.loader(false);
                        if (data && data.length) {
                            var playlist = data.map(function (item) {
                                return { title: item.title, url: item.url, quality: '1080p' };
                            });
                            var scroll = new Lampa.Scroll({ mask: true, over: true });
                            var files = new Lampa.Files(object);
                            files.append({ list: playlist });
                            scroll.append(files.render());
                            comp.activity.render().append(scroll.render());
                            files.back(scroll.render());
                        } else {
                            Lampa.Noty.show('Потоков не найдено.');
                        }
                    }, function () {
                        comp.activity.loader(false);
                        Lampa.Noty.show('Ошибка бэкенда.');
                    });
                };
                this.destroy = function () {};
                this.render = function () { return comp.activity.render(); };
            }
            
            // Регистрируем компонент в системе Lampa
            Lampa.Component.add('my_private_online', ЛичныйПарсер);
            
            // Самый надежный и совместимый метод внедрения кнопки для мобильных (через Full)
            Lampa.Listener.follow('activity', function (e) {
                if (e.type === 'create' && e.component === 'full') {
                    setTimeout(function() {
                        var page = e.object;
                        if (page && page.plugins && typeof page.plugins.add === 'function') {
                            page.plugins.add({
                                name: 'Личный Онлайн',
                                icon: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://w3.org"><path d="M21 7V17C21 18.1 20.1 19 19 19H5C3.9 19 3 18.1 3 17V7C3 5.9 3.9 5 5 5H19C20.1 5 21 5.9 21 7ZM19 7H5V17H19V7Z" fill="currentColor"/><path d="M10 9.5V14.5L14.5 12L10 9.5Z" fill="currentColor"/></svg>',
                                click: function() {
                                    Lampa.Activity.push({
                                        title: 'Личный Онлайн',
                                        component: 'my_private_online',
                                        card: e.object.card,
                                        page: 1
                                    });
                                }
                            });
                        }
                    }, 400);
                }
            });
        })();`;
        
        return res.end(plugin);
    }
    
    // ТОЧКА 2: Сбор потоков с балансеров
    if (parsedUrl.pathname === '/reader-api') {
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        const kpId = parsedUrl.query.kp || '';
        const imdbId = parsedUrl.query.imdb || '';
        const type = parsedUrl.query.type || 'movie';
        let streams = [];
        
        if (imdbId) {
            streams.push({ title: '🌐 Зарубежный источник (Eng/Sub) [Vidsrc]', url: 'https://vidsrc.to' + type + '/' + imdbId });
            streams.push({ title: '🌐 Зарубежный источник (Multi) [Vidsrc.xyz]', url: 'https://vidsrc.xyz' + type + '/' + imdbId });
        }
        if (kpId) {
            const kinoboxData = await fetchJson('https://kinobox.tv' + kpId);
            if (kinoboxData && Array.isArray(kinoboxData)) {
                kinoboxData.forEach(player => {
                    if (player.link) {
                        streams.push({ title: '🍿 Русская озвучка [' + player.source.toUpperCase() + ']', url: player.link });
                    }
                });
            }
        }
        return res.end(JSON.stringify(streams));
    }
    
    // ТОЧКА 3: Торрент-поиск через Prowlarr
    if (parsedUrl.pathname === '/search') {
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        const q = parsedUrl.query.query || '';
        const prowlarrUrl = 'http://127.0.0' + encodeURIComponent(q);
        
        http.get(prowlarrUrl, { headers: { 'X-Api-Key': '1234567890abcdef1234567890abcdef' } }, (pRes) => {
            let body = '';
            pRes.on('data', chunk => body += chunk);
            pRes.on('end', () => {
                try {
                    const results = JSON.parse(body);
                    const lampaFormat = results.map(item => ({ title: item.title, seeders: item.seeders || 0, leechers: (item.peers - item.seeders) || 0, size: item.size, magnet: item.magnetUrl || item.downloadUrl, tracker: item.indexer }));
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
