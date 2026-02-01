FROM debian:12-slim

ENV DEST="/home/lampac"
WORKDIR $DEST

# Установка .NET 9 и нужных библиотек
RUN apt-get update && apt-get install -y wget \
    && wget https://packages.microsoft.com -O packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && rm packages-microsoft-prod.deb \
    && apt-get update && apt-get install -y \
    dotnet-runtime-9.0 \
    aspnetcore-runtime-9.0 \
    unzip curl libicu-dev libnss3 libatk1.0-0 libatk-bridge2.0-0 \
    libcups2 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 \
    libxrandr2 libgbm1 libasound2 libpango-1.0-0 libcairo2 \
    && rm -rf /var/lib/apt/lists/*

# Скачивание Lampac
RUN curl -L -k -o publish.zip https://lampa.weritos.online \
    && unzip -o publish.zip \
    && rm -f publish.zip

# Конфиг на порт 8080 (стандарт Koyeb)
RUN echo '{"listen": {"port": 8080}}' > init.conf
RUN mkdir -p data && echo -n "1" > data/vers-minor.txt

EXPOSE 8080

CMD ["dotnet", "Lampac.dll"]
