FROM mcr.microsoft.com/dotnet/aspnet:9.0

WORKDIR /app

# 1. Устанавливаем Node.js (необходим для Playwright) и системные зависимости
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    ca-certificates \
    wget \
    gnupg \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libasound2 \
    libxss1 \
    libxtst6 \
    && curl -fsSL https://deb.nodesource.com | bash - \
    && apt-get install -y nodejs \
    # 2. Скачиваем само приложение
    && wget https://lampa.weritos.online/publish.zip -O /tmp/publish.zip \
    && unzip -o /tmp/publish.zip -d /app \
    && rm /tmp/publish.zip \
    # 3. Создаем структуру для модулей, чтобы не было ошибки "repository config file not found"
    && mkdir -p /app/module \
    && echo '{"repositories": []}' > /app/module/repository.yaml \
    && apt-get purge -y wget unzip \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Создаем конфиг (HTTPS везде)
RUN echo '{"listen":{"port":8080},"koyeb":true,"api":{"host":"https://lampohka.koyeb.app"},"parser":{"jac":true,"eth":true,"proxy":true},"online":{"proxy":true},"proxy":{"all":true}}' > /app/init.conf

# Плагины
RUN mkdir -p /app/wwwroot/plugins && \
    echo '{"list":[{"name":"Koyeb.Bundle","url":"https://lampohka.koyeb.app"}]}' > /app/wwwroot/plugins.json && \
    echo 'Lampa.plugin.add("koyeb_settings", function(){ Lampa.Storage.set("parser_use", true); Lampa.Storage.set("parser_host", "https://lampohka.koyeb.app"); Lampa.Storage.set("proxy_all", true); console.log("Koyeb Plugin Loaded"); });' > /app/wwwroot/plugins/koyeb.js

# Даем полные права на папку (важно для записи кэша и загрузки Node Playwright-ом)
RUN chmod -R 777 /app

# Указываем Playwright использовать системный Node, если это возможно
ENV NODE_PATH=/usr/lib/node_modules

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080"]
