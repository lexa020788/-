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

# Считываем скрытую переменную сайта из настроек Koyeb
BASE_URL = os.environ.get("SITE_URL")

@app.route('/')
def home():
    # Заглушка для пинга, чтобы сервер не засыпал
    return "Сервер Lampa-прослойки активен и работает 24/7!", 200

@app.route('/kp')
def get_streams():
    if not BASE_URL:
        return jsonify({"error": "Ошибка: Переменная SITE_URL не настроена на хостинге"}), 500

    # Получаем ID фильма от Лампы (/kp?id={id})
    kp_id = request.args.get("id")
    if not kp_id:
        return jsonify({"error": "Missing id parameter"}), 400

    try:
        # Имитируем чистый браузер Windows Chrome, чтобы сайт нас не забанил
        headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"}
        
        # Запрашиваем страницу. allow_redirects=True сам летит по новым зеркалам вашего сайта
        response = requests.get(f"{BASE_URL.rstrip('/')}/film/{kp_id}/", headers=headers, allow_redirects=True, timeout=10)
        html_content = response.text
        playlist = []
        
        # 1. Сверх-всеядный поиск торрентов (Ищет magnet-ссылки и прямые файлы .torrent)
        all_links = re.findall(r'href=[\x22\x27]([^\x22\x27]+)[\x22\x27]', html_content)
        
        torrent_idx = 1
        for link in set(all_links):
            # Если это прямая магнет-ссылка
            if 'magnet:' in link:
                playlist.append({"title": f"💾 Торрент (Magnet) {torrent_idx}", "torrent": link})
                torrent_idx += 1
            # Если сайт отдает торренты файлами .torrent
            elif '.torrent' in link:
                # Если ссылка относительная (например, /download/file.torrent), делаем ее полной
                full_torrent_url = link if link.startswith('http') else f"{BASE_URL.rstrip('/')}{link}"
                playlist.append({"title": f"💾 Скачать торрент-файл {torrent_idx}", "torrent": full_torrent_url})
                torrent_idx += 1

        if not playlist:
            return jsonify({"error": "Источники на странице сайта не найдены"}), 404
        
        # Отдаем чистый JSON-ответ в стандарте Lampa и открываем доступ CORS
        res = jsonify({"channels": [{"title": "Мой Источник", "playlist": playlist}]})
        res.headers.add("Access-Control-Allow-Origin", "*")
        return res
    
    except Exception as e:
        return jsonify({"error": f"Ошибка парсинга: {str(e)}"}), 500

if __name__ == "__main__":
    # Динамический порт защищает от конфликтов портов на хостинге
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
EOF

# 4. Открываем порт для Koyeb
EXPOSE 8080

# 5. Инструкция вечного запуска процесса
CMD python /app.py
