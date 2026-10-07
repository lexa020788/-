# 1. Используем официальный стабильный образ Python
FROM python:3.10-slim

# 2. Устанавливаем утилиты для скачивания интерфейса Лампы
RUN apt-get update && apt-get install -y wget unzip && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 3. Скачиваем официальный, чистый веб-интерфейс Lampa прямо в контейнер
RUN wget https://github.com -O lampa.zip && \
    unzip lampa.zip && \
    mv lampa-main/* . && \
    rm -rf lampa.zip lampa-main

# 4. Ставим необходимые библиотеки Python для работы сети и парсера
RUN pip install --no-cache-dir flask beautifulsoup4 requests gunicorn

# 5. Пишем код твоего сервера, который раздаёт Лампу и выполняет автонастройку
RUN cat << 'EOF' > main.py
import os
import urllib.parse
import requests
from flask import Flask, request, jsonify, make_response

# Указываем Flask раздавать скачанный интерфейс Лампы из текущей папки
app = Flask(__name__, static_folder='.', static_url_path='')
TARGET = os.getenv("TARGET_SITE", "")

# ГЛАВНАЯ СТРАНИЦА: При переходе на lamposhka.koyeb.app открывается ТВОЯ ЛАМПА
@app.route("/")
def index():
    # Отдаем оригинальный index.html Лампы
    with open("index.html", "r", encoding="utf-8") as f:
        html = f.read()
    
    # Вживляем автозапуск плагина перед закрывающим тегом head
    auto_inject = '<script src="/online.js"></script></head>'
    return html.replace("</head>", auto_inject)

# НАШ СКРИПТ АВТО-НАСТРОЙКИ (Лампа запустит его сама при старте страницы)
@app.route("/online.js")
def plugin():
    h = request.host
    js = f"""(function () {{
        'use strict';

        var current_host = window.location.protocol + "//" + "{h}";
        var server_ip = "{h}".split(":");

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

        // 2. АВТО-ПРОПИСЫВАНИЕ ТОРРЕНТОВ И ПАРСЕРА В ПАМЯТЬ ЛАМПЫ
        localStorage.setItem("parser_use", "true");
        localStorage.setItem("parser_twyt", "true");
        localStorage.setItem("parser_url", current_host + "/parser");

        // 3. АВТО-НАСТРОЙКА ТВОЕГО TORRSERVER (Порт 8090)
        localStorage.setItem("torrserver_url", "http://" + server_ip + ":8090");
        localStorage.setItem("torrserver_use", "true");

        // 4. АВТО-ЗАГРУЗКА ОСТАЛЬНЫХ СИСТЕМНЫХ ПЛАГИНОВ ДЛЯ ТОРРЕНТОВ И ЗВУКА
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

# ТВОЙ СКРЫТЫЙ ПАРСЕР ОНЛАЙН-ВИДЕО (Ищет на troutcdn.site под видом Mozilla 5.0)
@app.route("/search")
def search():
    q = request.args.get("query", "")
    if not q or not TARGET: return jsonify([])
    try:
        res = requests.get(f"{TARGET}/search?query={urllib.parse.quote(q)}", timeout=10, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"})
        if res.status_code == 200:
            soup = BeautifulSoup(res.text, "html.parser")
            links = []
            for iframe in soup.find_all("iframe", src=True):
                links.append({"title": f"Смотреть онлайн [{q}]", "url": iframe["src"], "quality": "Auto"})
            if not links: 
                links.append({"title": f"Открыть плеер: {q}", "url": f"{TARGET}/search?query={urllib.parse.quote(q)}", "quality": "Auto"})
            
            resp = jsonify(links)
            resp.headers["Access-Control-Allow-Origin"] = "*"
            return resp
    except: pass
    
    empty_resp = jsonify([])
    empty_resp.headers["Access-Control-Allow-Origin"] = "*"
    return empty_resp

# ТВОЙ СКРЫТЫЙ МОСТ ДЛЯ ТОРРЕНТОВ
@app.route("/parser", methods=["GET", "POST"])
def parser_proxy():
    q = request.args.get("search", "")
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

# 5. Декларируем порт 9118 наружу для Koyeb
EXPOSE 9118

# 6. Запускаем твою личную полноценную Lampa на порту 9118
CMD ["gunicorn", "--bind", "0.0.0.0:9118", "main:app"]
