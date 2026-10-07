# 1. Используем легкий образ Python
FROM python:3.10-slim

# 2. Устанавливаем системный Nginx и библиотеки Python
RUN apt-get update && apt-get install -y nginx && rm -rf /var/list/apt/lists/*
RUN pip install --no-cache-dir flask beautifulsoup4 cloudscraper gunicorn

WORKDIR /app

# 3. Зашиваем конфигурацию Nginx прямо при сборке контейнера
# Настраиваем его так, чтобы он слушал порт от Koyeb и отдавал файлы
RUN echo ' \n\
server { \n\
    listen 8080; \n\
    server_name _; \n\
\n\
    # Разрешаем CORS, чтобы Lampa не блокировала плагин \n\
    add_header "Access-Control-Allow-Origin" "*"; \n\
    add_header "Access-Control-Allow-Methods" "GET, OPTIONS"; \n\
    add_header "Access-Control-Allow-Headers" "*"; \n\
\n\
    # Перенаправляем запросы Лампы на наш внутренний Python-парсер \n\
    location / { \n\
        proxy_pass http://127.0.0.1:5000; \n\
        proxy_set_header Host $host; \n\
        proxy_set_header X-Real-IP $remote_addr; \n\
    } \n\
} \n\
' > /etc/nginx/sites-available/default

# 4. Пишем код твоего личного Лампака (теперь он скрыт за Nginx на порту 5000)
RUN cat << 'EOF' > main.py
import os
import urllib.parse
from flask import Flask, request, jsonify, make_response
import cloudscraper
from bs4 import BeautifulSoup

app = Flask(__name__)
TARGET = os.getenv("TARGET_SITE", "")
scraper = cloudscraper.create_scraper(browser={"browser": "chrome", "platform": "windows", "desktop": True})

@app.route("/")
@app.route("/coweb")
def coweb_index():
    host_addr = request.host
    return f"<h1>Личный coWeb запущен!</h1><p>Ссылка для Лампы: http://{host_addr}/online.js</p>", 200

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
    }})();
    """
    response = make_response(plugin_bundle)
    response.headers["Content-Type"] = "application/javascript"
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
            return jsonify(links)
    except: pass
    return jsonify([])

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000)
EOF

# 5. Декларируем внешний порт Nginx для Koyeb
EXPOSE 8080

# 6. Запускаем одновременно и веб-сервер Nginx, и твой Python-парсер
CMD service nginx start && gunicorn --bind 127.0.0.1:5000 main:app
