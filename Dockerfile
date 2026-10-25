# syntax=docker/dockerfile:1
FROM linuxserver/prowlarr:latest

WORKDIR /app

# 1. Устанавливаем Node.js, bash и curl для работы автонастройки
RUN apk add --no-cache nodejs bash curl

# 2. Создаем файл server.js построчно (без использования <<EOF)
RUN echo "const http = require('http');" > /app/server.js \
    && echo "const https = require('https');" >> /app/server.js \
    && echo "const url = require('url');" >> /app/server.js \
    && echo "const PORT = process.env.PORT || 8080;" >> /app/server.js \
    && echo "function fetchJson(targetUrl) {" >> /app/server.js \
    && echo "    return new Promise((resolve) => {" >> /app/server.js \
    && echo "        const client = targetUrl.startsWith('https') ? https : http;" >> /app/server.js \
    && echo "        client.get(targetUrl, { timeout: 4000 }, (res) => {" >> /app/server.js \
    && echo "            let body = '';" >> /app/server.js \
    && echo "            res.on('data', chunk => body += chunk);" >> /app/server.js \
    && echo "            res.on('end', () => {" >> /app/server.js \
    && echo "                try { resolve(JSON.parse(body)); } catch(e) { resolve(null); }" >> /app/server.js \
    && echo "            });" >> /app/server.js \
    && echo "        }).on('error', () => resolve(null));" >> /app/server.js \
    && echo "    });" >> /app/server.js \
    && echo "}" >> /app/server.js \
    && echo "const server = http.createServer(async (req, res) => {" >> /app/server.js \
    && echo "    res.setHeader('Access-Control-Allow-Origin', '*');" >> /app/server.js \
    && echo "    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');" >> /app/server.js \
    && echo "    res.setHeader('Access-Control-Allow-Headers', '*');" >> /app/server.js \
    && echo "    if (req.method === 'OPTIONS') { res.writeHead(200); return res.end(); }" >> /app/server.js \
    && echo "    const parsedUrl = url.parse(req.url, true);" >> /app/server.js \
    && echo "    const myDomain = 'https://' + req.headers.host;" >> /app/server.js \
    && echo "    if (parsedUrl.pathname === '/online.js') {" >> /app/server.js \
    && echo "        res.writeHead(200, { 'Content-Type': 'application/javascript; charset=utf-8' });" >> /app/server.js \
    && echo "        const plugin = \`(function () { 'use strict'; if (!window.Lampa) return; console.log('[Личный Комбайн]: Плагин активирован.'); Lampa.Storage.set('torrserver_use', true); Lampa.Storage.set('torrserver_url', 'http://127.0.0.1:8090'); Lampa.Storage.set('parser_use', true); Lampa.Storage.set('parser_torrent_url', '\${myDomain}/search'); function ЛичныйРепозиторий(object) { var comp = this; var movie = object.card || {}; var type = movie.number_of_seasons ? 'tv' : 'movie'; var kp_id = movie.kinopoisk_id || ''; var imdb_id = movie.imdb_id || ''; var scroll = new Lampa.Scroll({mask: true, over: true}); var files = new Lampa.Files(object); this.create = function () { if (!kp_id && !imdb_id) { Lampa.Noty.show('У карточки отсутствуют KP и IMDB ID.'); return; } Lampa.network.silent('\${myDomain}/reader-api?type=' + type + '&kp=' + kp_id + '&imdb=' + imdb_id, function(data) { if (data && data.length) { var playlist = data.map(function(item) { return { title: item.title, url: item.url, quality: item.quality || '1080p' }; }); files.append({list: playlist}); scroll.append(files.render()); comp.activity.render().append(scroll.render()); comp.activity.loader(false); files.back(scroll.render()); } else { Lampa.Noty.show('Потоков онлайна не найдено.'); } }, function() { Lampa.Noty.show('Ошибка бэкенда.'); }); }; this.destroy = function () { scroll.destroy(); files.destroy(); }; this.render = function() { return comp.activity.render(); }; } Lampa.Component.add('my_private_online', ЛичныйРепозиторий); Lampa.Listener.follow('activity', function (e) { if (e.type === 'create' && e.component === 'full') { var info = e.object.card; if (info.kinopoisk_id || info.imdb_id) { setTimeout(function() { var render = e.object.render(); var buttons = render.find('.full-start-buttons'); if (buttons.length && !buttons.find('.view--my-online').length) { var btn = \$('<div class=\"full-start-new-button selector view--my-online\" style=\"background:#2196f3!important; color:#fff!important;\"><span>Посмотреть Онлайн</span></div>'); btn.on('hover:enter', function() { Lampa.Activity.push({ title: 'Личный Онлайн', component: 'my_private_online', card: e.object.card, page: 1 }); }); buttons.append(btn); if(Lampa.Controller.collection && Lampa.Controller.collection.full) { Lampa.Controller.collection.full.update(); } } }, 300); } } }); })();\`;" >> /app/server.js \
    && echo "        return res.end(plugin);" >> /app/server.js \
    && echo "    }" >> /app/server.js \
    && echo "    if (parsedUrl.pathname === '/reader-api') {" >> /app/server.js \
    && echo "        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });" >> /app/server.js \
    && echo "        const kpId = parsedUrl.query.kp || '';" >> /app/server.js \
    && echo "        const imdbId = parsedUrl.query.imdb || '';" >> /app/server.js \
    && echo "        const type = parsedUrl.query.type || 'movie';" >> /app/server.js \
    && echo "        let streams = [];" >> /app/server.js \
    && echo "        if (imdbId) {" >> /app/server.js \
    && echo "            streams.push({ title: '🌐 Зарубежный источник (Eng/Sub) [Vidsrc]', url: 'https://vidsrc.to' + type + '/' + imdbId });" >> /app/server.js \
    && echo "            streams.push({ title: '🌐 Зарубежный источник (Multi) [Vidsrc.xyz]', url: 'https://vidsrc.xyz' + type + '/' + imdbId });" >> /app/server.js \
    && echo "        }" >> /app/server.js \
    && echo "        if (kpId) {" >> /app/server.js \
    && echo "            const kinoboxData = await fetchJson('https://kinobox.tv' + kpId);" >> /app/server.js \
    && echo "            if (kinoboxData && Array.isArray(kinoboxData)) {" >> /app/server.js \
    && echo "                kinoboxData.forEach(player => {" >> /app/server.js \
    && echo "                    if (player.link) { streams.push({ title: '🍿 Русская озвучка [' + player.source.toUpperCase() + ']', url: player.link, quality: '1080p' }); }" >> /app/server.js \
    && echo "                });" >> /app/server.js \
    && echo "            }" >> /app/server.js \
    && echo "        }" >> /app/server.js \
    && echo "        return res.end(JSON.stringify(streams));" >> /app/server.js \
    && echo "    }" >> /app/server.js \
    && echo "    if (parsedUrl.pathname === '/search') {" >> /app/server.js \
    && echo "        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });" >> /app/server.js \
    && echo "        const q = parsedUrl.query.query || '';" >> /app/server.js \
    && echo "        const prowlarrUrl = 'http://127.0.0' + encodeURIComponent(q);" >> /app/server.js \
    && echo "        http.get(prowlarrUrl, { headers: { 'X-Api-Key': '1234567890abcdef1234567890abcdef' } }, (pRes) => {" >> /app/server.js \
    && echo "            let body = '';" >> /app/server.js \
    && echo "            pRes.on('data', chunk => body += chunk);" >> /app/server.js \
    && echo "            pRes.on('end', () => {" >> /app/server.js \
    && echo "                try {" >> /app/server.js \
    && echo "                    const results = JSON.parse(body);" >> /app/server.js \
    && echo "                    const lampaFormat = results.map(item => ({ title: item.title, seeders: item.seeders || 0, leechers: (item.peers - item.seeders) || 0, size: item.size, magnet: item.magnetUrl || item.downloadUrl, tracker: item.indexer }));" >> /app/server.js \
    && echo "                    res.end(JSON.stringify({ result: lampaFormat }));" >> /app/server.js \
    && echo "                } catch(e) { res.end(JSON.stringify({ result: [] })); }" >> /app/server.js \
    && echo "            });" >> /app/server.js \
    && echo "        }).on('error', () => res.end(JSON.stringify({ result: [] })));" >> /app/server.js \
    && echo "        return;" >> /app/server.js \
    && echo "    }" >> /app/server.js \
    && echo "    if (parsedUrl.pathname === '/health' || parsedUrl.pathname === '/') { res.writeHead(200, { 'Content-Type': 'text/plain' }); return res.end('OK'); }" >> /app/server.js \
    && echo "    res.writeHead(404); res.end('Not Found');" >> /app/server.js \
    && echo "});" >> /app/server.js \
    && echo "server.listen(PORT, () => console.log('Proxy Bridge active on port ' + PORT));" >> /app/server.js

# 3. Генерируем entrypoint.sh из защищенной Base64 строки (Решает проблему с символами $ и \)
