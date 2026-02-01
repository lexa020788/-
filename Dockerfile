FROM ://mcr.microsoft.com

ENV DEST="/home/lampac"
ENV ASPNETCORE_URLS="http://+:8080"
WORKDIR $DEST

# Установка системных библиотек
USER root
RUN apt-get update && apt-get install -y \
    curl unzip libicu-dev libnss3 libatk1.0-0 libatk-bridge2.0-0 \
    libcups2 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 \
    libxrandr2 libgbm1 libasound2 libpango-1.0-0 libcairo2 \
    && rm -rf /var/lib/apt/lists/*

# Загрузка Lampac
RUN curl -L -o publish.zip https://lampa.weritos.online \
    && unzip -o publish.zip \
    && rm -f publish.zip

# Конфиг и запуск
RUN echo '{"listen": {"port": 8080}}' > init.conf
RUN mkdir -p data && echo -n "1" > data/vers-minor.txt

EXPOSE 8080

CMD ["dotnet", "Lampac.dll"]
