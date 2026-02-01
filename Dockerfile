FROM ubuntu:24.04

ENV DEST="/home/lampac"
WORKDIR $DEST

# 1. Установка необходимых зависимостей и .NET 9 напрямую
RUN apt-get update && apt-get install -y \
    dotnet-sdk-9.0 \
    aspnetcore-runtime-9.0 \
    curl \
    unzip \
    libicu-dev \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpango-1.0-0 \
    libcairo2 \
    && rm -rf /var/lib/apt/lists/*

# 2. Скачивание и распаковка Lampac
RUN curl -L -k -o publish.zip https://lampa.weritos.online \
    && unzip -o publish.zip \
    && rm -f publish.zip

# 3. Настройка конфига (порт 8080 для Koyeb)
RUN echo '{"listen": {"port": 8080}}' > init.conf
RUN mkdir -p data && echo -n "1" > data/vers-minor.txt

EXPOSE 8080

CMD ["dotnet", "Lampac.dll"]
