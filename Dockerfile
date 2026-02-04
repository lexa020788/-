# ЭТАП 1: Скачивание и подготовка файлов (Легкий Alpine)
FROM --platform=linux/amd64 alpine:latest AS fetcher
RUN apk add --no-cache wget unzip
WORKDIR /tmp
# Прямая рабочая ссылка на ваш архив
RUN wget https://lampa.weritos.online -O publish.zip && \
    unzip -o publish.zip -d /app && \
    rm publish.zip

# ЭТАП 2: Финальный образ (Используем GitHub Container Registry вместо Microsoft)
FROM --platform=linux/amd64 ghcr.io/actions/dotnet-aspnet:9.0
WORKDIR /app

# Установка системных библиотек для Playwright и работы системы
# Очистка кэша apt снижает размер образа для 512MB RAM на Koyeb
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libasound2 \
    && rm -rf /var/lib/apt/lists/*

# Переносим распакованное приложение из первого этапа
COPY --from=fetcher /app .

# Генерируем конфиг (HTTPS настройки и API хост)
RUN echo '{"listen":{"port":8080},"koyeb":true,"api":{"host":"https://lampohka.koyeb.app"},"parser":{"jac":true,"eth":true,"proxy":true},"online":{"proxy":true},"proxy":{"all":true}}' > /app/init.conf

# Настройка плагинов: plugins.json ссылается на локальный js файл
RUN mkdir -p /app/wwwroot/plugins && \
    echo '{"list":[{"name":"Koyeb.Bundle","url":"/plugins/koyeb.js"}]}' > /app/wwwroot/plugins.json && \
    echo 'Lampa.plugin.add("koyeb_settings", function(){ \
        Lampa.Storage.set("parser_use", true); \
        Lampa.Storage.set("parser_host", "https://lampohka.koyeb.app"); \
        Lampa.Storage.set("proxy_all", true); \
        console.log("Koyeb Plugin Loaded"); \
    });' > /app/wwwroot/plugins/koyeb.js

# Даем полные права на папку для корректной записи логов и БД
RUN chmod -R 777 /app

# Настройки для Koyeb: порт и режим контейнера
ENV ASPNETCORE_URLS=http://+:8080
ENV DOTNET_RUNNING_IN_CONTAINER=true
EXPOSE 8080

# Проверка работоспособности (Healthcheck)
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Запуск Lampac
ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080"]
