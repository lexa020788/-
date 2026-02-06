# 1. Берем готовый образ из указанного тобой репозитория
FROM --platform=linux/amd64 ghcr.io/lampac-talks/lampac:latest

# 2. Настраиваем репозитории плагинов (меняем на стабильный lampac.sh)
RUN mkdir -p /app/module && \
    echo 'repositories: \n - name: "Lampac" \n   url: "https://lampac.sh"' > /app/module/repository.yaml

WORKDIR /app

# 3. Твой конфиг для Koyeb (порт 8080 и прокси)
RUN echo '{\
 "listen": {"port": 8080, "frontend": "cloudflare"},\
 "host": "lampohka.koyeb.app",\
 "proxy": {"psearch": true, "all": true},\
 "jac": {\
 "enable": true,\
 "apikey": "123",\
 "items": [\
 { "name": "rutracker", "enable": true },\
 { "name": "kinozal", "enable": true },\
 { "name": "rutor", "enable": true },\
 { "name": "nnmclub", "enable": true }\
 ]\
 },\
 "LampaWeb": {\
 "init": {\
 "parser_use": true,\
 "parser_host": "https://lampohka.koyeb.app"\
 }\
 },\
 "plugins": [\
 "https://nb99.github.io",\
 "https://bwa.to"\
 ],\
 "Playwright": {"enable": false},\
 "AnimeGo": {"enable": true, "useproxy": true, "host": "https://animego.me"},\
 "Animebesst": {"enable": true, "useproxy": true, "host": "https://anime1.best"}\
 }' > /app/init.conf

# Права доступа (на всякий случай для записи логов/баз)
RUN chmod -R 777 /app

# Настройки для Koyeb (512MB RAM)
ENV DOTNET_GCHeapHardLimit=1C000000
ENV ASPNETCORE_URLS=http://+:8080

EXPOSE 8080

# 4. Запуск (используем штатный DLL из образа)
ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080", "--contentroot=/app"]
