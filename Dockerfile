# 7. Стабильный запуск с очисткой памяти
CMD pkill -9 chromium; pkill -9 dotnet; \
    Xvfb :99 -ac -screen 0 1024x768x16 & \
    export DISPLAY=:99 && \
    dotnet Core.dll --urls http://0.0.0 & \
    echo "--- Ожидание Lampac... ---" && \
    until curl -s http://127.0.0.1:9118 > /dev/null; do sleep 3; done && \
    echo "--- Прогрев Chromium ---" && \
    curl -s http://127.0.0 > /dev/null && \
    echo "--- [READY] Мост открыт ---" && \
    socat TCP-LISTEN:7860,fork,reuseaddr TCP:127.0.0.1:9118
# 5. ИСПРАВЛЕННАЯ КОНФИГУРАЦИЯ (С лимитом памяти для стабильности на HF)
RUN echo '{"listen":{"port":9118},"server":{"host":"0.0.0.0"},"cache":{"enable":true},"online":{"enable":true,"proxy":true,"internal":true},"online_config":{"videodb":{"enable":true,"proxy":true},"rezka":{"enable":true,"proxy":true}},"SISI":{"enable":true},"LampaWeb":{"init":true,"base_url":"https://hf.space","plugins":["/online.js","/sisi.js","/jac.js"]},"chromium":{"enable":true,"executablePath":"/usr/bin/chromium","args":["--no-sandbox","--disable-setuid-sandbox","--remote-debugging-pipe","--remote-debugging-port=0","--single-process","--no-zygote","--disable-gpu","--disable-dev-shm-usage","--js-flags=\"--max-old-space-size=256\""]}}' > /lampac/init.conf
