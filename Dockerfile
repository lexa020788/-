FROM mcr.microsoft.com/dotnet/aspnet:9.0

WORKDIR /app

# Исправленная установка Node.js и системных библиотек
RUN apt-get update && apt-get install -y \
    curl unzip ca-certificates wget \
    libgbm1 libgtk-3-0 libnspr4 libnss3 libasound2 \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install nodejs -y \
    # Исправленная ссылка на архив Lampac
    && wget https://lampa.weritos.online -O /tmp/publish.zip \
    && unzip -o /tmp/publish.zip -d /app \
    && rm /tmp/publish.zip \
    # Установка Playwright Chromium
    && npx playwright install chromium --with-deps \
    && apt-get purge -y wget unzip \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Конфиг: относительный путь для плагина убирает конфликты доменов
RUN echo '{"listen":{"port":8080},"koyeb":true,"parser":{"jac":true,"eth":true,"proxy":true,"playwright":true},"online":{"proxy":true},"proxy":{"all":true},"plugins":[{"name":"Koyeb Bundle","url":"/plugins/koyeb.js"}]}' > /app/init.conf

# JS Плагин: динамически подхватывает текущий адрес Koyeb
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

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080"]
