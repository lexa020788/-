FROM mcr.microsoft.com/dotnet/aspnet:9.0

WORKDIR /app

# 1. Установка системных зависимостей и Node.js для Playwright
RUN apt-get update && apt-get install -y \
    curl unzip ca-certificates wget nodejs npm \
    libgbm1 libgtk-3-0 libnspr4 libnss3 libasound2 && \
    rm -rf /var/lib/apt/lists/*

# 2. Скачивание Lampac (ПРЯМАЯ ССЫЛКА НА ZIP)
# Если эта ссылка не сработает, используем альтернативную
RUN wget -q https://github.com -O /tmp/publish.zip && \
    unzip -o /tmp/publish.zip -d /app && \
    rm /tmp/publish.zip

# 3. Установка Playwright браузеров (для Hobby плана)
RUN npx playwright install chromium --with-deps

# 4. Конфиг Lampac (относительный путь для плагина /plugins/koyeb.js)
RUN echo '{"listen":{"port":8080},"koyeb":true,"parser":{"jac":true,"eth":true,"proxy":true,"playwright":true},"online":{"proxy":true},"proxy":{"all":true},"plugins":[{"name":"Koyeb Bundle","url":"/plugins/koyeb.js"}]}' > /app/init.conf

# 5. Плагин Lampa (авто-настройка под твой текущий домен)
RUN mkdir -p /app/wwwroot/plugins && \
    echo 'Lampa.plugin.add("koyeb_bundle", function(){ \
        var host = window.location.protocol + "//" + window.location.host; \
        Lampa.Storage.set("parser_use", "true"); \
        Lampa.Storage.set("parser_host", host); \
        Lampa.Storage.set("proxy_all", "true"); \
        console.log("Koyeb Plugin Active: " + host); \
    });' > /app/wwwroot/plugins/koyeb.js

RUN chmod -R 777 /app

HEALTHCHECK --interval=60s --timeout=15s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Запуск напрямую
ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080"]
