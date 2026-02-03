FROM mcr.microsoft.com/dotnet/aspnet:9.0

WORKDIR /app

# Объединяем установку и скачивание в один слой
RUN apt-get update && apt-get install -y curl unzip ca-certificates wget && \
    wget https://lampa.weritos.online/publish.zip -O /tmp/publish.zip && \
    unzip -o /tmp/publish.zip -d /app && \
    rm /tmp/publish.zip && \
    apt-get purge -y wget unzip && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Создаем конфиг
RUN echo '{"listen":{"port":8080},"koyeb":true,"api":{"host":"lampohka.koyeb.app"},"parser":{"jac":true,"eth":true,"proxy":true},"online":{"proxy":true},"proxy":{"all":true}}' > /app/init.conf

# Правильный формат плагина для Lampa (Lampa.plugin.add)
RUN mkdir -p /app/wwwroot/plugins && \
    echo '{"list":[{"name":"Koyeb.Bundle","url":"https://lampohka.koyeb.app"}]}' > /app/wwwroot/plugins.json && \
    echo '(function(){ var settings = {"parser_use": true, "parser_host": "https://lampohka.koyeb.app"}; Lampa.Storage.set("online_proxy_all", true); })();' > /app/wwwroot/plugins/koyeb.js

RUN chmod -R 777 /app

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080"]
