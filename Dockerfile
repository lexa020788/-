# Использование официального образа Microsoft ASP.NET
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app

# Объединяем установку зависимостей, скачивание и распаковку в один слой
# Это гарантирует отсутствие ошибок 'sh' и проблем с правами доступа
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    unzip \
    curl \
    ca-certificates \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libasound2 \
    && wget https://lampa.weritos.online -O /tmp/publish.zip \
    && unzip -o /tmp/publish.zip -d /app \
    && rm /tmp/publish.zip \
    && apt-get purge -y wget unzip \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Конфигурация приложения (API и настройки Koyeb)
RUN echo '{"listen":{"port":8080},"koyeb":true,"api":{"host":"https://lampohka.koyeb.app"},"parser":{"jac":true,"eth":true,"proxy":true},"online":{"proxy":true},"proxy":{"all":true}}' > /app/init.conf

# Настройка плагинов для Lampa (исправлен путь в plugins.json)
RUN mkdir -p /app/wwwroot/plugins && \
    echo '{"list":[{"name":"Koyeb.Bundle","url":"/plugins/koyeb.js"}]}' > /app/wwwroot/plugins.json && \
    echo 'Lampa.plugin.add("koyeb_settings", function(){ \
        Lampa.Storage.set("parser_use", true); \
        Lampa.Storage.set("parser_host", "https://lampohka.koyeb.app"); \
        Lampa.Storage.set("proxy_all", true); \
        console.log("Koyeb Plugin Loaded"); \
    });' > /app/wwwroot/plugins/koyeb.js

# Права доступа для корректной работы Lampac
RUN chmod -R 777 /app

# Настройки среды для Koyeb
ENV ASPNETCORE_URLS=http://+:8080
ENV DOTNET_RUNNING_IN_CONTAINER=true
EXPOSE 8080

# Проверка здоровья
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Запуск приложения через Dotnet
ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080"]
