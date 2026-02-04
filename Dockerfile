FROM mcr.microsoft.com/dotnet/aspnet:9.0

WORKDIR /app

# 1. Системные библиотеки и Node.js (без sh)
RUN ["apt-get", "update"]
RUN ["apt-get", "install", "-y", "--no-install-recommends", "curl", "unzip", "ca-certificates", "wget", "nodejs", "libgbm1", "libgtk-3-0", "libnspr4", "libnss3", "libasound2", "libxss1", "libxtst6"]

# 2. Скачивание (ПРЯМАЯ ССЫЛКА на файл)
RUN ["wget", "https://github.com", "-O", "/tmp/publish.zip"]

# 3. Распаковка (прямой вызов unzip)
RUN ["unzip", "-o", "/tmp/publish.zip", "-d", "/app"]
RUN ["rm", "/tmp/publish.zip"]

# 4. Фикс Playwright (создание структуры напрямую)
RUN ["mkdir", "-p", "/app/.playwright/node/linux-x64"]
RUN ["mkdir", "-p", "/app/bin/.playwright/node/linux-x64"]
RUN ["ln", "-s", "/usr/bin/node", "/app/.playwright/node/linux-x64/node"]
RUN ["ln", "-s", "/usr/bin/node", "/app/bin/.playwright/node/linux-x64/node"]
RUN ["touch", "/app/.playwright/node/linux-x64/.done"]
RUN ["touch", "/app/bin/.playwright/node/linux-x64/.done"]

# 5. Модули и Репозиторий
RUN ["mkdir", "-p", "/app/module"]
RUN ["/bin/bash", "-c", "echo '{\"repositories\": []}' > /app/module/repository.yaml"]

# 6. Конфигурация Lampac
RUN ["/bin/bash", "-c", "echo '{\"listen\":{\"port\":8080},\"koyeb\":true,\"api\":{\"host\":\"https://lampohka.koyeb.app\"},\"parser\":{\"jac\":true,\"eth\":true,\"proxy\":true},\"online\":{\"proxy\":true},\"proxy\":{\"all\":true},\"playwright\":{\"cl_node\":false}}' > /app/init.conf"]

# 7. Плагины
RUN ["mkdir", "-p", "/app/wwwroot/plugins"]
RUN ["/bin/bash", "-c", "echo '{\"list\":[{\"name\":\"Koyeb.Bundle\",\"url\":\"https://lampohka.koyeb.app\"}]}' > /app/wwwroot/plugins.json"]
RUN ["/bin/bash", "-c", "echo 'Lampa.plugin.add(\"koyeb_settings\", function(){ Lampa.Storage.set(\"parser_use\", true); Lampa.Storage.set(\"parser_host\", \"https://lampohka.koyeb.app\"); Lampa.Storage.set(\"proxy_all\", true); });' > /app/wwwroot/plugins/koyeb.js"]

# 8. Права доступа
RUN ["chmod", "-R", "777", "/app"]

# 9. Точка входа (dotnet без оболочки)
ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080"]
