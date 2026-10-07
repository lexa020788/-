# 1. Используем официальный стабильный образ Python
FROM python:3.10-slim

# 2. Указываем рабочую папку
WORKDIR /app

# 3. Устанавливаем библиотеки для парсинга и обхода защит сайта
RUN pip install --no-cache-dir flask beautifulsoup4 cloudscraper gunicorn

# 4. Пишем код твоего личного Лампака
RUN cat << 'EOF' > main.py
import os
import urllib.parse
from flask import Flask, request, jsonify, make_response
import cloudscraper
from bs4 import BeautifulSoup

app = Flask(__name__)

# Ссылка на скрытый сайт берется из переменных окружения в куебе
TARGET = os.getenv("TARGET_SITE", "")

# Создаем умный скрейпер для обхода Cloudflare под видом Windows Chrome
scraper = cloudscraper.create_scraper(browser={"browser": "chrome", "platform": "windows", "desktop": True})

@app.route("/")
@app.route("/coweb")
def coweb_index():
    host_addr = request.host
    return f"""
    <html>
    <head><title>coWeb - Мой Лампак</title></head>
    <body style="font-family: sans-serif; text-align: center; margin-top: 50px; background: #141414; color: white;">
        <h1>Твой личный coWeb запущен!</h1>
        <p>Ссылка для Лампы: <b style="color: #e50914;">http://{host_addr}/online.js</b></p>
    </body>
    </html>
    """, 200

@app.route("/online.js")
def plugin():
    host_addr = request.host
    plugin_bundle = f"""
    (function () {{
        var current_host = window.location.protocol + "//" + "{host_addr}";
        
        Lampa.Plugins.add("trout_custom", function () {{
            Lampa.Extensions.add("online", function (object) {{
                return {{
                    search: function (query) {{
                        return current_host + "/search?query=" + encodeURIComponent(query.title);
                    }}
                }};
            }}});
        }});
        
        var server_ip = "{host_addr}".split(":");
        localStorage.setItem("torrserver_url", "http://" + server_ip + ":8090");
        localStorage.setItem("torrserver_use", "true");
        
        var plugins_to_load = [
            "http://cub.red",
            "http://cub.red",
            "http://cub.red"
        ];
        plugins_to_load.forEach(function(url) {{
            var script = document.createElement("script");
            script.src = url;
            document.head.appendChild(script);
        }});
    }})();
    """
    response = make_response(plugin_bundle)
    response.headers["Content-Type"] = "application/javascript"
    response.headers["Access-Control-Allow-Origin"] = "*"
    return response

@app.route("/search")
def search():
    query = request.args.get("query", "")
    if not query or not TARGET: return jsonify([])
    search_url = f"{TARGET}/search?query={urllib.parse.quote(query)}"
    try:
        res = scraper.get(search_url, timeout=10)
        if res.status_code == 200:
            soup = BeautifulSoup(res.text, "html.parser")
            links = []
            for iframe in soup.find_all("iframe", src=True):
                links.append({{"title": f"Смотреть онлайн [{{query}}]", "url": iframe["src"], "quality": "Auto"}})
            if not links:
                links.append({{"title": f"Открыть плеер: {{query}}", "url": search_url, "quality": "Auto"}})
            
            resp = jsonify(links)
            resp.headers["Access-Control-Allow-Origin"] = "*"
            return resp
    except: pass
    
    empty_resp = jsonify([])
    empty_resp.headers["Access-Control-Allow-Origin"] = "*"
    return empty_resp

if __name__ == "__main__":
    # Жестко связываем внутренности с внешним портом 8080 хостинга
    app.run(host="0.0.0.0", port=8080)
EOF

# 5. Декларируем внутренний порт контейнера строго как в куебе
EXPOSE 8080

# 6. Запускаем сервер через gunicorn на порту 8080
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "main:app"]
