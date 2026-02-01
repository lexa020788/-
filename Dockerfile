FROM ://mcr.microsoft.com

# Переменные окружения
ENV DEST="/home/lampac"
ENV ASPNETCORE_URLS="http://+:8080"
WORKDIR $DEST

# Установка необходимых библиотек
USER root
RUN apt-get update && apt-get install -y \
    unzip curl libicu-dev libnss3-dev libgtk-3-dev libxss-dev \
    libasound2 libgdk-pixbuf2.0-dev libnspr4 libatk1.0-0 \
    xvfb coreutils libatk-bridge2.0-0 libdrm-dev libxkbcommon-dev \
    libxcomposite-dev libxdamage-dev libxrandr-dev libgbm-dev \
    libasound2-dev libpangocairo-1.0-0 libpango-1.0-0 libcairo2-dev \
    && rm -rf /var/lib/apt/lists/*

# Скачивание и распаковка Lampac
RUN curl -L -k -o publish.zip https://lampa.weritos.online \
    && unzip -o publish.zip \
    && rm -f publish.zip

# Создаем базовый конфиг. Порт 8080 — стандарт для Koyeb
RUN echo '{"listen": {"port": 8080}}' > init.conf
RUN mkdir -p data && echo -n "1" > data/vers-minor.txt

# Открываем порт
EXPOSE 8080

# Запуск
CMD ["dotnet", "Lampac.dll"]
