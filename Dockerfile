# 1. Используем официальный образ
FROM ghcr.io/lampac-talks/lampac:amd64

# Устанавливаем зависимости
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    libicu-dev \
&& rm -rf /var/lib/apt/lists/*

# 2. Настраиваем репозиторий плагинов
# В этом образе корень приложения — это /
RUN mkdir -p /module && \
    echo 'repositories:\n  - name: "Lampac"\n    url: "https://lampac.sh"' > /module/repository.yaml

# 3. ТВОЙ КОНФИГ
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
}' > /init.conf

# 4. ПРАВА ДОСТУПА (только на нужные папки)
RUN chmod 777 /init.conf && chmod -R 777 /module

# Настройки среды
ENV DOTNET_GCHeapHardLimit=1C000000 
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# 5. ФИНАЛЬНЫЙ ЗАПУСК
# В образе ghcr.io приложение лежит в корне
ENTRYPOINT ["dotnet", "/Lampac.dll", "--urls=http://0.0.0.0:8080", "--contentroot=/"]
