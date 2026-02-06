# 1. Используем правильный тег официального образа (amd64)
FROM ghcr.io/lampac-talks/lampac:amd64

# Устанавливаем зависимости (в ghcr.io они обычно есть, но закрепим)
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    libicu-dev \
&& rm -rf /var/lib/apt/lists/*

# 2. Настраиваем стабильный репозиторий (Weritos часто лежит, lampac.sh надежнее)
RUN mkdir -p /app/module && \
    echo 'repositories:\n  - name: "Lampac"\n    url: "https://lampac.sh"' > /app/module/repository.yaml

WORKDIR /app

# ВАЖНО: Убрали wget и unzip. В образе ghcr.io УЖЕ лежит готовый Lampac.
# Если ты скачаешь поверх него архив с другого сайта, он не запустится.

# 3. ТВОЙ КОНФИГ (Исправили форматирование для корректного JSON)
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

RUN chmod -R 777 /app

# Ограничение памяти для 512MB RAM
ENV DOTNET_GCHeapHardLimit=1C000000 
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# 4. ЗАПУСК (указываем полный путь к DLL)
ENTRYPOINT ["dotnet", "/app/Lampac.dll", "--urls=http://0.0.0.0:8080", "--contentroot=/app"]




