FROM mcr.microsoft.com/dotnet/aspnet:9.0

WORKDIR /app

# Добавляем gnupg для работы с ключами и исправляем логику
RUN apt-get update && apt-get install -y \
    curl unzip ca-certificates wget gnupg \
    libgbm1 libgtk-3-0 libnspr4 libnss3 libasound2 \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install nodejs -y \
    # Прямая ссылка на архив
    && wget https://lampa.weritos.online -O /tmp/publish.zip \
    && unzip -o /tmp/publish.zip -d /app \
    && rm /tmp/publish.zip \
    # Установка Playwright
    && npx playwright install chromium --with-deps \
    && apt-get purge -y wget unzip gnupg \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Конфиг с относительным путем (убирает конфликты URL)
RUN echo '{"listen":{"port":8080},"koyeb":true,"parser":{"jac":true,"eth":true,"proxy":true,"playwright":true},"online":{"proxy":true},"proxy":{"all":true},"plugins":[{"name":"Koyeb Bundle","url":"/plugins/koyeb.js"}]}' > /app/init.conf

# Плагин с динамическим определением домена
RUN mkdir -p /app/wwwroot/plugins && \
    echo 'Lampa.plugin.add("koyeb_bundle", function(){ \
        var host = window.location.protocol + "//" + window.location.host; \
        Lampa.Storage.set("parser_use", "true"); \
        Lampa.Storage.set("parser_host", host); \
        Lampa.Storage.set("proxy_all", "true"); \
        Lampa.Storage.set("proxy_host", host); \
        console.log("Koyeb Bundle Active: " + host); \
    });' > /app/wwwroot/plugins/koyeb.js

RUN chmod -R 777 /app

HEALTHCHECK --interval=60s --timeout=15s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080"]
