FROM debian:12.5-slim

EXPOSE 8000
WORKDIR /home

# 1. Установка системных зависимостей
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip libicu-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. Установка .NET Runtime 9.0
RUN curl -fSL -o dotnet.tar.gz https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/9.0.12/aspnetcore-runtime-9.0.12-linux-x64.tar.gz \
    && mkdir -p /usr/share/dotnet \
    && tar -oxzf dotnet.tar.gz -C /usr/share/dotnet \
    && rm dotnet.tar.gz

# 3. Скачивание Lampac (используем стабильную ссылку на ветку main)
RUN curl -L -H "User-Agent: Mozilla/5.0" -o publish.zip https://github.com \
    && unzip -o publish.zip \
    && mv lampac-main/* ./ \
    && rm -rf lampac-main publish.zip merchant \
    && rm -rf runtimes/os* runtimes/win* runtimes/linux-arm* runtimes/linux-musl* \
    && touch isdocker

# 4. Обновление через скрипт автора
RUN curl -s https://raw.githubusercontent.com/lampac-talks/lampac/main/Build/Docker/update.sh | bash || true

# 5. Создание конфигов (добавлен mkdir для module)
RUN echo '{"listen":{"port":8000,"scheme":"https","frontend":"cloudflare"},"KnownProxies":[{"ip":"0.0.0.0","prefixLength":0}],"mikrotik":true,"typecache":"mem","GC":{"enable":true,"Concurrent":false,"ConserveMemory":9,"HighMemoryPercent":1,"RetainVM":false},"WAF":{"enable":false,"bypassLocalIP":true,"allowExternalIpAccess":true,"bruteForceProtection":false},"watcherInit":"cron","pirate_store":false,"rch":{"keepalive":900},"weblog":{"enable":true},"chromium":{"enable":false},"firefox":{"enable":false},"LampaWeb":{"autoupdate":false,"initPlugins":{"timecode":false,"backup":false,"sync":false}},"cub":{"enable":true,"geo":["RU"]},"tmdb":{"enable":true},"serverproxy":{"verifyip":false,"buffering":{"enable":false},"image":{"cache":false,"cache_rsize":false}},"online":{"checkOnlineSearch":false},"sisi":{"push_all":false,"rsize_disable":["BongaCams","Chaturbate","Runetki","PornHub","Eporner","HQporner","Spankbang","Porntrex","Xnxx","Xvideos","Xhamster","Tizam"],"proxyimg_disable":["Ebalovo"]},"Mirage":{"displayindex":1},"Ashdi":{"rhub":true},"Kinoukr":{"rhub":true},"VDBmovies":{"rhub":true},"VideoDB":{"rhub":true},"FanCDN":{"rhub":true},"Rezka":{"rhub":true,"scheme":"https"},"Kinotochka":{"rhub":true,"rhub_streamproxy":true,"streamproxy":false,"geostreamproxy":null,"rhub_geo_disable":["RU"]},"Videoseed":{"streamproxy":false,"geostreamproxy":null},"Vibix":{"streamproxy":false,"geostreamproxy":null},"iRemux":{"streamproxy":false,"geostreamproxy":null},"Rgshows":{"streamproxy":false,"geostreamproxy":null},"Autoembed":{"enable":false},"Animevost":{"rhub":true},"AnilibriaOnline":{"rhub":true},"Ebalovo":{"rhub":true},"Spankbang":{"rhub":true,"rhub_geo_disable":["RU"]},"BongaCams":{"rhub":true},"Chaturbate":{"rhub":true,"rhub_geo_disable":["RU"]},"Runetki":{"rhub":true},"HQporner":{"rhub":true,"streamproxy":false,"geostreamproxy":null,"qualitys_proxy":false,"geo_hide":["RU"]},"Eporner":{"streamproxy":false,"geostreamproxy":null,"qualitys_proxy":false,"rhub_geo_disable":["RU"]},"Porntrex":{"rhub":true,"streamproxy":false,"geostreamproxy":null,"qualitys_proxy":false,"rhub_geo_disable":["RU"]},"Xhamster":{"rhub":true,"rhub_streamproxy":true,"rhub_fallback":true,"rhub_geo_disable":["RU"]},"Xnxx":{"rhub":true,"rhub_fallback":true,"rhub_streamproxy":true,"rhub_geo_disable":["RU"]},"Tizam":{"rhub":true,"rhub_fallback":true,"streamproxy":false,"geostreamproxy":null,"qualitys_proxy":false},"Xvideos":{"rhub":true,"rhub_streamproxy":true,"rhub_fallback":true,"rhub_geo_disable":["RU"]},"PornHub":{"rhub":true,"rhub_streamproxy":true,"rhub_fallback":true},"RutubeMovie":{"rhub":true,"rhub_streamproxy":true,"rhub_fallback":true,"rhub_geo_disable":["UA"]},"VkMovie":{"rhub":true,"rhub_streamproxy":true,"rhub_fallback":true},"Plvideo":{"rhub":true,"rhub_streamproxy":true,"rhub_fallback":true,"rhub_geo_disable":["UA"]},"CDNvideohub":{"rhub":true,"rhub_streamproxy":true,"rhub_fallback":true},"Redheadsound":{"rhub":true,"rhub_streamproxy":true,"rhub_fallback":true},"CDNmovies":{"rhub":true,"rhub_streamproxy":true,"rhub_fallback":true},"AniMedia":{"rhub":true,"rhub_streamproxy":true,"rhub_fallback":true},"Animebesst":{"rhub":true,"rhub_streamproxy":true,"rhub_fallback":true}}' > /home/init.conf \
    && mkdir -p /home/module \
    && echo '"typesearch":"webapi","merge":null' > /home/module/JacRed.conf \
    && echo '[{"enable":true,"dll":"SISI.dll"},{"enable":true,"dll":"Online.dll"},{"enable":true,"initspace":"Catalog.ModInit","dll":"Catalog.dll"},{"enable":true,"initspace":"TorrServer.ModInit","dll":"TorrServer.dll"},{"enable":true,"initspace":"Jackett.ModInit","dll":"JacRed.dll"}]' > /home/module/manifest.json

# 6. Установка TorrServer
RUN mkdir -p torrserver && \
    curl -L -H "User-Agent: Mozilla/5.0" -o torrserver/TorrServer-linux https://github.com/YouROK/TorrServer/releases/latest/download/TorrServer-linux-amd64 && \
    chmod +x torrserver/TorrServer-linux

# 7. Скрипт запуска для обоих сервисов
RUN echo '#!/bin/bash\n\
./torrserver/TorrServer-linux & \n\
sleep 2\n\
exec /usr/share/dotnet/dotnet Lampac.dll --urls http://0.0.0' > /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
