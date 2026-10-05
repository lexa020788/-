# 1. Используем легкий образ Python
FROM python:3.10-slim

WORKDIR /app

# 2. Ставим Flask, BeautifulSoup и cloudscraper для обхода блокировок
RUN pip install --no-cache-dir flask beautifulsoup4 cloudscraper

# 3. Пишем код твоего личного Лампака
RUN echo ' \n\
import os \n\
from flask import Flask, request, jsonify \n\
import cloudscraper \n\
from bs4 import BeautifulSoup \n\
import urllib.parse \n\
\n\
app = Flask(__name__) \n\
\n\
TARGET = os.getenv("TARGET_SITE", "") \n\
\n\
# Создаем "умный" браузер, который умеет обходить Cloudflare \n\
scraper = cloudscraper.create_scraper(browser={"browser": "chrome", "platform": "windows", "desktop": True}) \n\
\n\
@app.route("/") \n\
@app.route("/coweb") \n\
def coweb_index(): \n\
    return """ \n\
    <html> \n\
    <head><title>coWeb - Мой Лампак</title></head> \n\
    <body style="font-family: sans-serif; text-align: center; margin-top: 50px; background: #141414; color: white;"> \n\
        <h1>Твой личный coWeb запущен!</h1> \n\
        <p>Ссылка для Лампы: <b style="color: #e50914;">http://\" + request.host + \"/online.js</b></p> \n\
    </body> \n\
    </html> \n\
    """, 200 \n\
\n\
@app.route("/online.js") \n\
def plugin(): \n\
    plugin_bundle = """ \n\
    (function () { \n\
        var current_host = window.location.protocol + "//" + window.location.host; \n\
        \n\
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
        var server_ip = window.location.hostname; \n\
        localStorage.setItem("torrserver_url", "http://" + server_ip + ":8090"); \n\
        localStorage.setItem("torrserver_use", "true"); \n\
        \n\
        var plugins_to_load = [ \n\
            "http://cub.red", \n\
            "http://cub.red", \n\
            "http://cub.red" \n\
        ]; \n\
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
        # Делаем запрос через скрейпер (он сам подставит нужную Mozilla 5.0 и обойдет JS-защиту) \n\
        res = scraper.get(search_url, timeout=10) \n\
        if res.status_code == 200: \n\
            soup = BeautifulSoup(res.text, "html.parser") \n\
            links = [] \n\
            \n\
            for iframe in soup.find_all("iframe", src=True): \n\
                links.append({"title": f"Смотреть онлайн [{query}]", "url": iframe["src"], "quality": "Auto"}) \n\
            \n\
            if not links: \n\
                links.append({"title": f"Открыть плеер: {query}", "url": search_url, "quality": "Auto"}) \n\
            return jsonify(links) \n\
    except: pass \n\
    return jsonify([]) \n\
\n\
if __name__ == "__main__": \n\
    app.run(host="0.0.0.0", port=8080) \n\
' > main.py

EXPOSE 8080
CMD ["python", "main.py"]
