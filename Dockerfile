# 1. Легкий образ Python
FROM python:3.10-slim

WORKDIR /app

# 2. Ставим нужные библиотеки
RUN pip install --no-cache-dir flask requests beautifulsoup4

# 3. Собираем умный скрипт
RUN echo ' \n\
import os \n\
from flask import Flask, request, jsonify \n\
import requests \n\
from bs4 import BeautifulSoup \n\
import urllib.parse \n\
\n\
app = Flask(__name__) \n\
\n\
TARGET = os.getenv("TARGET_SITE", "") \n\
HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"} \n\
\n\
@app.route("/online.js") \n\
def plugin(): \n\
    # Этот код автоматически разворачивает твой парсер и подгружает другие плагины в Лампу \n\
    plugin_bundle = """ \n\
    (function () { \n\
        // 1. АВТОМАТОМ ИНЖЕКТИРУЕМ ТВОЙ ПАРСЕР \n\
        Lampa.Plugins.add("trout_custom", function () { \n\
            Lampa.Extensions.add("online", function (object) { \n\
                var host = window.location.protocol + "//" + window.location.host; \n\
                return { \n\
                    search: function (query) { \n\
                        return host + "/search?query=" + encodeURIComponent(query.title); \n\
                    } \n\
                }; \n\
            }); \n\
        }); \n\
        \n\
        // 2. СЮДА МОЖНО ДОБАВИТЬ ЛЮБЫЕ ДРУГИЕ ПЛАГИНЫ (Они загрузятся сами!) \n\
        var plugins_to_load = [ \n\
            "http://cub.red/plugin/etor",      // Меню TorrServer для торрентов \n\
            "http://cub.red/plugin/tracks"     // Выбор аудиодорожек \n\
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
            for iframe in soup.find_all("iframe", src=True): \n\
                links.append({"title": f"Смотреть: {query}", "url": iframe["src"], "quality": "Auto"}) \n\
            \n\
            if not links: \n\
                links.append({"title": f"Открыть плеер: {query}", "url": search_url, "quality": "Auto"}) \n\
            return jsonify(links) \n\
    except: pass \n\
    return jsonify([]) \n\
\n\
if __name__ == "__main__": \n\
    app.run(host="0.0.0.0", port=9118) \n\
' > main.py

EXPOSE 9118
CMD ["python", "main.py"]
