FROM mcr.microsoft.com/dotnet/aspnet:9.0

WORKDIR /app

# 1. Добавлена nodejs (нужна для Playwright)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl unzip ca-certificates wget nodejs libgbm1 libgtk-3-0 \
    libnspr4 libnss3 libasound2 libxss1 libxtst6 \
    && wget https://lampa.weritos.online/publish.zip -O /tmp/publish.zip \
    && unzip -o /tmp/publish.zip -d /app \
    && rm /tmp/publish.zip \
    && rm -rf /var/lib/apt/lists/*

# 2. Фикс Playwright: подсовываем системную ноду, чтобы не качал свою
RUN mkdir -p /app/.playwright/node/linux-x64 && \
    ln -s /usr/bin/node /app/.playwright/node/linux-x64/node && \
    touch /app/.playwright/node/linux-x64/.done

# 3. Конфиг (добавлен запрет на скачивание ноды cl_node)
RUN echo '{"listen":{"port":8080},"koyeb":true,"api":{"host":"https://lampohka.koyeb.app"},"parser":{"jac":true,"eth":true,"proxy":true},"online":{"proxy":true},"proxy":{"all":true},"playwright":{"cl_node":false}}' > /app/init.conf

# 4. ИСПРАВЛЕННЫЙ ПУТЬ К ПЛАГИНУ (теперь Лампа его увидит)
RUN mkdir -p /app/wwwroot/plugins && \
    echo '{"list":[{"name":"Koyeb.Settings","url":"/plugins/koyeb.js"}]}' > /app/wwwroot/plugins.json && \
    echo 'Lampa.plugin.add("koyeb_settings", function(){ Lampa.Storage.set("parser_use", true); Lampa.Storage.set("parser_host", "https://lampohka.koyeb.app"); Lampa.Storage.set("proxy_all", true); console.log("Koyeb Plugin Loaded"); });' > /app/wwwroot/plugins/koyeb.js

RUN chmod -R 777 /app

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080"]
