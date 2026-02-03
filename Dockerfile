FROM mcr.microsoft.com/dotnet/aspnet:9.0

WORKDIR /app

# 1. Устанавливаем системные зависимости
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
    # 2. АКТУАЛЬНЫЙ способ установки Node.js 20 (без битых скриптов)
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y nodejs \
    # 3. Скачиваем приложение (ИСПРАВЛЕНО: прямая ссылка на zip)
    && wget https://lampa.weritos.online -O /tmp/publish.zip \
    && unzip -o /tmp/publish.zip -d /app \
    # 4. ФИКСЫ ДЛЯ PLAYWRIGHT И REPOSITORY
    && mkdir -p /app/.playwright/node/linux-x64 \
    && ln -s /usr/bin/node /app/.playwright/node/linux-x64/node \
    && mkdir -p /app/module \
    && echo '{"repositories": []}' > /app/module/repository.yaml \
    # Очистка
    && rm /tmp/publish.zip \
    && apt-get purge -y wget unzip \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Создаем конфиг
RUN echo '{"listen":{"port":8080},"koyeb":true,"api":{"host":"https://lampohka.koyeb.app"},"parser":{"jac":true,"eth":true,"proxy":true},"online":{"proxy":true},"proxy":{"all":true}}' > /app/init.conf

# Плагины
RUN mkdir -p /app/wwwroot/plugins && \
    echo '{"list":[{"name":"Koyeb.Bundle","url":"https://lampohka.koyeb.app"}]}' > /app/wwwroot/plugins.json && \
    echo 'Lampa.plugin.add("koyeb_settings", function(){ Lampa.Storage.set("parser_use", true); Lampa.Storage.set("parser_host", "https://lampohka.koyeb.app"); Lampa.Storage.set("proxy_all", true); console.log("Koyeb Plugin Loaded"); });' > /app/wwwroot/plugins/koyeb.js

RUN chmod -R 777 /app

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080"]
