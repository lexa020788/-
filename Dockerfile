# syntax=docker/dockerfile:1
FROM python:3.11-slim

# Устанавливаем Flask, Requests и библиотеку для чтения торрент-файлов прямо в докер
RUN pip install --no-cache-dir flask requests

COPY <<EOF /app.py
from flask import Flask, request, jsonify
import requests
import re
import os
import hashlib

app = Flask(__name__)

BASE_URL = os.environ.get("SITE_URL")

# Функция-магия: скачивает файл .torrent и на лету превращает его в magnet-ссылку
def convert_torrent_to_magnet(torrent_url, headers):
    try:
        res = requests.get(torrent_url, headers=headers, timeout=5)
        if res.status_code == 200 and len(res.content) > 0:
            # Ищем начало блока информации в торрент-файле
            metadata_start = res.content.find(b'4:infod')
            if metadata_start != -1:
                # Вырезаем блок info и делаем из него SHA1 хэш
                info_block = res.content[metadata_start + 5 : -1]
                sha1_hash = hashlib.sha1(info_block).hexdigest()
                return f"magnet:?xt=urn:btih:{sha1_hash}"
    except:
        pass
    return None

@app.route('/')
def home():
    return "Сервер Lampa-прослойки активен и работает 24/7!", 200

@app.route('/kp')
def get_streams():
    if not BASE_URL:
        return jsonify({"error": "SITE_URL не настроен"}), 500

    kp_id = request.args.get("id")
    if not kp_id:
        return jsonify({"error": "Missing id"}), 400

    try:
        headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
        response = requests.get(f"{BASE_URL.rstrip('/')}/film/{kp_id}/", headers=headers, allow_redirects=True, timeout=10)
        html_content = response.text
        playlist = []
        
        # Находим вообще все ссылки на странице
        all_links = re.findall(r'href=[\x22\x27]([^\x22\x27]+)[\x22\x27]', html_content)
        
        torrent_idx = 1
        for link in set(all_links):
            # Если это чистая magnet-ссылка
            if 'magnet:' in link:
                playlist.append({"title": f"💾 Торрент (Magnet) {torrent_idx}", "torrent": link})
                torrent_idx += 1
            # Если это файл .torrent — запускаем наш встроенный конвертер!
            elif '.torrent' in link:
                full_url = link if link.startswith('http') else f"{BASE_URL.rstrip('/')}{link}"
                # Конвертируем файл в магнет прямо в памяти Koyeb
                magnet_from_file = convert_torrent_to_magnet(full_url, headers)
                
                if magnet_from_file:
                    playlist.append({"title": f"💾 Торрент (Авто-Конверт) {torrent_idx}", "torrent": magnet_from_file})
                else:
                    # Если конвертер не справился, отдаем прямую ссылку как резерв
                    playlist.append({"title": f"💾 Резервный торрент-файл {torrent_idx}", "torrent": full_url})
                torrent_idx += 1

        if not playlist:
            return jsonify({"error": "Источники не найдены"}), 404
        
        res = jsonify({"channels": [{"title": "Мой Источник", "playlist": playlist}]})
        res.headers.add("Access-Control-Allow-Origin", "*")
        return res
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
EOF

EXPOSE 8080
CMD python /app.py
