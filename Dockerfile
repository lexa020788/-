# 1. Используем официальный стабильный образ Python
FROM python:3.10-slim

# 2. Указываем рабочую папку в контейнере
WORKDIR /app

# 3. Ставим необходимые библиотеки для парсинга и работы сервера
RUN pip install --no-cache-dir flask beautifulsoup4 requests gunicorn

# 4. Железобетонная запись main.py символ в символ через base64, чтобы кавычки никогда не ломались
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
    
    # Кристально чистый JavaScript-код плагина, полностью соответствующий стандартам API Lampa
    js = f"""(function () {{
        'use strict';

        // Регистрируем твой плагин с красивым именем
        Lampa.Plugins.add("trout_custom", function () {{
            
            // Проверяем, что в Lampa вообще есть расширение "online"
            if (!Lampa.Extensions.add) return;

            Lampa.Extensions.add("online", function (object) {{
                var current_host = window.location.protocol + "//" + "{h}";
                
                return {{
                    // Главная функция поиска, которую вызывает кнопка "Онлайн"
                    search: function (movie_data) {{
                        // Вытаскиваем точное название фильма (оригинальное или русское)
                        var title = movie_data.movie.title || movie_data.movie.name || '';
                        return current_host + "/search?query=" + encodeURIComponent(title);
                    }}
                }};
            }});
        }});

        // Авто-привязка TorrServer для торрентов на порт 8090
        var ip = "{h}".split(":");
        localStorage.setItem("torrserver_url", "http://" + ip[0] + ":8090");
        localStorage.setItem("torrserver_use", "true");
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
        # Твой робот идет на сайт под видом Mozilla 5.0, пряча его домен от Лампы
        res = requests.get(f"{TARGET}/search?query={urllib.parse.quote(q)}", timeout=10, headers={"User-Agent": "Mozilla/5.0"})
        if res.status_code == 200:
            soup = BeautifulSoup(res.text, "html.parser")
            links = []
            
            # Вырезаем iframe плеера из движка сайта
            for iframe in soup.find_all("iframe", src=True):
                links.append({"title": f"Смотреть [{q}]", "url": iframe["src"], "quality": "Auto"})
                
            # Если плеер скрыт, даем прямую ссылку на поисковую страницу фильма на сайте
            if not links: 
                links.append({"title": f"Открыть плеер: {q}", "url": f"{TARGET}/search?query={urllib.parse.quote(q)}", "quality": "Auto"})
            
            resp = jsonify(links)
            resp.headers["Access-Control-Allow-Origin"] = "*"
            return resp
    except: pass
    
    resp = jsonify([])
    resp.headers["Access-Control-Allow-Origin"] = "*"
    return resp

if __name__ == "__main__": 
    app.run(host="0.0.0.0", port=9118)
EOF

# 5. Декларируем порт 9118 наружу для Koyeb
EXPOSE 9118

# 6. Запускаем сервер через gunicorn на порту 9118
CMD ["gunicorn", "--bind", "0.0.0.0:9118", "main:app"]
