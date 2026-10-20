FROM alpine:latest AS builder

# Устанавливаем git и скачиваем официальный веб-интерфейс Lampa
RUN apk add --no-cache git && \
    git clone https://github.com /app

# Создаем скрипт автонастройки, который запустится раньше самой Lampa
RUN echo "(function () {" > /app/autoconfig.js && \
    echo "    'use strict';" >> /app/autoconfig.js && \
    echo "    // 1. Включаем торренты и связываем с внешним TorrServer на ТВ" >> /app/autoconfig.js && \
    echo "    localStorage.setItem('torrent_use', 'true');" >> /app/autoconfig.js && \
    echo "    localStorage.setItem('torrent_url', 'http://127.0.0.1:8090');" >> /app/autoconfig.js && \
    echo "    // 2. Включаем парсер и прописываем бесплатный JacRed" >> /app/autoconfig.js && \
    echo "    localStorage.setItem('parser_use', 'true');" >> /app/autoconfig.js && \
    echo "    localStorage.setItem('parser_url', 'https://jacred.xyz');" >> /app/autoconfig.js && \
    echo "    // 3. Автоматически инжектируем список необходимых плагинов" >> /app/autoconfig.js && \
    echo "    var required = [" >> /app/autoconfig.js && \
    echo "        { url: 'https://cub.red', status: 1, name: 'TMDB Proxy' }," >> /app/autoconfig.js && \
    echo "        { url: 'https://cub.red', status: 1, name: 'VTT Субтитры' }" >> /app/autoconfig.js && \
    echo "    ];" >> /app/autoconfig.js && \
    echo "    localStorage.setItem('plugins', JSON.stringify(required));" >> /app/autoconfig.js && \
    echo "    // 4. Описываем и регистрируем чистый онлайн-плагин для VideoCDN" >> /app/autoconfig.js && \
    echo "    function VideoCDNPlugin() {" >> /app/autoconfig.js && \
    echo "        this.search = function (object) {" >> /app/autoconfig.js && \
    echo "            var kp_id = object.movie.kinopoisk_id;" >> /app/autoconfig.js && \
    echo "            var imdb_id = object.movie.imdb_id;" >> /app/autoconfig.js && \
    echo "            if (!kp_id && !imdb_id) { object.empty('Нет ID для поиска в VideoCDN'); return; }" >> /app/autoconfig.js && \
    echo "            var apiToken = '3iYmYv7asdfAlS6o73asdfg';" >> /app/autoconfig.js && \
    echo "            var url = 'https://videocdn.tv' + apiToken + (kp_id ? '&kinopoisk_id=' + kp_id : '&imdb_id=' + imdb_id);" >> /app/autoconfig.js && \
    echo "            Lampa.Network.silent(url, function (json) {" >> /app/autoconfig.js && \
    echo "                if (json && json.data && json.data.length > 0) {" >> /app/autoconfig.js && \
    echo "                    object.create([{ title: 'Смотреть Онлайн (VideoCDN) - 1080p', url: json.data.iframe_url, quality: '1080p' }]);" >> /app/autoconfig.js && \
    echo "                } else { object.empty('В базе VideoCDN ничего не найдено'); }" >> /app/autoconfig.js && \
    echo "            }, function () { object.empty('Ошибка сети при обращении к VideoCDN'); });" >> /app/autoconfig.js && \
    echo "        };" >> /app/autoconfig.js && \
    echo "    }" >> /app/autoconfig.js && \
    echo "    // Дожидаемся инициализации плагинов Lampa и добавляем вкладку" >> /app/autoconfig.js && \
    echo "    window.addEventListener('load', function() {" >> /app/autoconfig.js && \
    echo "        if (typeof Lampa !== 'undefined') {" >> /app/autoconfig.js && \
    echo "            Lampa.Plugins.add('koyeb_combo_mod', function () {" >> /app/autoconfig.js && \
    echo "                Lampa.Online.add('videocdn', VideoCDNPlugin);" >> /app/autoconfig.js && \
    echo "            });" >> /app/autoconfig.js && \
    echo "        }" >> /app/autoconfig.js && \
    echo "    });" >> /app/autoconfig.js && \
    echo "})();" >> /app/autoconfig.js

# Внедряем наш автоконфиг в официальный index.html перед основными скриптами Lampa
RUN sed -i 's/<script src="app.min.js[^"]*"><\/script>/<script src="autoconfig.js"><\/script><script src="app.min.js"><\/script>/' /app/index.html

# Этап сборки финального ультра-легкого веб-сервера
FROM nginx:alpine
COPY --from=builder /app /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
