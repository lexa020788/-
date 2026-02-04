FROM mcr.microsoft.com/dotnet/aspnet:9.0

WORKDIR /app

# 1. Системные библиотеки (прямой вызов без sh)
RUN ["apt-get", "update"]
RUN ["apt-get", "install", "-y", "--no-install-recommends", "curl", "unzip", "ca-certificates", "wget", "nodejs", "libgbm1", "libgtk-3-0", "libnspr4", "libnss3", "libasound2", "libxss1", "libxtst6"]

# 2. Скачивание (ПРЯМАЯ ССЫЛКА на файл архива, чтобы unzip не ругался)
RUN ["wget", "https://github.com", "-O", "/tmp/publish.zip"]

# 3. Распаковка
RUN ["unzip", "-o", "/tmp/publish.zip", "-d", "/app"]
RUN ["rm", "/tmp/publish.zip"]

# 4. Фикс Playwright: обман загрузчика через маркеры .done и симлинки на системную ноду
RUN ["mkdir", "-p", "/app/.playwright/node/linux-x64"]
RUN ["mkdir", "-p", "/app/bin/.playwright/node/linux-x64"]
RUN ["ln", "-s", "/usr/bin/node", "/app/.playwright/node/linux-x64/node"]
RUN ["ln", "-s", "/usr/bin/node", "/app/bin/.playwright/node/linux-x64/node"]
RUN ["touch", "/app/.playwright/node/linux-x64/.done"]
RUN ["touch", "/app/bin/.playwright/node/linux-x64/.done"]

# 5. Инициализация репозитория
RUN ["mkdir", "-p", "/app/module"]
RUN ["/bin/bash", "-c", "echo '{\"repositories\": []}' > /app/module/repository.yaml"]

# 6. Создание init.conf (с твоим хостом и фиксом ноды)
RUN ["/bin/bash", "-c", "echo '{\"listen\":{\"port\":8080},\"koyeb\":true,\"api\":{\"host\":\"https://lampohka.koyeb.app\"},\"parser\":{\"jac\":true,\"eth\":true,\"proxy\":true},\"online\":{\"proxy\":true},\"proxy\":{\"all\":true},\"playwright\":{\"cl_node\":false}}' > /app/init.conf"]

# 7. Плагины: MX Online + твои встроенные настройки Koyeb
RUN ["mkdir", "-p", "/app/wwwroot/plugins"]
RUN ["/bin/bash", "-c", "echo '{\"list\":[{\"name\":\"MX Online\",\"url\":\"https://lampa.mx\"},{\"name\":\"Koyeb.Settings\",\"url\":\"/plugins/koyeb.js\"}]}' > /app/wwwroot/plugins.json"]
RUN ["/bin/bash", "-c", "echo 'Lampa.plugin.add(\"koyeb_settings\", function(){ Lampa.Storage.set(\"parser_use\", true); Lampa.Storage.set(\"parser_host\", \"https://lampohka.koyeb.app\"); Lampa.Storage.set(\"proxy_all\", true); });' > /app/wwwroot/plugins/koyeb.js"]

# 8. Права доступа
RUN ["chmod", "-R", "777", "/app"]

# 9. Запуск процесса напрямую через dotnet
ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080"]
