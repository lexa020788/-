# 1. Берем легкий официальный образ Python
FROM python:3.11-slim

# 2. Устанавливаем нужные библиотеки прямо при сборке
RUN pip install --no-cache-dir flask requests

# 3. Открываем порт для Koyeb
EXPOSE 8080

# 4. ЗАПУСК И ЛОГИКА В ОДНУ СТРОКУ (Вместо CMD используем надежный ENTRYPOINT)
# Скрипт принимает SITE_URL и MY_SECRET_TOKEN из переменных Koyeb
ENTRYPOINT ["python", "-c", "from flask import Flask, request, jsonify; import requests, re, os; app = Flask(__name__); BASE_URL = os.environ.get('SITE_URL'); SERVER_TOKEN = os.environ.get('MY_SECRET_TOKEN', 'default_secure_token'); \
@app.route('/')\ndef home(): return 'Сервер Lampa-прослойки работает 24/7!', 200\n \
@app.route('/kp')\ndef get_streams():\n    user_token = request.args.get('token')\n    if not user_token or user_token != SERVER_TOKEN: return jsonify({'error': 'Forbidden'}), 403\n    if not BASE_URL: return jsonify({'error': 'SITE_URL missing'}), 500\n    kp_id = request.args.get('id')\n    if not kp_id: return jsonify({'error': 'Missing id'}), 400\n    try:\n        headers = {'User-Agent': 'Mozilla/5.0'}\n        res = requests.get(f'{BASE_URL.rstrip(\"/\")}/film/{kp_id}/', headers=headers, allow_redirects=True, timeout=10)\n        playlist = []\n        for idx, url in enumerate(set(re.findall(r'(https?://[^\s\"\']+\.(?:mp4|m3u8))', res.text))): playlist.append({'title': f'🎬 Онлайн поток {idx+1}', 'video': url})\n        for idx, mag in enumerate(set(re.findall(r'magnet:\?xt=[^\s\"\']+', res.text))): playlist.append({'title': f'💾 Торрент {idx+1}', 'torrent': mag})\n        if not playlist: return jsonify({'error': 'No sources'}), 404\n        return jsonify({'channels': [{'title': 'Мой Источник', 'playlist': playlist}]})\n    except Exception as e: return jsonify({'error': str(e)}), 500\n \
if __name__ == '__main__': app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))"]
