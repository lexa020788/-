# --- Stage 1: Установка зависимостей ---
FROM debian:13-slim AS builder
RUN apt-get update && apt-get install -y --no-install-recommends python3-pip python3-venv && rm -rf /var/lib/apt/lists/*

# --- Stage 2: Рабочая среда ---
FROM debian:13-slim AS runner
WORKDIR /app

# Открываем бесконфликтный порт 8080 для Koyeb
EXPOSE 8080

# Устанавливаем системный Nginx, Python и Tini для контроля процессов
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl nginx tini python3 python3-pip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Ставим библиотеки Python для твоего личного парсера контента
RUN pip install --no-cache-dir --break-system-packages flask beautifulsoup4 requests gunicorn

# Прописываем конфигурацию Nginx как прямой мост на порту 8080
RUN echo 'server { \n\
    listen 8080; \n\
    server_name _; \n\
\n\
    # Разрешаем CORS-заголовки, чтобы Lampa на ТВ не блокировала плагин \n\
    add_header "Access-Control-Allow-Origin" "*" always; \n\
    add_header "Access-Control-Allow-Methods" "GET, OPTIONS" always; \n\
    add_header "Access-Control-Allow-Headers" "*" always; \n\
\n\
    # Мост: Nginx принимает запросы с 8080 и передает их твоему парсеру \n\
    location / { \n\
        proxy_pass http://127.0.0.1:9118; \n\
        proxy_set_header Host $host; \n\
        proxy_set_header X-Real-IP $remote_addr; \n\
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; \n\
    } \n\
}' > /etc/nginx/sites-available/default

# Пишем код твоего личного Лампака (теперь он скрыт за Nginx на внутреннем порту 9118)
RUN cat << 'EOF' > main.py
import os
import urllib.parse
import requests
from flask import Flask, request, jsonify, make_response
from bs4 import BeautifulSoup

app = Flask(__name__)
TARGET = os.getenv("TARGET_SITE", "")

@app.route("/")
def index(): 
    return "<h1>Мой Личный HTTP coWeb Активен!</h1>", 200

@app.route("/online.js")
def plugin():
    h = request.host
    
    # Кристально чистый JavaScript-код плагина, полностью написанный под твои задачи
    js = f"""(function () {{
        'use strict';

        // 1. АВТО-РЕГИСТРАЦИЯ ТВОЕГО ОНЛАЙН-ПАРСЕРА
        Lampa.Plugins.add("trout_custom", function () {{
            if (!Lampa.Extensions.add) return;

            Lampa.Extensions.add("online", function (object) {{
                var current_host = window.location.protocol + "//" + "{h}";
                return {{
                    search: function (movie_data) {{
                        var title = movie_data.movie.title || movie_data.movie.name || '';
                        return current_host + "/search?query=" + encodeURIComponent(title);
                    }}
                }};
            }});
        }});

        // 2. АВТОМАТИЧЕСКАЯ НАСТРОЙКА ТОРРЕНТОВ НА ТВОЙ TORRSERVER (Порт 8090)
        var ip = "{h}".split(":");
        localStorage.setItem("torrserver_url", "http://" + ip[0] + ":8090");
        localStorage.setItem("torrserver_use", "true");
        localStorage.setItem("parser_use", "false"); 
    }})();"""
    
    r = make_response(js)
    r.headers["Content-Type"] = "application/javascript"
    r.headers["Access-Control-Allow-Origin"] = "*"
    return r

@app.route("/search")
def search():
    q = request.args.get("query", "")
    if not q or not TARGET: return jsonify([])
    try:
        # Твой сервер идет на твой пиратский сайт под видом реальной Mozilla 5.0
        res = requests.get(f"{TARGET}/search?query={urllib.parse.quote(q)}", timeout=10, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"})
        if res.status_code == 200:
            soup = BeautifulSoup(res.text, "html.parser")
            links = []
            
            # Вырезаем iframe плеера из верстки твоего сайта
            for iframe in soup.find_all("iframe", src=True):
                links.append({"title": f"Смотреть онлайн [{q}]", "url": iframe["src"], "quality": "Auto"})
                
            # Если плееры спрятаны, даем прямую ссылку на поиск этого фильма на сайте
            if not links: 
                links.append({"title": f"Открыть плеер: {q}", "url": f"{TARGET}/search?query={urllib.parse.quote(q)}", "quality": "Auto"})
            
            resp = jsonify(links)
            resp.headers["Access-Control-Allow-Origin"] = "*"
            return resp
    except: pass
    
    empty_resp = jsonify([])
    empty_resp.headers["Access-Control-Allow-Origin"] = "*"
    return empty_resp

if __name__ == "__main__": 
    app.run(host="127.0.0.1", port=9118)
EOF

RUN mkdir -p /run/nginx && chmod -R 777 /app /var/lib/nginx /var/log/nginx /run/nginx

# Инициализируем чистый стартер через Tini
RUN printf 'import subprocess\n\
import os\n\
subprocess.Popen(["nginx"])\n\
os.execv("/usr/bin/gunicorn", ["gunicorn", "--bind", "127.0.0.1:9118", "main:app"])\n\
' > /app/entrypoint.py

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["python3", "/app/entrypoint.py"]
