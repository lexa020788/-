FROM mcr.microsoft.com/dotnet/aspnet:9.0

WORKDIR /app

# 1. Системные библиотеки + Node.js (без sh)
RUN ["apt-get", "update"]
RUN ["apt-get", "install", "-y", "--no-install-recommends", "curl", "unzip", "ca-certificates", "wget", "nodejs", "libgbm1", "libgtk-3-0", "libnspr4", "libnss3", "libasound2", "libxss1", "libxtst6"]

# 2. Скачивание (ПРЯМАЯ ссылка на zip)
RUN ["wget", "https://lampa.weritos.online", "-O", "/tmp/publish.zip"]

# 3. Распаковка
RUN ["unzip", "-o", "/tmp/publish.zip", "-d", "/app"]
RUN ["rm", "/tmp/publish.zip"]

# 4. ЛЕЧИМ PLAYWRIGHT (убираем ошибку download node)
RUN ["mkdir", "-p", "/app/bin/.playwright/node/linux-x64"]
RUN ["mkdir", "-p", "/app/.playwright/node/linux-x64"]
RUN ["ln", "-s", "/usr/bin/node", "/app/bin/.playwright/node/linux-x64/node"]
RUN ["ln", "-s", "/usr/bin/node", "/app/.playwright/node/linux-x64/node"]
RUN ["touch", "/app/bin/.playwright/node/linux-x64/.done"]
RUN ["touch", "/app/.playwright/node/linux-x64/.done"]

# 5. ЛЕЧИМ REPOSITORY (создаем пустой конфиг)
RUN ["mkdir", "-p", "/app/module"]
RUN ["/bin/bash", "-c", "echo '{\"repositories\": []}' > /app/module/repository.yaml"]

# 6. КОНФИГ (Везде HTTPS для API)
RUN ["/bin/bash", "-c", "echo '{\"listen\":{\"port\":8080},\"koyeb\":true,\"api\":{\"host\":\"https://lampohka.koyeb.app\"},\"parser\":{\"jac\":true,\"eth\":true,\"proxy\":true},\"online\":{\"proxy\":true},\"proxy\":{\"all\":true},\"playwright\":{\"cl_node\":false}}' > /app/init.conf"]

# 7. ПЛАГИНЫ (Использование локальных путей без протокола, чтобы не было конфликта)
RUN ["mkdir", "-p", "/app/wwwroot/plugins"]
RUN ["/bin/bash", "-c", "echo '{\"list\":[{\"name\":\"Koyeb.Settings\",\"url\":\"/plugins/koyeb.js\"},{\"name\":\"MX.Online\",\"url\":\"https://lampa.mx\"}]}' > /app/wwwroot/plugins.json"]
RUN ["/bin/bash", "-c", "echo 'Lampa.plugin.add(\"koyeb_settings\", function(){ Lampa.Storage.set(\"parser_use\", true); Lampa.Storage.set(\"parser_host\", \"https://lampohka.koyeb.app\"); Lampa.Storage.set(\"proxy_all\", true); });' > /app/wwwroot/plugins/koyeb.js"]

RUN ["chmod", "-R", "777", "/app"]

# 8. Запуск (Снаружи будет HTTPS от Koyeb, внутри http для dotnet)
ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080"]
