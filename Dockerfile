# syntax=docker/dockerfile:1
FROM python:3.11-slim

RUN pip install --no-cache-dir flask requests

COPY <<EOF /app.py
from flask import Flask, request, jsonify
import requests
import re
import os

app = Flask(__name__)

BASE_URL = os.environ.get("SITE_URL")
SERVER_TOKEN = os.environ.get("MY_SECRET_TOKEN", "default_secure_token")

def home():
    # Заглушка для пинга
    return "Сервер Lampa-прослойки активен и работает 24/7!", 200

def get_streams():
    # БЛОК БЕЗОПАСНОСТИ
    user_token = request.args.get("token")
    if not user_token or user_token != SERVER_TOKEN:
        return jsonify({"error": "Forbidden: Неверный токен доступа"}), 403

    if not BASE_URL:
        return jsonify({"error": "Ошибка: Переменная SITE_URL не настроена на хостинге"}), 500

    kp_id = request.args.get("id")
    if not kp_id:
        return jsonify({"error": "Missing id parameter"}), 400

    try:
        headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
        response = requests.get(f"{BASE_URL.rstrip('/')}/film/{kp_id}/", headers=headers, allow_redirects=True, timeout=10)
        html_content = response.text
        playlist = []
        
        # Умный поиск онлайн-видео (.mp4 или .m3u8 потоков)
        video_urls = re.findall(r'https?://[^\s\x22\x27]+\.(?:mp4|m3u8)', html_content)
        for idx, url in enumerate(set(video_urls)):
            playlist.append({"title": f"🎬 Онлайн поток {idx+1}", "video": url})
        
        # Умный поиск торрентов (magnet-ссылок)
        magnet_links = re.findall(r'magnet:\?xt=[^\s\x22\x27]+', html_content)
        for idx, magnet in enumerate(set(magnet_links)):
            playlist.append({"title": f"💾 Торрент раздача {idx+1}", "torrent": magnet})
        
        if not playlist:
            return jsonify({"error": "Источники на странице сайта не найдены"}), 404
        
        return jsonify({"channels": [{"title": "Мой Личный Источник", "playlist": playlist}]})
    except Exception as e:
        return jsonify({"error": f"Ошибка парсинга: {str(e)}"}), 500

# ЯВНОЕ ПРИВЯЗЫВАНИЕ СТРАНИЦ (Защита от склеивания строк в Docker)
app.add_url_rule('/', view_func=home)
app.add_url_rule('/kp', view_func=get_streams)

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
EOF

EXPOSE 8080
CMD python /app.py
