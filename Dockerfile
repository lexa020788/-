# 1. Используем официальный готовый веб-интерфейс Lampa
FROM ghcr.io/lampa-app/lampa:latest

# 2. Прямо при сборке вживляем автозапуск твоего плагина в index.html
RUN sed -i 's|</head>|<script src="/online.js"></script></head>|g' /usr/share/nginx/html/index.html

# 3. Создаем идеальный JavaScript файл автонастройки прямо внутри папки Лампы
RUN echo '(function () {\n\
    "use strict";\n\
    var h = window.location.host;\n\
    var current_host = window.location.protocol + "//" + h;\n\
    \n\
    // 1. АВТО-РЕГИСТРАЦИЯ ТВОЕГО ПАРСЕРА\n\
    Lampa.Plugins.add("trout_custom", function () {\n\
        if (!Lampa.Extensions.add) return;\n\
        Lampa.Extensions.add("online", function (object) {\n\
            return {\n\
                search: function (movie_data) {\n\
                    var title = movie_data.movie.title || movie_data.movie.name || "";\n\
                    return "https://troutcdn.site" + encodeURIComponent(title);\n\
                }\n\
            };\n\
        });\n\
    });\n\
    \n\
    // 2. АВТО-ПРОПИСЫВАНИЕ ПАРСЕРА И ТОРРЕНТОВ В ПАМЯТЬ ЛАМПЫ\n\
    localStorage.setItem("parser_use", "true");\n\
    localStorage.setItem("parser_twyt", "true");\n\
    localStorage.setItem("parser_url", "http://jacred.xyz");\n\
    \n\
    // 3. АВТО-НАСТРОЙКА TORRSERVER (Порт 8090)\n\
    var server_ip = h.split(":");\n\
    localStorage.setItem("torrserver_url", "http://" + server_ip[0] + ":8090");\n\
    localStorage.setItem("torrserver_use", "true");\n\
    \n\
    // 4. АВТО-ЗАГРУЗКА ПЛАГИНОВ ТОРРЕНТОВ И ЗВУКА\n\
    ["http://cub.red", "http://cub.red", "http://cub.red"].forEach(function (url) {\n\
        var script = document.createElement("script");\n\
        script.src = url;\n\
        document.head.appendChild(script);\n\
    });\n\
})();' > /usr/share/nginx/html/online.js

# 4. Декларируем стандартный порт Nginx наружу для Koyeb
EXPOSE 80

# 5. Запускаем чистый веб-сервер
CMD ["nginx", "-g", "daemon off;"]
