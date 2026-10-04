# 1. Берем легкий официальный образ Python
FROM python:3.11-slim

# 2. Устанавливаем библиотеки Flask и Requests прямо при сборке
RUN pip install --no-cache-dir flask requests

# 3. Записываем код нашего API-сервера внутрь контейнера
RUN echo 'from flask import Flask, request, jsonify \n\
import requests \n\
import re \n\
import os \n\
\n\
app = Flask(__name__) \n\
\n\
# Считываем секретные переменные, которые вы укажете только в Koyeb \n\
BASE_URL = os.environ.get("SITE_URL") \n\
SERVER_TOKEN = os.environ.get("MY_SECRET_TOKEN", "default_secure_token") \n\
\n\
@app.route("/") \n\
def home(): \n\
    # Заглушка для пинга (cron-job.org), чтобы сервер не засыпал \n\
    return "Сервер Lampa-прослойки активен и работает 24/7!", 200 \n\
\n\
@app.route("/kp") \n\
def get_streams(): \n\
    # БЛОК БЕЗОПАСНОСТИ: Проверяем токен от Лампы \n\
    user_token = request.args.get("token") \n\
    if not user_token or user_token != SERVER_TOKEN: \n\
        return jsonify({"error": "Forbidden: Неверный токен доступа"}), 403 \n\
\n\
    if not BASE_URL: \n\
        return jsonify({"error": "Ошибка: Переменная SITE_URL не настроена на хостинге"}), 500 \n\
\n\
    # Получаем ID фильма от Лампы (/kp?id=301&token=ваш_пароль) \n\
    kp_id = request.args.get("id") \n\
    if not kp_id: \n\
        return jsonify({"error": "Missing id parameter"}), 400 \n\
\n\
    try: \n\
        headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"} \n\
        \n\
        # Запрашиваем страницу. allow_redirects=True сам летит по новым зеркалам сайта \n\
        response = requests.get(f"{BASE_URL.rstrip(\"/\")}/film/{kp_id}/", headers=headers, allow_redirects=True, timeout=10) \n\
        html_content = response.text \n\
        playlist = [] \n\
        \n\
        # Универсальный поиск онлайн-видео (.mp4 или .m3u8 потоков) \n\
        video_urls = re.findall(r"(https?://[^\s\"\']+\.(?:mp4|m3u8))", html_content) \n\
        for idx, url in enumerate(set(video_urls)): \n\
            playlist.append({"title": f"🎬 Онлайн поток {idx+1}", "video": url}) \n\
        \n\
        # Универсальный поиск торрентов (magnet-ссылок) \n\
        magnet_links = re.findall(r"magnet:\?xt=[^\s\"\']+", html_content) \n\
        for idx, magnet in enumerate(set(magnet_links)): \n\
            playlist.append({"title": f"💾 Торрент раздача {idx+1}", "torrent": magnet}) \n\
        \n\
        if not playlist: \n\
            return jsonify({"error": "Источники на странице сайта не найдены"}), 404 \n\
        \n\
        # Отдаем чистый JSON-ответ в стандарте Lampa \n\
        return jsonify({"channels": [{"title": "Мой Личный Источник", "playlist": playlist}]}) \n\
    \n\
    except Exception as e: \n\
        return jsonify({"error": f"Ошибка парсинга: {str(e)}"}), 500 \n\
\n\
if __name__ == "__main__": \n\
    # Динамический порт защищает от конфликтов портов на хостинге \n\
    port = int(os.environ.get("PORT", 8080)) \n\
    app.run(host="0.0.0.0", port=port) \n\
' > /app.py

# 4. Сообщаем докеру рабочий порт
EXPOSE 8080

# 5. Инструкция для вечного запуска процесса
CMD ["python", "/app.py"]
