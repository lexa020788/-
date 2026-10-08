# --- Stage 1: Скачивание чистого интерфейса Lampa ---
FROM debian:13-slim AS builder
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl xz-utils unzip git && rm -rf /var/lib/apt/lists/*
WORKDIR /build
RUN curl -fSL -o lampa.zip https://github.com && \
    unzip lampa.zip && mv lampa-main web && rm -rf lampa.zip

# --- Stage 2: Рабочая среда (Только Python Сервер на 8080) ---
FROM debian:13-slim AS runner
WORKDIR /app

# Жестко декларируем порт 8080 для хостинга Koyeb
EXPOSE 8080

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl python3 python3-pip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir --break-system-packages flask beautifulsoup4 requests gunicorn

# Копируем веб-интерфейс Лампы в рабочую папку
COPY --from=builder /build/web /app/wroot

# Пишем код твоего личного Python-движка, который и Лампу раздает, и сайт парсит
RUN cat << 'EOF' > main.py
import os
import urllib.parse
import requests
from flask import Flask, request, jsonify, make_response, send_from_directory
from bs4 import BeautifulSoup

# Указываем Flask раздавать интерфейс Лампы из папки wroot
app = Flask(__name__, static_folder='wroot', static_url_path='')
TARGET = os.getenv("TARGET_SITE", "")

# ГЛАВНАЯ СТРАНИЦА: При переходе на сайт открывается твоя визуализация Лампы
@app.route("/")
def index():
    with open("wroot/index.html", "r", encoding="utf-8") as f:
        html = f.read()
    # На лету вживляем автозапуск твоего плагина прямо перед закрывающим тегом head
    auto_inject = '<script src="/online.js"></script></head>'
    return html.replace("</head>", auto_inject)

@app.route("/online.js")
def plugin():
    h = request.host
    js = f"""(function () {{
        'use strict';
        var current_host = window.location.protocol + "//" + "{h}";

        // 1. ВШИВАЕМ ПАРСЕР ОНЛАЙН-ВИДЕО С ТВОЕГО САЙТА
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
        localStorage.setItem("torrserver_url", "http://" + server_ip + ":8090");
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

# БЛОК 1: Парсинг онлайн-плееров с твоего сайта
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

# БЛОК 2: Парсинг торрентов с твоего сайта для Лампы
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
            for a in soup.find_all("a", href=True):
                href = a["href"]
                if ".torrent" in href or href.startswith("magnet:"):
                    title_text = a.get_text().strip() or f"Раздача [{q}]"
                    torrents_found.append({
                        "title": title_text,
                        "magnet": href,
                        "torrent": href if ".torrent" in href else "",
                        "size": "Unknown",
                        "seeders": 15,
                        "leechers": 5,
                        "source": "MySite"
                    })
            resp = jsonify(torrents_found); resp.headers["Access-Control-Allow-Origin"] = "*"; return resp
    except: pass
    resp = jsonify([]); resp.headers["Access-Control-Allow-Origin"] = "*"; return resp

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
EOF

# Запускаем Gunicorn строго на порту 8080, чтобы состыковаться с Koyeb!
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "main:app"]
