# syntax=docker/dockerfile:1
# 1. Берем легкий официальный образ Python
FROM python:3.11-slim

# 2. Устанавливаем библиотеки Flask и Requests
RUN pip install --no-cache-dir flask requests

# 3. Записываем код сервера, который объединяет Лампу и парсер секретного сайта
COPY <<EOF /app.py
from flask import Flask, request, jsonify, render_template_string
import requests
import re
import os
import base64

app = Flask(__name__)

# Считываем скрытую переменную сайта из настроек Koyeb
BASE_URL = os.environ.get("SITE_URL")

# ЧАСТЬ 1: ГЛАВНАЯ СТРАНИЦА (Раздает интерфейс Лампы)
def web_lampa():
    # Генерируем HTML-код, который разворачивает стабильное зеркало Lampa на весь экран
    # и МАГИЧЕСКИ прописывает наш собственный докер в память Лампы (localStorage)
    html_code = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Lampa Cinema</title>
        <style>
            html, body, iframe { margin: 0; padding: 0; width: 100%; height: 100%; border: none; overflow: hidden; background: #141414; }
        </style>
        <script>
            // Авто-настройка парсера внутри Лампы «из коробки»
            window.localStorage.setItem('parser_use', 'true');
            window.localStorage.setItem('parser_website', window.location.origin + '/kp?id={id}');
        </script>
    </head>
    <body>
        <!-- Используем стабильный и быстрый веб-интерфейс Лампы -->
        <iframe src="https://bylampa.online" allowfullscreen></iframe>
    </body>
    </html>
    """
    return render_template_string(html_code)

# ЧАСТЬ 2: СКРЫТЫЙ ПАРСЕР (Собирает ссылки с вашего сайта)
def get_streams():
    if not BASE_URL:
        return jsonify({"error": "SITE_URL не настроен в Koyeb"}), 500

    kp_id = request.args.get("id")
    if not kp_id:
        return jsonify({"error": "Missing id parameter"}), 400

    try:
        # Маскируемся под чистый браузер Windows Chrome
        headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"}
        
        # Летим на страницу фильма по ID Кинопоиска (allow_redirects сам обходит смену зеркал)
        response = requests.get(f"{BASE_URL.rstrip('/')}/film/{kp_id}/", headers=headers, allow_redirects=True, timeout=10)
        html_content = response.text
        playlist = []
        
        # 1. Поиск онлайн-видео (.mp4 или .m3u8 потоков)
        video_urls = re.findall(r'https?://[^\s\x22\x27]+\.(?:mp4|m3u8)', html_content)
        for idx, url in enumerate(set(video_urls)):
            playlist.append({"title": f"🎬 Онлайн поток {idx+1}", "video": url})
        
        # 2. Всеядный поиск торрент-магнетов (обычные и Base64-зашифрованные)
        magnet_links = re.findall(r'magnet:[^\s\x22\x27]+', html_content)
        
        b64_links = re.findall(r'(?:bWFnbmV0)[^\s\x22\x27]+', html_content)
        for b64_str in b64_links:
            try:
                decoded = base64.b64decode(b64_str).decode('utf-8', errors='ignore')
                if 'magnet:' in decoded:
                    magnet_links.append(re.search(r'magnet:[^\s\x22\x27]+', decoded).group(0))
            except:
                pass

        for idx, magnet in enumerate(set(magnet_links)):
            playlist.append({"title": f"💾 Торрент раздача {idx+1}", "torrent": magnet})
        
        if not playlist:
            return jsonify({"error": "Источники на сайте не найдены"}), 404
        
        # Формируем JSON-ответ и отключаем CORS-блокировку, чтобы встроенная Лампа приняла данные
        res = jsonify({"channels": [{"title": "Мой Встроенный Источник", "playlist": playlist}]})
        res.headers.add("Access-Control-Allow-Origin", "*")
        return res
        
    except Exception as e:
        return jsonify({"error": f"Ошибка парсинга: {str(e)}"}), 500

# Явное распределение страниц (Защита от склеивания строк в Linux)
app.add_url_rule('/', view_func=web_lampa)
app.add_url_rule('/kp', view_func=get_streams)

if __name__ == "__main__":
    # Динамический порт защищает от конфликтов портов в Koyeb
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
EOF

# 4. Открываем порт для Koyeb
EXPOSE 8080

# 5. Инструкция вечного запуска
CMD python /app.py
