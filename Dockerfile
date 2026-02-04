# Исправлено: чистый путь к образу с указанием платформы
FROM --platform=linux/amd64 mcr.microsoft.com/dotnet/aspnet:9.0

# 1. Системные зависимости (libicu важен для работы плагинов)
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    libicu-dev \
&& rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y wget unzip curl ca-certificates && \
    wget https://lampa.weritos.online/publish.zip -O /tmp/publish.zip && \
    unzip -o /tmp/publish.zip -d /app && \
    rm /tmp/publish.zip

WORKDIR /app

RUN chmod -R 777 /app

# 3. Конфиг: домен, прокси и авто-настройка парсера для Lampa
RUN echo '{\
  "listen": {"port": 8080},\
  "host": "lampohka.koyeb.app",\
  "proxy": {"psearch": true, "all": true},\
  "jac": {"enable": true},\
  "LampaWeb": {\
    "init": {\
      "parser_use": true,\
      "parser_host": "https://lampohka.koyeb.app"\
    }\
  },\
  "plugins": [\
    "https://lampohka.koyeb.app",\
    "https://lampohka.koyeb.app"\
  ],\
  "Playwright": {"enable": false}\
}' > init.conf

# Ограничение памяти для тарифа Hobby
ENV DOTNET_GCHeapHardLimit=1C000000 
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# Запуск с contentroot
ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080", "--contentroot=/app"]



    


