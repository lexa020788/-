FROM mcr.microsoft.com/dotnet/aspnet:9.0

WORKDIR /app

# 1. Системные библиотеки
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl unzip ca-certificates wget nodejs libgbm1 libgtk-3-0 \
    libnspr4 libnss3 libasound2 libxss1 libxtst6 \
    && rm -rf /var/lib/apt/lists/*

# 2. ИСПРАВЛЕНО: Прямая ссылка на ZIP (добавлен /publish.zip)
RUN wget https://lampa.weritos.online -O /tmp/publish.zip

# 3. Распаковка
RUN unzip -o /tmp/publish.zip -d /app && rm /tmp/publish.zip

# 4. Playwright Fix (двойной путь для надежности)
RUN mkdir -p /app/.playwright/node/linux-x64 && \
    mkdir -p /app/bin/.playwright/node/linux-x64 && \
    ln -s /usr/bin/node /app/.playwright/node/linux-x64/node && \
    ln -s /usr/bin/node /app/bin/.playwright/node/linux-x64/node && \
    touch /app/.playwright/node/linux-x64/.done && \
    touch /app/bin/.playwright/node/linux-x64/.done

# 5. Репозиторий и Init (добавлен cl_node: false)
RUN mkdir -p /app/module && \
    echo '{"repositories": []}' > /app/module/repository.yaml && \
    echo '{"listen":{"port":8080},"koyeb":true,"api":{"host":"https://lampohka.koyeb.app"},"parser":{"jac":true,"eth":true,"proxy":true},"online":{"proxy":true},"proxy":{"all":true},"playwright":{"cl_node":false}}' > /app/init.conf

# 6. ИСПРАВЛЕНО: Настройка плагинов (теперь они подтянутся локально)
RUN mkdir -p /app/wwwroot/plugins && \
    echo '{"list":[{"name":"Koyeb.Settings","url":"/plugins/koyeb.js"},{"name":"MX.Online","url":"https://lampa.mx"}]}' > /app/wwwroot/plugins.json && \
    echo 'Lampa.plugin.add("koyeb_settings", function(){ Lampa.Storage.set("parser_use", true); Lampa.Storage.set("parser_host", "https://lampohka.koyeb.app"); Lampa.Storage.set("proxy_all", true); });' > /app/wwwroot/plugins/koyeb.js

# 7. Права доступа
RUN chmod -R 777 /app

# 8. Запуск напрямую (без sh)
ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080"]
