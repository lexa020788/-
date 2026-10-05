# 1. Используем официальный легкий образ Python
FROM python:3.10-slim

# 2. Указываем рабочую папку внутри контейнера
WORKDIR /app

# 3. Устанавливаем библиотеки для работы с сетью и парсинга сайта
RUN pip install --no-cache-dir flask requests beautifulsoup4

# 4. Прописываем всю логику личного Лампака прямо в один исполняемый файл
RUN echo ' \n\
import os \n\
from flask import Flask, request, jsonify \n\
import requests \n\
from bs4 import BeautifulSoup \n\
import urllib.parse \n\
\n\
app = Flask(__name__) \n\
\n\
# Ссылка на скрытый сайт берется из памяти (из вкладки Env в куебе) \n\
TARGET = os.getenv("TARGET_SITE", "") \n\
HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"} \n\
\n\
# СТРАНИЦА ТВОЕГО COWEB (Откроется по порту 8080) \n\
@app.route("/") \n\
@app.route("/coweb") \n\
def coweb_index(): \n\
    return """ \n\
    <html> \n\
    <head><title>coWeb - Твой Личный Лампак</title></head> \n\
    <body style="font-family: sans-serif; text-align: center; margin-top: 50px; background: #141414; color: white;"> \n\
        <h1>Панель управления coWeb активна!</h1> \n\
        <p>Твой личный Лампак успешно скрещен со скрытым сайтом.</p> \n\
        <p>Ссылка для добавления в приложение Lampa: <b style="color: #e50914;">http://\" + request.host + \"/online.js</b></p> \n\
    </body> \n\
    </html> \n\
    """, 200 \n\
\n\
@app.route("/online.js") \n\
def plugin(): \n\
    # Этот авто-скрипт выдаст Лампе на ТВ твой парсер и сам настроит торренты с остальными плагинами \n\
    plugin_bundle = """ \n\
    (function () { \n\
        var current_host = window.location.protocol + "//" + window.location.host; \n\
        \n\
        // 1. АВТОМАТИЧЕСКИЙ ПЛАГИН ОНЛАЙНА ДЛЯ ТВОЕГО СКРЫТОГО САЙТА \n\
        Lampa.Plugins.add("trout_custom", function () { \n\
            Lampa.Extensions.add("online", function (object) { \n\
                return { \n\
                    search: function (query) { \n\
                        return current_host + "/search?query=" + encodeURIComponent(query.title); \n\
                    } \n\
                }; \n\
            }); \n\
        }); \n\
        \n\
        // 2. АВТО-ПРИВЯЗКА ТОРРЕНТОВ (Записываем твой TorrServer на порту 8090 в память Лампы) \n\
        var server_ip = window.location.hostname; \n\
        localStorage.setItem("torrserver_url", "http://" + server_ip + ":8090"); \n\
        localStorage.setItem("torrserver_use", "true"); \n\
        \n\
        // 3. АВТО-УСТАНОВКА ВСЕХ НЕОБХОДИМЫХ СИСТЕМНЫХ ПЛАГИНОВ \n\
        var plugins_to_load = [ \n\
            "http://cub.red",      // Интерфейс TorrServer внутри Лампы \n\
            "http://cub.red",    // Плагин для переключения аудиодорожек \n\
            "http://cub.red"     // Поисковик торрент-раздач JacRed \n\
        ]; \n\
        \n\
        plugins_to_load.forEach(function(url) { \n\
            var script = document.createElement("script"); \n\
            script.src = url; \n\
            document.head.appendChild(script); \n\
        }); \n\
    })(); \n\
    """ \n\
    return plugin_bundle, 200, {"Content-Type": "application/javascript"} \n\
\n\
@app.route("/search") \n\
def search(): \n\
    query = request.args.get("query", "") \n\
    if not query or not TARGET: return jsonify([]) \n\
    \n\
    search_url = f"{TARGET}/search?query={urllib.parse.quote(query)}" \n\
    try: \n\
        res = requests.get(search_url, headers=HEADERS, timeout=10) \n\
        if res.status_code == 200: \n\
            soup = BeautifulSoup(res.text, "html.parser") \n\
            links = [] \n\
            \n\
            # Ищем встроенные плееры (iframe) в движке сайта \n\
            for iframe in soup.find_all("iframe", src=True): \n\
                links.append({"title": f"Смотреть онлайн [{query}]", "url": iframe["src"], "quality": "Auto"}) \n\
            \n\
            # Если плеер скрыт скриптами сайта, даем прямую ссылку на его поисковую страницу \n\
            if not links: \n\
                links.append({"title": f"Открыть плеер: {query}", "url": search_url, "quality": "Auto"}) \n\
            return jsonify(links) \n\
    except: pass \n\
    return jsonify([]) \n\
\n\
if __name__ == "__main__": \n\
    # Внутренний сервер скрипта теперь слушает порт 8080 \n\
    app.run(host="0.0.0.0", port=8080) \n\
' > main.py

# 5. Декларируем внутренний порт контейнера
EXPOSE 8080

# 6. Команда на запуск нашего личного бэкенда
CMD ["python", "main.py"]
