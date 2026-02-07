FROM debian:12.5-slim

EXPOSE 8000
WORKDIR /home

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip libicu-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN curl -fSL -k -o dotnet.tar.gz https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/9.0.12/aspnetcore-runtime-9.0.12-linux-x64.tar.gz \
    && mkdir -p /usr/share/dotnet \
    && tar -oxzf dotnet.tar.gz -C /usr/share/dotnet \
    && rm dotnet.tar.gz

RUN curl -L -k -o publish.zip https://github.com/lampac-talks/lampac/releases/latest/download/publish.zip \
    && unzip -o publish.zip && rm -f publish.zip && rm -rf merchant \
    && rm -rf runtimes/os* && rm -rf runtimes/win* && rm -rf runtimes/linux-arm runtimes/linux-arm64 runtimes/linux-musl-arm64 runtimes/linux-musl-x64 \
    && touch isdocker

RUN curl -k -s https://raw.githubusercontent.com/lampac-talks/lampac/main/Build/Docker/update.sh | bash

# Основной конфиг
RUN echo '{"jackett_host":"https://lampohka.koyeb.app","listen":{"port":8000,"scheme":"http","frontend":"cloudflare"},"KnownProxies":[{"ip":"0.0.0.0","prefixLength":0}],"mikrotik":true,"typecache":"mem","GC":{"enable":true,"Concurrent":false,"ConserveMemory":9,"HighMemoryPercent":1,"RetainVM":false},"WAF":{"enable":false,"bypassLocalIP":true,"allowExternalIpAccess":true,"bruteForceProtection":false},"watcherInit":"cron","pirate_store":false,"rch":{"keepalive":900},"weblog":{"enable":true},"LampaWeb":{"autoupdate":false,"initPlugins":{"timecode":false,"backup":false,"sync":false}},"cub":{"enable":true,"geo":["RU"]},"tmdb":{"enable":true},"serverproxy":{"verifyip":false,"buffering":{"enable":false},"image":{"cache":false,"cache_rsize":false}},"online":{"checkOnlineSearch":false},"sisi":{"push_all":false,"rsize_disable":["BongaCams","Chaturbate","Runetki","PornHub","Eporner","HQporner","Spankbang","Porntrex","Xnxx","Xvideos","Xhamster","Tizam"]},"Mirage":{"displayindex":1},"Ashdi":{"rhub":true},"Kinoukr":{"rhub":true},"VDBmovies":{"rhub":true},"VideoDB":{"rhub":true},"FanCDN":{"rhub":true},"Rezka":{"rhub":true,"scheme":"https"},"Kinotochka":{"rhub":true,"rhub_streamproxy":true},"Animevost":{"rhub":true},"AnilibriaOnline":{"rhub":true},"Ebalovo":{"rhub":true},"Spankbang":{"rhub":true},"BongaCams":{"rhub":true},"Chaturbate":{"rhub":true},"Runetki":{"rhub":true},"HQporner":{"rhub":true},"Eporner":{"rhub":true},"Porntrex":{"rhub":true},"Xhamster":{"rhub":true},"Xnxx":{"rhub":true},"Tizam":{"rhub":true},"Xvideos":{"rhub":true},"PornHub":{"rhub":true},"RutubeMovie":{"rhub":true},"VkMovie":{"rhub":true},"Plvideo":{"rhub":true},"CDNvideohub":{"rhub":true},"Redheadsound":{"rhub":true},"CDNmovies":{"rhub":true},"AniMedia":{"rhub":true},"Animebesst":{"rhub":true}}' > /home/init.conf

# Конфиг парсера (Исправлено!)
RUN echo '{"host":"https://lampohka.koyeb.app","typesearch":"webapi","merge":null}' > /home/module/JacRed.conf

# Список модулей
RUN echo '[{"enable":true,"dll":"SISI.dll"},{"enable":true,"dll":"Online.dll"},{"enable":true,"initspace":"Catalog.ModInit","dll":"Catalog.dll"},{"enable":true,"initspace":"TorrServer.ModInit","dll":"TorrServer.dll"},{"enable":true,"initspace":"Jackett.ModInit","dll":"JacRed.dll"}]' > /home/module/manifest.json

RUN mkdir -p torrserver && curl -L -k -o torrserver/TorrServer-linux https://github.com/YouROK/TorrServer/releases/latest/download/TorrServer-linux-amd64 \
    && chmod +x torrserver/TorrServer-linux

ENTRYPOINT ["/usr/share/dotnet/dotnet", "Lampac.dll"]
