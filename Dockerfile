# 1. Используем официальный стабильный образ Python
FROM python:3.10-slim

# 2. Указываем рабочую папку в контейнере
WORKDIR /app

# 3. Ставим необходимые библиотеки для парсинга и работы сервера
RUN pip install --no-cache-dir flask beautifulsoup4 requests gunicorn

# 4. Железобетонная запись main.py символ в символ без искажения кавычек
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
    return "OK", 200

@app.route("/online.js")
def plugin():
    h = request.host
    
    # Скрипт со встроенной авто-настройкой ВСЕХ меню Лампы (и плагины, и парсер торрентов)
    js = f"""(function () {{
        'use strict';

        var current_host = window.location.protocol + "//" + "{h}";
        var server_ip = "{h}".split(":")[0];

        // 1. АВТО-РЕГИСТРАЦИЯ ТВОЕГО ЛИЧНОГО ПАРСЕРА ДЛЯ ОНЛАЙН-ВИДЕО
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

        // 2. АВТО-ПРОПИСЫВАНИЕ ТВОЕЙ ССЫЛКИ В ПОЛЕ "ПАРСЕР" ДЛЯ ТОРРЕНТОВ
        localStorage.setItem("parser_use", "true");
        localStorage.setItem("parser_twyt", "true");
        localStorage.setItem("parser_url", current_host + "/parser");

        // 3. АВТО-НАСТРОЙКА ДВИЖКА TORRSERVER (Порт 8090)
        localStorage.setItem("torrserver_url", "http://" + server_ip + ":8090");
        localStorage.setItem("torrserver_use", "true");

        // 4. АВТОМАТИЧЕСКАЯ УСТАНОВКА ВСЕХ НЕОБХОДИМЫХ ДОП. ПЛАГИНОВ CUB
        var plugins_to_load = [
            "http://cub.red",
            "http://cub.red",
            "http://cub.red"
        ];
        
        plugins_to_load.forEach(function (url) {{
            var script = document.createElement("script");
            script.src = url;
            document.head.appendChild(script);
        }});
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
        res = requests.get(f"{TARGET}/search?query={urllib.parse.quote(q)}", timeout=10, headers={"User-Agent": "Mozilla/5.0"})
        if res.status_code == 200:
            soup = BeautifulSoup(res.text, "html.parser")
            links = []
            for iframe in soup.find_all("iframe", src=True):
                links.append({"title": f"Смотреть [{q}]", "url": iframe["src"], "quality": "Auto"})
            if not links: 
                links.append({"title": f"Открыть плеер: {q}", "url": f"{TARGET}/search?query={urllib.parse.quote(q)}", "quality": "Auto"})
            
            resp = jsonify(links)
            resp.headers["Access-Control-Allow-Origin"] = "*"
            return resp
    except: pass
    
    empty_resp = jsonify([])
    empty_resp.headers["Access-Control-Allow-Origin"] = "*"
    return empty_resp

# Эндпоинт для раздач (чтобы Лампа искала торренты через твой докер)
@app.route("/parser", methods=["GET", "POST"])
def parser_proxy():
    q = request.args.get("search", "")
    # Наш докер перенаправляет запрос на встроенный поисковик раздач JacRed
    jacred_url = f"http://jacred.xyz{urllib.parse.quote(q)}"
    try:
        res = requests.get(jacred_url, timeout=10)
        resp = make_response(res.text, res.status_code)
        resp.headers["Content-Type"] = "application/json"
        resp.headers["Access-Control-Allow-Origin"] = "*"
        return resp
    except:
        resp = jsonify([])
        resp.headers["Access-Control-Allow-Origin"] = "*"
        return resp

if __name__ == "__main__": 
    app.run(host="0.0.0.0", port=9118)
EOF

EXPOSE 9118
CMD ["gunicorn", "--bind", "0.0.0.0:9118", "main:app"]
