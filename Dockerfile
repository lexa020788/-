FROM alpine:3.19

ENV DEST="/home/lampac"
WORKDIR $DEST

# Установка .NET 9 и необходимых библиотек для Lampac
RUN apk add --no-cache \
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
    dotnet9-runtime \
    aspnetcore9-runtime

# Скачивание Lampac
RUN curl -L -k -o publish.zip https://lampa.weritos.online \
    && unzip -o publish.zip \
    && rm -f publish.zip

# Конфиг под порт 8080
RUN echo '{"listen": {"port": 8080}}' > init.conf
RUN mkdir -p data && echo -n "1" > data/vers-minor.txt

EXPOSE 8080

# Запуск напрямую через dotnet
CMD ["dotnet", "Lampac.dll"]
