# Global ARGs
ARG DOTNET_VERSION=10.0.5
ARG DOTNET_SDK_VERSION=10.0.201

# --- Builder Stage ---
FROM --platform=$BUILDPLATFORM debian:13-slim AS builder
ARG BUILDARCH
ARG TARGETARCH
ARG DOTNET_SDK_VERSION
WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl xz-utils libicu76 git \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/lampac-nextgen/lampac .

RUN case "$BUILDARCH" in \
    arm64) SDK_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-arm64.tar.gz" ;; \
    *) SDK_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-x64.tar.gz" ;; \
    esac \
    && curl -fSL -o /tmp/dotnet-sdk.tar.gz "${SDK_URL}" \
    && mkdir -p /usr/share/dotnet \
    && tar -xzf /tmp/dotnet-sdk.tar.gz -C /usr/share/dotnet \
    && rm /tmp/dotnet-sdk.tar.gz

RUN case "$TARGETARCH" in \
    arm64) RID=linux-arm64 ;; \
    *) RID=linux-x64 ;; \
    esac \
    && /usr/share/dotnet/dotnet publish --configuration Release --runtime "$RID" \
    --output /out/lampac -p:PlaywrightPlatform="$RID" -p:Parallel=false Core/Core.csproj

# --- Runner Stage ---
FROM debian:13-slim AS runner
ARG TARGETARCH
WORKDIR /lampac
EXPOSE 7860

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates chromium curl fontconfig libicu76 libnspr4 libnss3 \
    libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxcomposite1 \
    libxdamage1 libxext6 libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 libasound2 \
    libglib2.0-0 procps socat tini \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN case "$TARGETARCH" in arm64) RID=arm64 ;; *) RID=x64 ;; esac && \
    curl -fSL -o /tmp/rt.tar.gz "https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/10.0.5/aspnetcore-runtime-10.0.5-linux-${RID}.tar.gz" && \
    mkdir -p /usr/share/dotnet && tar -xzf /tmp/rt.tar.gz -C /usr/share/dotnet && rm /tmp/rt.tar.gz

# Переменные для защиты от OOM и настройки путей
ENV PATH="${PATH}:/usr/share/dotnet" \
    DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_GCHeapHardLimit=0x100000000 \
    ASPNETCORE_URLS=http://127.0.0.1:9118 \
    CHROMIUM_PATH=/usr/bin/chromium

COPY --from=builder /out/lampac /lampac
COPY --from=builder /build/Core/wwwroot/. /lampac/wwwroot/
COPY --from=builder /build/Modules/. /lampac/modules/
COPY --from=builder /build/Online/. /lampac/modules/
COPY --from=builder /build/SISI/. /lampac/modules/

RUN rm -rf /lampac/modules/Zetflix* && \
    find /lampac/modules -name "*.js" -exec cp -f {} /lampac/wwwroot/ \;

# Исправлено: Добавлены лимиты памяти для Chromium в args
RUN echo '{"listen":{"port":9118},"server":{"host":"0.0.0.0","allow_cors":true},"cache":{"enable":true},"online":{"enable":true,"proxy":true,"internal":true,"threads":1,"timeout":30},"online_config":{"mikai":{"enable":true,"proxy":true},"videodb":{"enable":true,"proxy":true},"lumen":{"enable":true,"proxy":true},"rezka":{"enable":true,"proxy":true},"spectre":{"enable":true,"proxy":true},"pizdatoehd":{"enable":true,"proxy":true}},"LampaWeb":{"init":true,"base_url":"https://lexa020788-lamposhka.hf.space","online_js":true,"online_external":true,"online_js_main":true,"online_priority":["videodb","pizdatoehd","mikai","spectre","rezka"],"plugins":["/online.js"]},"chromium":{"enable":true,"executablePath":"/usr/bin/chromium","args":["--no-sandbox","--disable-setuid-sandbox","--headless=new","--disable-gpu","--disable-dev-shm-usage","--disable-background-networking","--disable-component-update","--disable-extensions","--mute-audio","--no-zygote","--single-process","--disable-notifications","--disable-popup-blocking","--disable-remote-fonts","--js-flags=--max-old-space-size=512","--disk-cache-size=104857600"]}}' > /lampac/init.conf

RUN mkdir -p /lampac/data /lampac/cache && chmod -R 777 /lampac /tmp

ENTRYPOINT ["/usr/bin/tini", "--"]

# CMD: теперь с wait -n (если один упадет — упадут все, и HF перезагрузит билд)
CMD dotnet Core.dll --urls http://127.0.0.1:9118 & \
    sleep 20 && \
    socat TCP-LISTEN:7860,fork,reuseaddr,keepalive,keepidle=10 TCP:127.0.0.1:9118 & \
    wait -n
