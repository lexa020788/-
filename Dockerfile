# ЭТАП 1: Скачивание и распаковка (используем alpine для легкости)
FROM --platform=linux/amd64 alpine:latest AS fetcher
RUN apk add --no-cache wget unzip
WORKDIR /tmp
# Прямая ссылка на ваш архив
RUN wget https://lampa.weritos.online -O publish.zip && \
    unzip -o publish.zip -d /app && \
    rm publish.zip

# ЭТАП 2: Финальный образ (ASP.NET 9.0)
FROM --platform=linux/amd64 ://mcr.microsoft.com
WORKDIR /app

# Устанавливаем зависимости для работы системы и браузерных движков (Playwright)
# Очищаем кэш сразу, чтобы образ был меньше (важно для Hobby 512MB)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libasound2 \
    && rm -rf /var/lib/apt/lists/*

# Копируем файлы из первого этапа
COPY --from=fetcher /app .

# Настройка конфига (HTTPS и API)
RUN echo '{"listen":{"port":8080},"koyeb":true,"api":{"host":"https://lampohka.koyeb.app"},"parser":{"jac":true,"eth":true,"proxy":true},"online":{"proxy":true},"proxy":{"all":true}}' > /app/init.conf

# Настройка плагинов (синхронизируем пути, чтобы не было 404)
RUN mkdir -p /app/wwwroot/plugins && \
    echo '{"list":[{"name":"Koyeb.Bundle","url":"/plugins/koyeb.js"}]}' > /app/wwwroot/plugins.json && \
    echo 'Lampa.plugin.add("koyeb_settings", function(){ \
        Lampa.Storage.set("parser_use", true); \
        Lampa.Storage.set("parser_host", "https://lampohka.koyeb.app"); \
        Lampa.Storage.set("proxy_all", true); \
        console.log("Koyeb Plugin Loaded"); \
    });' > /app/wwwroot/plugins/koyeb.js

# Права доступа (необходимы для записи конфигов во время работы)
RUN chmod -R 777 /app

# Настройки среды
ENV ASPNETCORE_URLS=http://+:8080
ENV DOTNET_RUNNING_IN_CONTAINER=true
EXPOSE 8080

# Проверка здоровья (даем 30 секунд на прогрев .NET)
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Запуск приложения
ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080"]
