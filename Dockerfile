FROM mcr.microsoft.com/dotnet/aspnet:9.0

WORKDIR /app

# Hobby план позволяет нам установить Chromium
RUN apt-get update && apt-get install -y \
    curl unzip ca-certificates wget \
    libgbm1 libgtk-3-0 libnspr4 libnss3 libasound2 \
    && curl -fsSL https://deb.nodesource.com | bash - \
    && apt-get install -y nodejs \
    && wget https://lampa.weritos.online -O /tmp/publish.zip \
    && unzip -o /tmp/publish.zip -d /app \
    && rm /tmp/publish.zip \
    # Устанавливаем браузер для качественного парсинга
    && npx playwright install chromium --with-deps \
    && apt-get purge -y wget unzip \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Конфиг: url плагина указан от корня (/), чтобы не было конфликтов с доменом
RUN echo '{"listen":{"port":8080},"koyeb":true,"parser":{"jac":true,"eth":true,"proxy":true,"playwright":true},"online":{"proxy":true},"proxy":{"all":true},"plugins":[{"name":"Koyeb Bundle","url":"/plugins/koyeb.js"}]}' > /app/init.conf

# JS Плагин с динамическим определением хоста
RUN mkdir -p /app/wwwroot/plugins && \
    echo 'Lampa.plugin.add("koyeb_bundle", function(){ \
        var host = window.location.protocol + "//" + window.location.host; \
        Lampa.Storage.set("parser_use", "true"); \
        Lampa.Storage.set("parser_host", host); \
        Lampa.Storage.set("proxy_all", "true"); \
        Lampa.Storage.set("proxy_host", host); \
        console.log("Koyeb Bundle Loaded on " + host); \
    });' > /app/wwwroot/plugins/koyeb.js

RUN chmod -R 777 /app

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080"]
