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
    arm64) SDK_URL="https://microsoft.com{DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-arm64.tar.gz" ;; \
    *) SDK_URL="https://microsoft.com{DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-x64.tar.gz" ;; \
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

# Ставим пакеты (полный хром)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates chromium curl fontconfig libicu76 libnspr4 libnss3 \
    libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxcomposite1 \
    libxdamage1 libxext6 libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 libasound2 \
    libglib2.0-0 libxshmfence1 libx11-xcb1 libxcb-dri3-0 libxss1 \
    procps nginx tini \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN case "$TARGETARCH" in arm64) RID=arm64 ;; *) RID=x64 ;; esac && \
    curl -fSL -o /tmp/rt.tar.gz "https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/10.0.5/aspnetcore-runtime-10.0.5-linux-${RID}.tar.gz" && \
    mkdir -p /usr/share/dotnet && tar -xzf /tmp/rt.tar.gz -C /usr/share/dotnet && rm /tmp/rt.tar.gz

ENV PATH="${PATH}:/usr/share/dotnet" \
    DOTNET_RUNNING_IN_CONTAINER=true \
    ASPNETCORE_URLS=http://127.0.0.1:9118 \
    CHROMIUM_PATH=/usr/bin/chromium

COPY --from=builder /out/lampac /lampac
COPY --from=builder /build/Core/wwwroot/. /lampac/wwwroot/
COPY --from=builder /build/Modules/OnlineRUS/. /lampac/modules/
COPY --from=builder /build/SISI/. /lampac/modules/

# Исправлено: добавлен \; в конце find
RUN rm -rf /lampac/modules/Zetflix* && \
    find /lampac/modules -name "*.js" -exec cp -f {} /lampac/wwwroot/ \;

RUN echo 'server { \
    listen 7860; \
    location / { \
        proxy_pass http://127.0.0.1:9118; \
        proxy_http_version 1.1; \
        proxy_set_header Upgrade $http_upgrade; \
        proxy_set_header Connection "upgrade"; \
        proxy_set_header Host $host; \
        proxy_cache_bypass $http_upgrade; \
    } \
}' > /etc/nginx/sites-available/default

RUN echo '{"listen":{"port":9118},"server":{"host":"0.0.0.0","allow_cors":true},"cache":{"enable":true},"online":{"enable":true,"proxy":false,"internal":false,"threads":1,"timeout":40},"online_config":{"mikai":{"enable":true,"proxy":false},"videodb":{"enable":true,"proxy":false},"lumen":{"enable":true,"proxy":false},"rezka":{"enable":true,"proxy":false},"spectre":{"enable":true,"proxy":false},"pizdatoehd":{"enable":true,"proxy":false}},"LampaWeb":{"init":true,"base_url":"https://lexa020788-lampac.hf.space","online_js":true,"online_external":true,"online_js_main":true,"online_priority":["videodb","rezka","pizdatoehd","spectre"],"plugins":["/online.js"]},"chromium":{"enable":true,"executablePath":"/usr/bin/chromium","args":["--no-sandbox","--disable-setuid-sandbox","--headless=new","--disable-gpu","--disable-dev-shm-usage","--disable-background-networking","--no-zygote","--disable-notifications"]}}' > /lampac/init.conf

# Права: HF требует доступа к /var/lib/nginx и логам
RUN mkdir -p /lampac/data /lampac/cache /run/nginx /var/lib/nginx /var/log/nginx && \
    chmod -R 777 /lampac /tmp /var/lib/nginx /var/log/nginx /run/nginx

ENTRYPOINT ["/usr/bin/tini", "--"]

# Запуск: Nginx в фоне, Dotnet основным процессом (если dotnet упадет - контейнер рестартнет)
CMD nginx && dotnet Core.dll --urls http://127.0.0.1:9118
