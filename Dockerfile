# Global ARGs
ARG DOTNET_SDK_VERSION=10.0.201

# --- СТАДИЯ СБОРКИ ---
FROM --platform=$BUILDPLATFORM debian:13-slim AS builder
ARG BUILDARCH, TARGETARCH, DOTNET_SDK_VERSION
WORKDIR /build
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl xz-utils libicu76 git \
    && git clone --depth 1 https://github.com/lampac-nextgen/lampac . \
    && SDK_URL=$( [ "$BUILDARCH" = "arm64" ] && echo "https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-arm64.tar.gz" || echo "https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-x64.tar.gz" ) \
    && curl -fSL -o sdk.tar.gz "${SDK_URL}" && mkdir -p /usr/share/dotnet && tar -xzf sdk.tar.gz -C /usr/share/dotnet && rm sdk.tar.gz \
    && RID=$( [ "$TARGETARCH" = "arm64" ] && echo "linux-arm64" || echo "linux-x64" ) \
    && /usr/share/dotnet/dotnet publish --configuration Release --runtime "$RID" --output /out/lampac -p:Parallel=false Core/Core.csproj

# --- СТАДИЯ ЗАПУСКА ---
FROM debian:13-slim AS runner
ARG TARGETARCH, DOTNET_SDK_VERSION
WORKDIR /lampac

# Koyeb по умолчанию любит 8080, но мы оставим 7860 (просто укажи его в панели Koyeb при деплое)
EXPOSE 7860

# ОГРАНИЧЕНИЕ ПАМЯТИ ДЛЯ .NET: чтобы не раздувался на старте
ENV PATH="${PATH}:/usr/share/dotnet" \
    DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_GCHeapHardLimit=1C200000 \
    ASPNETCORE_URLS=http://127.0.0.1:9118 \
    CHROMIUM_PATH=/usr/bin/chromium \
    DOTNET_CLI_HOME=/tmp/dotnet_home

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates chromium curl fontconfig libicu76 libnspr4 libnss3 \
    libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxcomposite1 \
    libxdamage1 libxext6 libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 \
    libasound2 libglib2.0-0 procps nginx tini \
    && RID=$( [ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "x64" ) \
    && curl -fSL -o sdk.tar.gz "https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-${RID}.tar.gz" \
    && mkdir -p /usr/share/dotnet && tar -xzf sdk.tar.gz -C /usr/share/dotnet && rm sdk.tar.gz \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /out/lampac /lampac
COPY --from=builder /build/Shared /lampac/shared
COPY --from=builder /build/Online /lampac/online
COPY --from=builder /build/SISI /lampac/sisi
COPY --from=builder /build/Modules /lampac/modules
COPY --from=builder /build/Core/wwwroot /lampac/wwwroot

RUN find /lampac/modules -name "*.js" -exec cp -f {} /lampac/wwwroot/ \; \
    && find /lampac/online -name "*.js" -exec cp -f {} /lampac/wwwroot/ \; \
    && echo 'server { \
        listen 7860; \
        server_tokens off; \
        location / { \
            proxy_pass http://127.0.0.1:9118; \
            proxy_http_version 1.1; \
            proxy_set_header Upgrade $http_upgrade; \
            proxy_set_header Connection "upgrade"; \
            proxy_set_header Host $host; \
            proxy_set_header X-Forwarded-Proto $scheme; \
            proxy_read_timeout 120s; \
        } \
    }' > /etc/nginx/sites-available/default \
    # ИСПРАВЛЕННЫЙ init.conf для Koyeb (Base_URL пустой, чтобы подхватил домен автоматически)
    && echo '{"listen":{"port":9118},"server":{"host":"127.0.0.1","allow_cors":true},"cache":{"enable":true,"path":"/tmp/cache"},"tmdb":{"enable":true,"proxy":true,"api_key":"4ef0d735117c451680108888591f391d"},"LampaWeb":{"init":true,"base_url"https://lampohka.koyeb.app/"","api_url"https://lampohka.koyeb.app"","online_js":true,"online_priority":["VideoDB","Rezka","Collaps"],"plugins":["/online.js","/sisi.js"]},"chromium":{"enable":true,"semaphore":1,"executablePath":"/usr/bin/chromium","args":["--no-sandbox","--headless=new","--disable-gpu","--disable-dev-shm-usage","--no-zygote","--single-process","--js-flags=\"--max-old-space-size=96 --stack-size=512\""]}}' > /lampac/init.conf \
    && mkdir -p /lampac/system /lampac/system/config \
    && echo '{"TmdbProxy":{"enable":true,"proxy":true},"CubProxy":{"enable":true,"proxy":true},"VideoDB":{"enable":true,"proxy":true,"useproxy":true},"Rezka":{"enable":true,"proxy":true,"useproxy":true},"Collaps":{"enable":true,"proxy":true,"useproxy":true}}' > /lampac/accs.json \
    && cp /lampac/accs.json /lampac/system/accs.json && cp /lampac/accs.json /lampac/system/config/accs.json \
    && mkdir -p /lampac/data /lampac/cache /run/nginx && chmod -R 777 /lampac /tmp /var/lib/nginx /var/log/nginx /run/nginx

RUN echo '#!/bin/bash\n\
nginx\n\
sleep 2\n\
exec dotnet /lampac/Core.dll --urls http://127.0.0.1:9118' > /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash", "/entrypoint.sh"]
