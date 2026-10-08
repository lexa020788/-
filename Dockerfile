# --- Stage 1: Скачивание чистого интерфейса Lampa ---
FROM debian:13-slim AS builder
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl xz-utils unzip git && rm -rf /var/lib/apt/lists/*
WORKDIR /build
RUN curl -fSL -o lampa.zip https://github.com && \
    unzip lampa.zip && mv lampa-main web && rm -rf lampa.zip

# --- Stage 2: Рабочая среда (Nginx + Python Парсер) ---
FROM debian:13-slim AS runner
WORKDIR /app

# Открываем порт 8080 для Koyeb
EXPOSE 8080

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl nginx tini python3 python3-pip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir --break-system-packages flask beautifulsoup4 requests gunicorn

# Копируем интерфейс Лампы в папку веб-сервера
COPY --from=builder /build/web /app/wroot

# Автоматически вживляем автозапуск твоего плагина прямо в код Лампы при сборке
RUN sed -i 's|</head>|<script src="/online.js"></script></head>|g' /app/wroot/index.html

# Настраиваем Nginx: порт 8080 наружу, раздает интерфейс и проксирует запросы к парсеру
RUN echo 'server { \n\
    listen 8080; \n\
    server_name _; \n\
\n\
    add_header "Access-Control-Allow-Origin" "*" always; \n\
    add_header "Access-Control-Allow-Methods" "GET, OPTIONS, POST" always; \n\
    add_header "Access-Control-Allow-Headers" "*" always; \n\
\n\
    # Раздача интерфейса Лампы \n\
    location / { \n\
        root /app/wroot; \n\
        index index.html; \n\
        try_files $uri $uri/ =404; \n\
    } \n\
\n\
    # Перенаправление плагина, поиска онлайна и торрентов на Python-скрипт \n\
    location ~* ^/(online\.js|search|parser) { \n\
        proxy_pass http://127.0.0.1:9118; \n\
        proxy_set_header Host $host; \n\
        proxy_set_header X-Real-IP $remote_addr; \n\
    } \n\
}' > /etc/nginx/sites-available/default

# Пишем код твоего личного Python-движка (Парсинг ОНЛАЙНА + ТОРРЕНТОВ с твоего сайта)
RUN cat << 'EOF' > main.py
import os
import urllib.parse
import requests
from flask import Flask, request, jsonify, make_response
from bs4 import BeautifulSoup

app = Flask(__name__)
TARGET = os.getenv("TARGET_SITE", "")

@app.route("/online.js")
def plugin():
    h = request.host
    js = f"""(function () {{
        'use strict';
        var current_host = window.location.protocol + "//" + "{h}";

        // 1. ВШИВАЕМ ПАРСЕР ОНЛАЙН-ВИДЕО
        Lampa.Plugins.add("trout_custom", function () {{
            if (!Lampa.Extensions.add) return;
            Lampa.Extensions.add("online", function (object) {{
                return {{
                    search: function (movie_data) {{
                        var title = movie_data.movie.title || movie_data.movie.name || '';
                        return current_host + "/search?query=" + encodeURIComponent(title);
                    }}
                }};
            }});
        }});

        // 2. ВШИВАЕМ ПАРСЕР ТОРРЕНТОВ С ТВОЕГО САЙТА В МЕНЮ "ПАРСЕР"
        localStorage.setItem("parser_use", "true");
        localStorage.setItem("parser_twyt", "true");
        localStorage.setItem("parser_url", current_host + "/parser");

        // 3. ПРИВЯЗЫВАЕМ ТВОЙ TORRSERVER (Порт 8090)
        var server_ip = "{h}".split(":");
        localStorage.setItem("torrserver_url", "http://" + server_ip[0] + ":8090");
        localStorage.setItem("torrserver_use", "true");

        // 4. ПОДГРУЖАЕМ ПЛАГИН ЗВУКОВЫХ ДОРОЖЕК И ТОРРЕНТ-ИНТЕРФЕЙСА
        ["http://cub.red", "http://cub.red"].forEach(function (url) {{
            var script = document.createElement("script");
            script.src = url;
            document.head.appendChild(script);
        }});
    }})();"""
    r = make_response(js)
    r.headers["Content-Type"] = "application/javascript"
    r.headers["Access-Control-Allow-Origin"] = "*"
    return r

# БЛОК 1: Парсинг онлайн-плееров (ищет iframe)
@app.route("/search")
def search():
    q = request.args.get("query", "")
    if not q or not TARGET: return jsonify([])
    search_url = f"{TARGET}/search?query={urllib.parse.quote(q)}"
    try:
        res = requests.get(search_url, timeout=10, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"})
        if res.status_code == 200:
            soup = BeautifulSoup(res.text, "html.parser")
            links = []
            for iframe in soup.find_all("iframe", src=True):
                links.append({"title": f"Смотреть онлайн [{q}]", "url": iframe["src"], "quality": "Auto"})
            if not links:
                links.append({"title": f"Открыть плеер: {q}", "url": search_url, "quality": "Auto"})
            resp = jsonify(links); resp.headers["Access-Control-Allow-Origin"] = "*"; return resp
    except: pass
    resp = jsonify([]); resp.headers["Access-Control-Allow-Origin"] = "*"; return resp

# БЛОК 2: Парсинг торрентов с твоего сайта и перевод их в JSON для Лампы
@app.route("/parser", methods=["GET", "POST"])
def parser_torrent():
    q = request.args.get("search", "")
    if not q or not TARGET: return jsonify([])
    search_url = f"{TARGET}/search?query={urllib.parse.quote(q)}"
    try:
        res = requests.get(search_url, timeout=10, headers={"User-Agent": "Mozilla/5.0"})
        if res.status_code == 200:
            soup = BeautifulSoup(res.text, "html.parser")
            torrents_found = []
            
            # Робот ищет на странице любые ссылки, содержащие .torrent или magnet:
            for a in soup.find_all("a", href=True):
                href = a["href"]
                if ".torrent" in href or href.startswith("magnet:"):
                    title_text = a.get_text().strip() or f"Раздача с сайта [{q}]"
                    torrents_found.append({
                        "title": title_text,
                        "magnet": href,
                        "torrent": href if ".torrent" in href else "",
                        "size": "Неизвестно",
                        "seeders": 10,
                        "leechers": 5,
                        "source": "MySite"
                    })
            
            # Если на странице фильма нет торрент-файлов, отдаем пустой список, чтобы Лампа не падала
            resp = jsonify(torrents_found)
            resp.headers["Access-Control-Allow-Origin"] = "*"
            return resp
    except: pass
    resp = jsonify([]); resp.headers["Access-Control-Allow-Origin"] = "*"; return resp

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=9118)
EOF

RUN mkdir -p /run/nginx && chmod -R 777 /app /var/lib/nginx /var/log/nginx /run/nginx

# Стартер через Tini
RUN printf 'import subprocess\n\
import os\n\
subprocess.Popen(["nginx"])\n\
os.execv("/usr/bin/gunicorn", ["gunicorn", "--bind", "127.0.0.1:9118", "main:app"])\n\
' > /app/entrypoint.py

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["python3", "/app/entrypoint.py"]
