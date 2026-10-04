# syntax=docker/dockerfile:1
FROM python:3.11-slim

# Устанавливаем Flask и Requests прямо при сборке контейнера
RUN pip install --no-cache-dir flask requests

COPY <<EOF /app.py
from flask import Flask, request, jsonify, render_template_string
import requests
import re
import os
import hashlib

app = Flask(__name__)

# Считываем секретный сайт из переменных Koyeb
BASE_URL = os.environ.get("SITE_URL")

# ЧАСТЬ 1: ГЛАВНАЯ СТРАНИЦА (САМА ЗАГРУЖАЕТ ЛАМПУ И ВБИВАЕТ ПАРСЕР АВТОМАТОМ)
def web_lampa():
    # Генерируем HTML-код, который разворачивает стабильное зеркало Lampa на весь экран
    # и МАГИЧЕСКИ прописывает наш собственный докер в память Лампы (localStorage)
    html_code = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Lampa Personal Cinema</title>
        <style>
            html, body, iframe { margin: 0; padding: 0; width: 100%; height: 100%; border: none; overflow: hidden; background: #141414; }
        </style>
        <script>
            // АВТО-НАСТРОЙКА: Лампа сама пропишет наш парсер «из коробки»
            window.localStorage.setItem('parser_use', 'true');
            window.localStorage.setItem('parser_website', window.location.origin + '/kp?id={id}');
            
            // АВТО-ВКЛЮЧЕНИЕ ТОРРЕНТ-ВКЛАДКИ: Чтобы кнопки раздач железно появились
            var plugins = window.localStorage.getItem('plugins') || '[]';
            if (!plugins.includes('etor')) {
                var parsed = JSON.parse(plugins);
                parsed.push({url: 'http://cub.red', status: 1});
                window.localStorage.setItem('plugins', JSON.stringify(parsed));
            }
        </script>
    </head>
    <body>
        <!-- Используем чистое стабильное веб-зеркало Лампы -->
        <iframe src="https://lampa.stream" allowfullscreen></iframe>
    </body>
    </html>
    """
    return render_template_string(html_code)

# ЧАСТЬ 2: СКРЫТЫЙ БРОНЕБОЙНЫЙ АВТОКОНВЕРТЕР ТОРРЕНТОВ
def convert_torrent_to_magnet(torrent_url, headers):
    try:
        res = requests.get(torrent_url, headers=headers, timeout=5)
        if res.status_code == 200 and len(res.content) > 0:
            metadata_start = res.content.find(b'4:infod')
            if metadata_start != -1:
                info_block = res.content[metadata_start + 5 : -1]
                sha1_hash = hashlib.sha1(info_block).hexdigest()
                return f"magnet:?xt=urn:btih:{sha1_hash}"
    except:
        pass
    return None

def get_streams():
    if not BASE_URL:
        return jsonify({"error": "SITE_URL не настроен в Koyeb"}), 500

    kp_id = request.args.get("id")
    if not kp_id:
        return jsonify({"error": "Missing id"}), 400

    try:
        headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
        response = requests.get(f"{BASE_URL.rstrip('/')}/film/{kp_id}/", headers=headers, allow_redirects=True, timeout=10)
        html_content = response.text
        playlist = []
        
        all_links = re.findall(r'href=[\x22\x27]([^\x22\x27]+)[\x22\x27]', html_content)
        
        torrent_idx = 1
        for link in set(all_links):
            if 'magnet:' in link:
                playlist.append({"title": f"💾 Торрент (Magnet) {torrent_idx}", "torrent": link})
                torrent_idx += 1
            elif '.torrent' in link:
                full_url = link if link.startswith('http') else f"{BASE_URL.rstrip('/')}{link}"
                magnet_from_file = convert_torrent_to_magnet(full_url, headers)
                
                if magnet_from_file:
                    playlist.append({"title": f"💾 Торрент (Авто-Конверт) {torrent_idx}", "torrent": magnet_from_file})
                else:
                    playlist.append({"title": f"💾 Резервный торрент-файл {torrent_idx}", "torrent": full_url})
                torrent_idx += 1

        if not playlist:
            return jsonify({"error": "Источники не найдены"}), 404
        
        res = jsonify({"channels": [{"title": "Мой Встроенный Источник", "playlist": playlist}]})
        res.headers.add("Access-Control-Allow-Origin", "*")
        return res
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ЧЕТКАЯ МАРШРУТИЗАЦИЯ СТРАНИЦ
app.add_url_rule('/', view_func=web_lampa)
app.add_url_rule('/kp', view_func=get_streams)

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
EOF

EXPOSE 8080
CMD python /app.py
