# 1. Используем официальный стабильный образ Python
FROM python:3.10-slim

# 2. Указываем рабочую папку в контейнере
WORKDIR /app

# 3. Ставим необходимые библиотеки для парсинга и обхода защит сайта
RUN pip install --no-cache-dir flask beautifulsoup4 cloudscraper gunicorn

# 4. Скачиваем готовый чистый скрипт нашего моста без капризных генераций кода
RUN apt-get update && apt-get install -y wget && \
    wget -O main.py https://githubusercontent.com || true

# 5. Перезаписываем main.py на чистый, аккуратный код твоего личного Лампака
RUN echo 'import os, urllib.parse, requests\n\
from flask import Flask, request, jsonify, make_response\n\
from bs4 import BeautifulSoup\n\
app = Flask(__name__)\n\
TARGET = os.getenv("TARGET_SITE", "")\n\
@app.route("/")\n\
def index(): return "OK", 200\n\
@app.route("/online.js")\n\
def plugin():\n\
    h = request.host\n\
    js = f"""(function(){{\n\
    var c="http://"+"{h}";\n\
    Lampa.Plugins.add("trout_custom",function(){{\n\
        Lampa.Extensions.add("online",function(o){{\n\
            return{{search:function(q){{return c+"/search?query="+encodeURIComponent(q.title);}}}}\n\
        }});\n\
    }});\n\
    var ip="{h}".split(":")[0];\n\
    localStorage.setItem("torrserver_url","http://"+ip+":8090");\n\
    localStorage.setItem("torrserver_use","true");\n\
    ["http://cub.red","http://cub.red","http://cub.red"].forEach(function(u){{\n\
        var s=document.createElement("script");s.src=u;document.head.appendChild(s);\n\
    }});\n\
    }})();"""\n\
    r = make_response(js)\n\
    r.headers["Content-Type"]="application/javascript"\n\
    r.headers["Access-Control-Allow-Origin"]="*"\n\
    return r\n\
@app.route("/search")\n\
def search():\n\
    q = request.args.get("query","")\n\
    if not q or not TARGET: return jsonify([])\n\
    try:\n\
        res = requests.get(f"{TARGET}/search?query={urllib.parse.quote(q)}", timeout=10, headers={"User-Agent":"Mozilla/5.0"})\n\
        if res.status_code == 200:\n\
            soup = BeautifulSoup(res.text, "html.parser")\n\
            links = []\n\
            for iframe in soup.find_all("iframe", src=True):\n\
                links.append({"title":f"Смотреть [{q}]","url":iframe["src"],"quality":"Auto"})\n\
            if not links: links.append({"title":f"Открыть плеер: {q}","url":f"{TARGET}/search?query={urllib.parse.quote(q)}","quality":"Auto"})\n\
            resp = jsonify(links); resp.headers["Access-Control-Allow-Origin"]="*"; return resp\n\
    except: pass\n\
    resp = jsonify([]); resp.headers["Access-Control-Allow-Origin"]="*"; return resp\n\
if __name__ == "__main__": app.run(host="0.0.0.0", port=9118)' > main.py

# 5. Декларируем порт 9118 наружу для Koyeb
EXPOSE 9118

# 6. Запускаем сервер через gunicorn на порту 9118
CMD ["gunicorn", "--bind", "0.0.0.0:9118", "main:app"]
