FROM mcr.microsoft.com/dotnet/aspnet:9.0

WORKDIR /app

# 1. Устанавливаем системные библиотеки и Node.js напрямую
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl unzip ca-certificates wget nodejs libgbm1 libgtk-3-0 \
    libnspr4 libnss3 libasound2 libxss1 libxtst6 \
    && rm -rf /var/lib/apt/lists/*

# 2. Скачиваем архив
RUN wget https://lampa.weritos.online -O /tmp/publish.zip

# 3. Распаковываем
RUN unzip -o /tmp/publish.zip -d /app && rm /tmp/publish.zip

# 4. ФИКС PLAYWRIGHT: создаем пути и маркеры .done, чтобы обмануть загрузчик
RUN mkdir -p /app/.playwright/node/linux-x64 && \
    mkdir -p /app/bin/.playwright/node/linux-x64 && \
    ln -s /usr/bin/node /app/.playwright/node/linux-x64/node && \
    ln -s /usr/bin/node /app/bin/.playwright/node/linux-x64/node && \
    touch /app/.playwright/node/linux-x64/.done && \
    touch /app/bin/.playwright/node/linux-x64/.done

# Исправляем репозиторий
RUN mkdir -p /app/module && \
    echo '{"repositories": []}' > /app/module/repository.yaml

# 5. Создаем конфиг (запрещаем скачивание ноды через cl_node)
RUN echo '{"listen":{"port":8080},"koyeb":true,"api":{"host":"https://lampohka.koyeb.app"},"parser":{"jac":true,"eth":true,"proxy":true},"online":{"proxy":true},"proxy":{"all":true},"playwright":{"cl_node":false}}' > /app/init.conf

# 6. Настройка плагинов
RUN mkdir -p /app/wwwroot/plugins && \
    echo '{"list":[{"name":"Koyeb.Bundle","url":"https://lampohka.koyeb.app"}]}' > /app/wwwroot/plugins.json && \
    echo 'Lampa.plugin.add("koyeb_settings", function(){ Lampa.Storage.set("parser_use", true); Lampa.Storage.set("parser_host", "https://lampohka.koyeb.app"); Lampa.Storage.set("proxy_all", true); });' > /app/wwwroot/plugins/koyeb.js

# 7. Права доступа
RUN chmod -R 777 /app

# 8. Запуск напрямую
ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080"]
