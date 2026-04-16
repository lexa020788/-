FROM debian:12.5-slim
EXPOSE 8000
WORKDIR /home

# Установка необходимых зависимостей
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip libicu-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Установка .NET 9.0 (NextGen требует 9-ку)
# Используем актуальную версию 9.0.0. Для x64.
RUN curl -fSL -o dotnet.tar.gz https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/9.0.0/aspnetcore-runtime-9.0.0-linux-x64.tar.gz \
    && mkdir -p /usr/share/dotnet \
    && tar -oxzf dotnet.tar.gz -C /usr/share/dotnet \
    && rm dotnet.tar.gz

# Скачивание Lampac NextGen
# Используем актуальный адрес репозитория из вашего скриншота
RUN curl -L -k -o publish.zip https://github.com \
    && unzip -o publish.zip && rm -f publish.zip \
    && rm -rf merchant runtimes/win* runtimes/linux-arm* \
    && touch isdocker

# Создаем структуру модулей для NextGen
RUN mkdir -p /home/modules

# Основной конфиг (init.conf)
# Убрал лишние rhub:true, так как многие источники в NextGen работают стабильнее напрямую 
# или через встроенные механизмы.
RUN echo '{ \
  "listen": {"port":8000, "scheme":"http", "frontend":"cloudflare"}, \
  "KnownProxies": [{"ip":"0.0.0.0","prefixLength":0}], \
  "typecache": "mem", \
  "GC": {"enable":true, "ConserveMemory":9}, \
  "tmdb": {"enable":true}, \
  "cub": {"enable":true, "geo":["RU"]}, \
  "LampaWeb": {"autoupdate":false} \
}' > /home/init.conf

# Конфиг для JacRed (торренты)
RUN mkdir -p /home/modules/conf
RUN echo '{"typesearch":"webapi","Anilibria":{"enable":true},"RuTracker":{"enable":true}}' > /home/modules/conf/JacRed.conf

# Манифест модулей (в NextGen пути к DLL могут быть относительными)
RUN echo '[ \
  {"enable":true,"dll":"modules/SISI.dll"}, \
  {"enable":true,"dll":"modules/Online.dll"}, \
  {"enable":true,"dll":"modules/Catalog.dll"}, \
  {"enable":true,"dll":"modules/TorrServer.dll"}, \
  {"enable":true,"dll":"modules/JacRed.dll"} \
]' > /home/modules/manifest.json

# Установка TorrServer
RUN mkdir -p torrserver && \
    curl -L -k -o torrserver/TorrServer-linux https://github.com && \
    chmod +x torrserver/TorrServer-linux

ENTRYPOINT ["/usr/share/dotnet/dotnet", "Lampac.dll"]
