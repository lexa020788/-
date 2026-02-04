
FROM --platform=linux/amd64 mcr.microsoft.com/dotnet/aspnet:9.0

# Устанавливаем ICU (важно для парсеров)
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    libicu-dev \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN apt-get update && apt-get install -y wget unzip curl ca-certificates && \
    wget https://lampa.weritos.online/publish.zip -O /tmp/publish.zip && \
    unzip -o /tmp/publish.zip -d /app && \
    rm /tmp/publish.zip
    
RUN chmod -R 777 /app

# 3. КОНФИГ С ЛЕГКИМИ ПЛАГИНАМИ
# Мы добавили: TMDB (постеры), Online (кино), Torrents (поиск), Lite (скорость)
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
    "https://lampohka.koyeb.app",\
    "https://lampohka.koyeb.app",\
    "https://lampohka.koyeb.app"\
  ],\
  "Playwright": {"enable": false},\
  "AnimeGo": {"enable": true, "useproxy": true},\
  "Animebesst": {"enable": true, "useproxy": true}\
}' > init.conf

# Ограничение аппетитов .NET для Hobby тарифа (512MB)
ENV DOTNET_GCHeapHardLimit=1C000000 
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# 4. ФИНАЛЬНЫЙ ЗАПУСК (с исправлением путей)
ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080", "--contentroot=/app"]




