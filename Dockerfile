FROM mcr.microsoft.com/dotnet/aspnet:9.0

WORKDIR /app

# 1. Системные утилиты и Node.js (берем стабильные из репозитория)
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    ca-certificates \
    wget \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# 2. Загрузка приложения
RUN wget https://lampa.weritos.online -O /tmp/publish.zip \
    && unzip -o /tmp/publish.zip -d /app \
    && rm /tmp/publish.zip \
    && chmod -R 777 /app

# 3. Установка Playwright (основной виновник прошлых ошибок)
RUN npx -y playwright install --with-deps chromium

# 4. Генерация конфигов
RUN echo '{"listen":{"port":8080},"koyeb":true,"api":{"host":"lampohka.koyeb.app"},"parser":{"jac":true,"eth":true,"proxy":true},"online":{"proxy":true},"proxy":{"all":true}}' > /app/init.conf

RUN mkdir -p /app/wwwroot/plugins && \
    echo '{"list":[{"name":"Koyeb.Bundle","url":"http://lampohka.koyeb.app"}]}' > /app/wwwroot/plugins.json && \
    echo 'window.lampa_settings = { "parser_use": true, "parser_host": "http://lampohka.koyeb.app" };' > /app/wwwroot/plugins/koyeb.js

# 5. Порты и запуск
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080", "--update=true"]
