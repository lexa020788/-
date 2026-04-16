ARG DOTNET_VERSION=9.0.2

# --- СТАДИЯ 1: Builder ---
FROM --platform=$BUILDPLATFORM debian:12-slim AS builder
ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip && rm -rf /var/lib/apt/lists/*

WORKDIR /out

# ТУТ ИСПРАВЛЕНО (ссылка полная):
RUN curl -L -o publish.zip https://github.com \
    && unzip -o publish.zip -d /out && rm publish.zip \
    && rm -rf /out/merchant /out/runtimes/os* /out/runtimes/win* /out/runtimes/linux-arm /out/runtimes/linux-musl* \
    && touch /out/isdocker

RUN mkdir -p /out/torrserver \
    && if [ "$TARGETARCH" = "arm64" ]; then TS_ARCH="arm64"; else TS_ARCH="amd64"; fi \
    && curl -L -o /out/torrserver/TorrServer-linux "https://github.com${TS_ARCH}" \
    && chmod +x /out/torrserver/TorrServer-linux

# --- СТАДИЯ 2: Runner ---
FROM debian:12-slim AS runner
WORKDIR /home
ARG TARGETARCH
ARG DOTNET_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl chromium libicu72 procps libfontconfig1 fonts-liberation \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN if [ "$TARGETARCH" = "arm64" ]; then DOTNET_ARCH="arm64"; else DOTNET_ARCH="x64"; fi \
    && curl -fSL -o dotnet.tar.gz "https://microsoft.com${DOTNET_VERSION}/aspnetcore-runtime-${DOTNET_VERSION}-linux-${DOTNET_ARCH}.tar.gz" \
    && mkdir -p /usr/share/dotnet && tar -oxzf dotnet.tar.gz -C /usr/share/dotnet && rm dotnet.tar.gz

ENV DOTNET_ROOT=/usr/share/dotnet \
    PATH="${PATH}:/usr/share/dotnet" \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    CHROMIUM_PATH=/usr/bin/chromium \
    CHROMIUM_FLAGS="--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage --disable-gpu"

COPY --from=builder /out /home/

RUN mkdir -p /home/module && \
    echo '{"listen":{"port":8000,"scheme":"https","frontend":"cloudflare"},"KnownProxies":[{"ip":"0.0.0.0","prefixLength":0}],"mikrotik":true,"typecache":"mem","GC":{"enable":true,"Concurrent":false,"ConserveMemory":9,"HighMemoryPercent":1,"RetainVM":false},"WAF":{"enable":false,"bypassLocalIP":true,"allowExternalIpAccess":true,"bruteForceProtection":false},"watcherInit":"cron","pirate_store":false,"rch":{"keepalive":900},"weblog":{"enable":true},"chromium":{"enable":true,"path":"/usr/bin/chromium"},"LampaWeb":{"autoupdate":false,"initPlugins":{"timecode":false,"backup":false,"sync":false}},"cub":{"enable":true,"geo":["RU"]},"tmdb":{"enable":true},"online":{"checkOnlineSearch":false},"sisi":{"push_all":false,"rsize_disable":["BongaCams","Chaturbate","Runetki","PornHub","Eporner","HQporner","Spankbang","Porntrex","Xnxx","Xvideos","Xhamster","Tizam"]},"Rezka":{"rhub":true,"scheme":"https"}}' > /home/init.conf && \
    echo '{"typesearch":"webapi","Anilibria":{"enable":true},"RuTracker":{"enable":true},"lostfilm":{"enable":true}}' > /home/module/JacRed.conf && \
    echo '[{"enable":true,"dll":"SISI.dll"},{"enable":true,"dll":"Online.dll"},{"enable":true,"initspace":"Catalog.ModInit","dll":"Catalog.dll"},{"enable":true,"initspace":"TorrServer.ModInit","dll":"TorrServer.dll"},{"enable":true,"initspace":"Jackett.ModInit","dll":"JacRed.dll"}]' > /home/module/manifest.json

RUN curl -s https://githubusercontent.com | bash

EXPOSE 8000
ENTRYPOINT ["dotnet", "Lampac.dll"]
