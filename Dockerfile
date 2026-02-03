FROM mcr.microsoft.com/dotnet/aspnet:9.0

# 1. Устанавливаем системные зависимости
RUN apt-get update && apt-get install -y \
    curl unzip ca-certificates libgbm1 libnss3 libatk1.0-0 \
    libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 \
    libxcomposite1 libxdamage1 libxrandr2 gnupg wget \
    && rm -rf /var/lib/apt/lists/*

# 2. Надежный метод установки Node.js 20 без внешних bash-скриптов
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && apt-get install nodejs -y

WORKDIR /app

# 3. Скачиваем Lampac
RUN wget https://lampa.weritos.online -O /tmp/publish.zip && \
    unzip -o /tmp/publish.zip -d /app && \
    rm /tmp/publish.zip

# 4. Включаем плагины (AnimeGo, Animebesst) и даем права
RUN if [ -d "/app/module" ]; then \
      find /app/module -name "*.json" -exec sed -i 's/"enable": false/"enable": true/g' {} + && \
      find /app/module -name "*.json" -exec sed -i 's/"enabled": false/"enabled": true/g' {} + ; \
    fi && \
    chmod -R 777 /app

# 5. Окружение
ENV PLAYWRIGHT_BROWSERS_PATH=/app/.playwright
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

RUN echo '{"listen": {"port": 8080}}' > init.conf

ENTRYPOINT ["dotnet", "Lampac.dll"]
