# 1. Берем официальный легкий образ Node.js
FROM node:20-alpine

# 2. Создаем рабочую папку в контейнере
WORKDIR /private-lampa

# 3. Записываем весь сервер прямо внутрь контейнера одной командой
RUN echo "const http = require('http'); \
const url = require('url'); \
const SECRET_TOKEN = process.env.SECRET_TOKEN || 'my_lampa_secret_2026'; \
const PORT = process.env.PORT || 8080; \
const pluginCode = \`(function () { \
    'use strict'; \
    if (!window.Lampa) return; \
    console.log('[Личный плагин]: Успешно авторизован.'); \
    if (Lampa.Storage.get('torrserver_use') === null || Lampa.Storage.get('torrserver_use') === false) { \
        Lampa.Storage.set('torrserver_use', true); \
    } \
    Lampa.Storage.set('torrserver_url', 'http://192.168.1.50:8090'); \
    Lampa.Storage.set('parser_use', true); \
    Lampa.Storage.set('parser_torrent_url', 'https://jacred.xyz'); \
    Lampa.Listener.follow('full', function (e) { \
        if (e.type == 'complite') { \
            var movie = e.data.movie; \
            var kpId = movie.kinopoisk_id; \
            var imdbId = movie.imdb_id; \
            if (!kpId && !imdbId) return; \
            var button = \$('<div class=\"full-start__button class_personal_online selector\">Личный Онлайн</div>'); \
            button.on('hover:enter', function () { \
                Lampa.Select.show({ \
                    title: 'Выбор источника видео', \
                    items: [ \
                        { title: 'Запустить плеер Krakens (Агрегатор)', id: 'krakens' }, \
                        { title: 'Запустить плеер View (Резерв)', id: 'view' } \
                    ], \
                    onSelect: function(item) { \
                        var videoUrl = item.id === 'krakens' ? 'https://krakens.cc' + kpId : 'https://vidsrc.me' + (imdbId || kpId); \
                        Lampa.Player.play({ url: videoUrl, title: movie.title }); \
                    } \
                }); \
            }); \
            e.object.find('.full-start__buttons').append(button); \
        } \
    }); \
})();\`; \
const server = http.createServer((req, res) => { \
    const parsedUrl = url.parse(req.url, true); \
    if (parsedUrl.pathname === '/online.js' && parsedUrl.query.token === SECRET_TOKEN) { \
        res.writeHead(200, { 'Content-Type': 'application/javascript; charset=utf-8', 'Access-Control-Allow-Origin': '*' }); \
        res.end(pluginCode); \
    } else { \
        res.writeHead(403, { 'Content-Type': 'text/plain; charset=utf-8' }); \
        res.end('Access Denied.'); \
    } \
}); \
server.listen(PORT, () => console.log('Server running on port ' + PORT));\" > server.js

# 4. Открываем сетевой порт
EXPOSE 8080

# 5. Инструкция для старта
CMD ["node", "server.js"]
