# ... (начало оставляем без изменений до этапа runner) ...
FROM debian:13-slim AS runner
ARG TARGETARCH
WORKDIR /lampac
EXPOSE 8000

# Зависимости
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates chromium curl fontconfig libicu76 libnspr4 unzip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 1. Твои кастомные конфиги (перенесены из старого докера)
RUN mkdir -p /lampac/module
RUN echo '{"listen":{"port":8000,"scheme":"https","frontend":"cloudflare"},"KnownProxies":[{"ip":"0.0.0.0","prefixLength":0}],"mikrotik":true,"typecache":"mem","GC":{"enable":true,"Concurrent":false,"ConserveMemory":9,"HighMemoryPercent":1,"RetainVM":false},"WAF":{"enable":false,"bypassLocalIP":true,"allowExternalIpAccess":true,"bruteForceProtection":false},"watcherInit":"cron","pirate_store":false,"rch":{"keepalive":900},"weblog":{"enable":true},"chromium":{"enable":false},"firefox":{"enable":false},"LampaWeb":{"autoupdate":false,"initPlugins":{"timecode":false,"backup":false,"sync":false}},"cub":{"enable":true,"geo":["RU"]},"tmdb":{"enable":true},"serverproxy":{"verifyip":false,"buffering":{"enable":false},"image":{"cache":false,"cache_rsize":false}},"online":{"checkOnlineSearch":false},"sisi":{"push_all":false,"rsize_disable":["BongaCams","Chaturbate","Runetki","PornHub","Eporner","HQporner","Spankbang","Porntrex","Xnxx","Xvideos","Xhamster","Tizam"],"proxyimg_disable":["Ebalovo"]},"Mirage":{"displayindex":1},"Ashdi":{"rhub":true},"Kinoukr":{"rhub":true},"VDBmovies":{"rhub":true},"VideoDB":{"rhub":true},"FanCDN":{"rhub":true},"Rezka":{"rhub":true,"scheme":"https"},"Kinotochka":{"rhub":true,"rhub_streamproxy":true,"streamproxy":false,"geostreamproxy":null,"rhub_geo_disable":["RU"]},"Videoseed":{"streamproxy":false,"geostreamproxy":null},"Vibix":{"streamproxy":false,"geostreamproxy":null},"iRemux":{"streamproxy":false,"geostreamproxy":null},"Rgshows":{"streamproxy":false,"geostreamproxy":null},"Autoembed":{"enable":false},"Animevost":{"rhub":true},"AnilibriaOnline":{"rhub":true},"Ebalovo":{"rhub":true},"Spankbang":{"rhub":true,"rhub_geo_disable":["RU"]},"BongaCams":{"rhub":true},"Chaturbate":{"rhub":true,"rhub_geo_disable":["RU"]},"Runetki":{"rhub":true},"HQporner":{"rhub":true,"streamproxy":false,"geostreamproxy":null,"qualitys_proxy":false,"geo_hide":["RU"]},"Eporner":{"streamproxy":false,"geostreamproxy":null,"qualitys_proxy":false,"rhub_geo_disable":["RU"]},"Porntrex":{"rhub":true,"streamproxy":false,"geostreamproxy":null,"qualitys_proxy":false,"rhub_geo_disable":["RU"]},"Xhamster":{"rhub":true,"rhub_streamproxy":true,"rhub_fallback":true,"rhub_geo_disable":["RU"]},"Xnxx":{"rhub":true,"rhub_fallback":true,"rhub_streamproxy":true,"rhub_geo_disable":["RU"]},"Tizam":{"rhub":true,"rhub_fallback":true,"streamproxy":false,"geostreamproxy":null,"qualitys_proxy":false},"Xvideos":{"rhub":true,"rhub_streamproxy":true,"rhub_fallback":true,"rhub_geo_disable":["RU"]},"PornHub":{"rhub":true,"rhub_streamproxy":true,"rhub_fallback":true},"RutubeMovie":{"rhub":true,"rhub_streamproxy":true,"rhub_fallback":true,"rhub_geo_disable":["UA"]},"VkMovie":{"rhub":true,"rhub_streamproxy":true,"rhub_fallback":true},"Plvideo":{"rhub":true,"rhub_streamproxy":true,"rhub_fallback":true,"rhub_geo_disable":["UA"]},"CDNvideohub":{"rhub":true,"rhub_streamproxy":true,"rhub_fallback":true},"Redheadsound":{"rhub":true,"rhub_streamproxy":true,"rhub_fallback":true},"CDNmovies":{"rhub":true,"rhub_streamproxy":true,"rhub_fallback":true},"AniMedia":{"rhub":true,"rhub_streamproxy":true,"rhub_fallback":true},"Animebesst":{"rhub":true,"rhub_streamproxy":true,"rhub_fallback":true}}' > /lampac/init.conf
RUN echo '{"typesearch":"webapi","Anilibria":{"enable":true},"RuTracker":{"enable":true},"lostfilm":{"enable":true}}' > /lampac/module/JacRed.conf
RUN echo '[{"enable":true,"dll":"SISI.dll"},{"enable":true,"dll":"Online.dll"},{"enable":true,"initspace":"Catalog.ModInit","dll":"Catalog.dll"},{"enable":true,"initspace":"TorrServer.ModInit","dll":"TorrServer.dll"},{"enable":true,"initspace":"Jackett.ModInit","dll":"JacRed.dll"}]' > /lampac/module/manifest.json

# 2. TorrServer (нужен для работы плагина TorrServer)
RUN mkdir -p /lampac/torrserver && curl -L -k -o /lampac/torrserver/TorrServer-linux https://github.com \
    && chmod +x /lampac/torrserver/TorrServer-linux

# Копируем само приложение из билдера
COPY --from=builder /out /

# Настройка путей и прав
ENV DOTNET_ROOT=/usr/share/dotnet PATH="${PATH}:/usr/share/dotnet"
RUN groupadd -r -g 1000 lampac && useradd -r -u 1000 -g lampac -d /lampac lampac
RUN chown -R lampac:lampac /lampac

USER lampac
ENTRYPOINT ["/usr/share/dotnet/dotnet", "Core.dll"]
