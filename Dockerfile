# syntax=docker/dockerfile:1
# 1. Берем легкий официальный образ Python
FROM python:3.11-slim

# 2. Устанавливаем нужные библиотеки прямо при сборке
RUN pip install --no-cache-dir flask requests

# 3. Создаем чистый файл app.py внутри контейнера
COPY <<EOF /app.py
from flask import Flask, request, jsonify
import requests
import re
import os

app = Flask(__name__)

# Считываем скрытые переменные из Koyeb
BASE_URL = os.environ.get("SITE_URL")
SERVER_TOKEN = os.environ.get("MY_SECRET_TOKEN", "default_secure_token")

@app.route('/')
def home():
    # Заглушка для пинга, чтобы сервер не засыпал
    return "Сервер Lampa-прослойки активен и работает 24/7!", 200

@app.route('/kp')
def get_streams():
    # БЛОК БЕЗОПАСНОСТИ: Проверяем токен от Лампы
    user_token = request.args.get("token")
    if not user_token or user_token != SERVER_TOKEN:
        return jsonify({"error": "Forbidden: Неверный токен доступа"}), 403

    if not BASE_URL:
        return jsonify({"error": "Ошибка: Переменная SITE_URL не настроена на хостинге"}), 500

    # Получаем ID фильма от Лампы (/kp?id=301&token=ваш_пароль)
    kp_id = request.args.get("id")
    if not kp_id:
        return jsonify({"error": "Missing id parameter"}), 400

    try:
        headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
        
        # Запрашиваем страницу. allow_redirects=True сам летит по новым зеркалам сайта
        response = requests.get(f"{BASE_URL.rstrip('/')}/film/{kp_id}/", headers=headers, allow_redirects=True, timeout=10)
        html_content = response.text
        playlist = []
        
        # Умный поиск онлайн-видео (.mp4 или .m3u8 потоков) без использования кавычек в регулярке
        video_urls = re.findall(r'https?://[^\s\x22\x27]+\.(?:mp4|m3u8)', html_content)
        for idx, url in enumerate(set(video_urls)): # set() отсекает дубликаты
            playlist.append({"title": f"🎬 Онлайн поток {idx+1}", "video": url})
        
        # Умный поиск торрентов (magnet-ссылок) без использования кавычек в регулярке
        magnet_links = re.findall(r'magnet:\?xt=[^\s\x22\x27]+', html_content)
        for idx, magnet in enumerate(set(magnet_links)):
            playlist.append({"title": f"💾 Торрент раздача {idx+1}", "torrent": magnet})
        
        if not playlist:
            return jsonify({"error": "Источники на странице сайта не найдены"}), 404
        
        return jsonify({"channels": [{"title": "Мой Личный Источник", "playlist": playlist}]})
    
    except Exception as e:
        return jsonify({"error": f"Ошибка парсинга: {str(e)}"}), 500

if __name__ == "__main__":
    # Динамический порт защищает от конфликтов портов на хостинге
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
EOF

# 4. Открываем порт для Koyeb
EXPOSE 8080

# 5. Запуск процесса
CMD python /app.py
