FROM alpine:3.19

ENV DEST="/home/lampac"
WORKDIR $DEST
ENV ASPNETCORE_URLS="http://+:8080"

# Установка .NET 8 и необходимых библиотек для Lampac из репозиториев Alpine
RUN apk update && apk add --no-cache \
    curl \
    unzip \
    bash \
    icu-libs \
    krb5-libs \
    libgcc \
    libintl \
    libssl3 \
    libstdc++ \
    zlib \
    libnss3 \
    at-spi2-core \
    libdrm \
    libxkbcommon \
    libxcomposite \
    libxdamage \
    libxrandr \
    mesa-gbm \
    alsa-lib \
    pango \
    cairo \
    # Пакеты .NET 8 в Alpine
    dotnet8-runtime \
    aspnetcore8-runtime \
    && rm -rf /var/cache/apk/*

# Скачивание Lampac
RUN curl -L -k -o publish.zip https://lampa.weritos.online \
    && unzip -o publish.zip \
    && rm -f publish.zip

# Конфиг под порт 8080
RUN echo '{"listen": {"port": 8080}}' > init.conf
RUN mkdir -p data && echo -n "1" > data/vers-minor.txt

EXPOSE 8080

# Запуск
CMD ["dotnet", "Lampac.dll"]
