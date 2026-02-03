FROM mcr.microsoft.com/dotnet/aspnet:9.0

WORKDIR /app

# 1. Устанавливаем системные зависимости и Node.js 20
RUN apt-get update && apt-get install -y curl unzip ca-certificates wget gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# 2. Скачиваем и распаковываем приложение
RUN wget https://lampa.weritos.online/publish.zip -O /tmp/publish.zip \
    && unzip -o /tmp/publish.zip -d /app \
    && rm /tmp/publish.zip \
    && chmod -R 777 /app

# 3. Устанавливаем Playwright и браузеры со всеми системными зависимостями
RUN npx playwright install --with-deps chromium

# 4. Создаем конфиги
RUN echo '{"listen":{"port":8080},"koyeb":true,"api":{"host":"lampohka.koyeb.app"},"parser":{"jac":true,"eth":true,"proxy":true},"online":{"proxy":true},"proxy":{"all":true}}' > /app/init.conf

RUN mkdir -p /app/wwwroot/plugins && \
    echo '{"list":[{"name":"Koyeb.Bundle","url":"http://lampohka.koyeb.app"}]}' > /app/wwwroot/plugins.json && \
    echo 'window.lampa_settings = { "parser_use": true, "parser_host": "http://lampohka.koyeb.app" };' > /app/wwwroot/plugins/koyeb.js

# 5. Настройки среды
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080", "--update=true"]
