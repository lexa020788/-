FROM debian:12.5-slim

# Открываем 8000 (Lampac) и 8090 (TorrServer)
EXPOSE 8000 8090
WORKDIR /home

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip libicu-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Установка .NET
RUN curl -fSL -k -o dotnet.tar.gz https://builds.dotnet.microsoft.com \
    && mkdir -p /usr/share/dotnet \
    && tar -oxzf dotnet.tar.gz -C /usr/share/dotnet \
    && rm dotnet.tar.gz

# Установка Lampac
RUN curl -L -k -o publish.zip https://github.com \
    && unzip -o publish.zip && rm -f publish.zip && rm -rf merchant \
    && rm -rf runtimes/os* && rm -rf runtimes/win* && rm -rf runtimes/linux-arm runtimes/linux-arm64 runtimes/linux-musl-arm64 runtimes/linux-musl-x64 \
    && touch isdocker

# Скрипт обновления (если нужен при сборке)
RUN curl -k -s https://raw.githubusercontent.com | bash

# Конфиги (твои без изменений)
RUN echo '{"listen":{"port":8000,"scheme":"https","frontend":"cloudflare"},"KnownProxies":[{"ip":"0.0.0.0","prefixLength":0}],"mikrotik":true,"typecache":"mem","GC":{"enable":true,"Concurrent":false,"ConserveMemory":9,"HighMemoryPercent":1,"RetainVM":false},"WAF":{"enable":false,"bypassLocalIP":true,"allowExternalIpAccess":true,"bruteForceProtection":false},"watcherInit":"cron"}' > /home/init.conf
RUN mkdir -p /home/module && echo '"typesearch":"webapi","merge":null' > /home/module/JacRed.conf
RUN echo '[{"enable":true,"dll":"SISI.dll"},{"enable":true,"dll":"Online.dll"},{"enable":true,"initspace":"Catalog.ModInit","dll":"Catalog.dll"},{"enable":true,"initspace":"TorrServer.ModInit","dll":"TorrServer.dll"},{"enable":true,"initspace":"Jackett.ModInit","dll":"JacRed.dll"}]' > /home/module/manifest.json

# Установка TorrServer
RUN mkdir -p torrserver && curl -L -k -o torrserver/TorrServer-linux https://github.com \
    && chmod +x torrserver/TorrServer-linux

# Команда запуска обоих сервисов
# 1. Запуск TorrServer в фоне (&) на порту 8090
# 2. Ожидание 2 сек
# 3. Запуск Lampac основным процессом
ENTRYPOINT /home/torrserver/TorrServer-linux -p 8090 & sleep 2 && /usr/share/dotnet/dotnet Lampac.dll
