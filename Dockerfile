# syntax=docker/dockerfile:1
FROM python:3.11-slim

RUN pip install --no-cache-dir flask requests

COPY <<EOF /app.py
from flask import Flask, request, jsonify, render_template_string
import requests
import re
import os
import base64

app = Flask(__name__)

BASE_URL = os.environ.get("SITE_URL")

# ЧАСТЬ 1: ГЛАВНАЯ СТРАНИЦА (Интегрируем чистую Лампу прямо в Докер)
def web_lampa():
    try:
        # Скачиваем официальную чистую веб-версию Lampa, чтобы она была внутри нашего сервера
        lampa_html = requests.get("https://lampa.stream", timeout=5).text
    except:
        # Резервный адрес на случай сбоя основного
        lampa_html = requests.get("https://bylampa.online", timeout=5).text

    # Вживляем автонастройку нашего парсера прямо в код страницы перед её отправкой на экран
    setup_script = """
    <script>
        window.localStorage.setItem('parser_use', 'true');
        window.localStorage.setItem('parser_website', window.location.origin + '/kp?id={id}');
        // Включаем встроенный плагин для отображения торрентов, как в оригинальном Лампаке
        var plugins = window.localStorage.getItem('plugins') || '[]';
        if (!plugins.includes('etor')) {
            var parsed = JSON.parse(plugins);
            parsed.push({url: 'http://cub.red', status: 1});
            window.localStorage.setItem('plugins', JSON.stringify(parsed));
        }
    </script>
    """
    
    # Вставляем нашу магию автонастройки прямо в тег <head> оригинальной Лампы
    ready_html = lampa_html.replace("<head>", f"<head>{setup_script}")
    return ready_html

# ЧАСТЬ 2: ВСТРОЕННЫЙ ПАРСЕР ТОРРЕНТОВ И ОНЛАЙНА
def get_streams():
    if not BASE_URL:
        return jsonify({"error": "SITE_URL не настроен в Koyeb"}), 500

    kp_id = request.args.get("id")
    if not kp_id:
        return jsonify({"error": "Missing id parameter"}), 400

    try:
        headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
        response = requests.get(f"{BASE_URL.rstrip('/')}/film/{kp_id}/", headers=headers, allow_redirects=True, timeout=10)
        html_content = response.text
        playlist = []
        
        # 1. Поиск онлайн-видео
        video_urls = re.findall(r'https?://[^\s\x22\x27]+\.(?:mp4|m3u8)', html_content)
        for idx, url in enumerate(set(video_urls)):
            playlist.append({"title": f"🎬 Онлайн поток {idx+1}", "video": url})
        
        # 2. Всеядный поиск торрентов
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
        
        res = jsonify({"channels": [{"title": "Мой Встроенный Источник", "playlist": playlist}]})
        res.headers.add("Access-Control-Allow-Origin", "*")
        return res
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

app.add_url_rule('/', view_func=web_lampa)
app.add_url_rule('/kp', view_func=get_streams)

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
EOF

EXPOSE 8080
CMD python /app.py
