FROM mcr.microsoft.com/dotnet/aspnet:9.0

# 1. Устанавливаем системные зависимости для работы JS и браузера
RUN apt-get update && apt-get install -y \
    curl unzip ca-certificates libgbm1 libnss3 libatk1.0-0 \
    libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 \
    libxcomposite1 libxdamage1 libxrandr2 gnupg wget \
    && rm -rf /var/lib/apt/lists/*

# 2. Устанавливаем Node.js 20 (через официальный скрипт)
RUN curl -fsSL https://deb.nodesource.com | bash - && \
    apt-get install -y nodejs

WORKDIR /app

# 3. Скачиваем Lampac и правим JSON (включаем Animebesst и AnimeGo)
RUN wget https://lampa.weritos.online -O /tmp/publish.zip && \
    unzip -o /tmp/publish.zip -d /app && \
    rm /tmp/publish.zip && \
    if [ -f /app/module/conf.json ]; then \
      sed -i 's/"enable": false/"enable": true/g' /app/module/conf.json && \
      sed -i 's/"enabled": false/"enabled": true/g' /app/module/conf.json; \
    fi

# 4. Настройка прав и путей
RUN chmod -R 777 /app
ENV PLAYWRIGHT_BROWSERS_PATH=/app/.playwright
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# Создаем начальный конфиг
RUN echo '{"listen": {"port": 8080}}' > init.conf

ENTRYPOINT ["dotnet", "Lampac.dll"]
