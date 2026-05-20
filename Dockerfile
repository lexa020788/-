# Global ARGs
ARG DOTNET_VERSION=10.0.5
ARG DOTNET_SDK_VERSION=10.0.201

# --- Builder Stage ---
FROM --platform=$BUILDPLATFORM debian:13-slim AS builder
ARG BUILDARCH
ARG TARGETARCH
ARG DOTNET_SDK_VERSION
WORKDIR /build
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl xz-utils libicu76 git && rm -rf /var/lib/apt/lists/*
RUN git clone https://github.com/lampac-nextgen/lampac .
RUN case "$BUILDARCH" in arm64) SDK_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-arm64.tar.gz" ;; *) SDK_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-x64.tar.gz" ;; esac && curl -fSL -o /tmp/dotnet-sdk.tar.gz "${SDK_URL}" && mkdir -p /usr/share/dotnet && tar -xzf /tmp/dotnet-sdk.tar.gz -C /usr/share/dotnet && rm /tmp/dotnet-sdk.tar.gz
RUN case "$TARGETARCH" in arm64) RID=linux-arm64 ;; *) RID=linux-x64 ;; esac && /usr/share/dotnet/dotnet publish --configuration Release --runtime "$RID" --output /out/lampac -p:Parallel=false Core/Core.csproj

# --- Runner Stage ---
FROM debian:13-slim AS runner
ARG TARGETARCH
ARG DOTNET_SDK_VERSION
WORKDIR /lampac
EXPOSE 7860
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates chromium curl fontconfig libicu76 procps nginx tini \
    libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
    libxcomposite1 libxdamage1 libxext6 libxfixes3 libxrandr2 libgbm1 \
    libpango-1.0-0 libasound2 libglib2.0-0 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN case "$TARGETARCH" in arm64) RID=arm64 ;; *) RID=x64 ;; esac && \
    curl -fSL -o /tmp/sdk.tar.gz "https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-${RID}.tar.gz" && \
    mkdir -p /usr/share/dotnet && tar -xzf /tmp/sdk.tar.gz -C /usr/share/dotnet && rm /tmp/sdk.tar.gz

ENV PATH="${PATH}:/usr/share/dotnet" \
    DOTNET_RUNNING_IN_CONTAINER=true \
    ASPNETCORE_URLS=http://127.0.0.1:9118 \
    DOTNET_GCHeapHardLimit=1C2000000 \
    DOTNET_CLI_HOME=/tmp/dotnet_home

COPY --from=builder /out/lampac /lampac
COPY --from=builder /build/Shared /lampac/shared
COPY --from=builder /build/Online /lampac/online
COPY --from=builder /build/SISI /lampac/sisi
COPY --from=builder /build/Modules /lampac/modules
COPY --from=builder /build/Core/wwwroot /lampac/wwwroot

RUN find /lampac/modules -name "*.js" -exec cp -f {} /lampac/wwwroot/ \; && \
    find /lampac/online -name "*.js" -exec cp -f {} /lampac/wwwroot/ \;

# ИСПРАВЛЕНО: Добавлены заголовки проксирования для бесперебойной работы за прокси HF
RUN echo 'server { \
    listen 7860; \
    location / { \
        proxy_pass http://127.0.0.1:9118; \
        proxy_http_version 1.1; \
        proxy_set_header Upgrade $http_upgrade; \
        proxy_set_header Connection "upgrade"; \
        proxy_set_header Host $host; \
        proxy_set_header X-Real-IP $remote_addr; \
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; \
        proxy_set_header X-Forwarded-Proto $scheme; \
    } \
}' > /etc/nginx/sites-available/default

# ИСПРАВЛЕНО: base_url и api_url изменены со статического домена на универсальный относительный путь /proxy/7860/
RUN echo '{ \
  "listen": {"port": 9118}, \
  "server": {"host": "0.0.0.0", "allow_cors": true}, \
  "auth": {"token": "TOKEN_PLACEHOLDER"}, \
  "cache": {"enable": true, "path": "/tmp/cache"}, \
  "lowMemoryMode": false, \
  "tmdb": { "enable": true, "proxy": true, "api_key": "4ef0d735117c451680108888591f391d" }, \
  "LampaWeb": { \
    "init": true, \
    "base_url": "/proxy/7860/", \
    "api_url": "/proxy/7860/" \
  }, \
  "chromium": { \
    "enable": true, \
    "puppets": true, \
    "timeout": 180000, \
    "executablePath": "/usr/bin/chromium", \
    "max_processes": 0, \
    "diskCacheSize": 0, \
    "memoryCacheSize": 0, \
    "args": [ \
      "--no-sandbox", \
      "--disable-setuid-sandbox", \
      "--headless=new", \
      "--disable-gpu", \
      "--disable-dev-shm-usage", \
      "--no-first-run", \
      "--no-default-browser-check" \
    ] \
  } \
}' > /lampac/init.conf

RUN mkdir -p /lampac/system /lampac/system/config && \
    echo '{ \
      "VideoDB": {"enable": true, "proxy": true, "use_chromium": true}, \
      "VDB": {"enable": true, "proxy": true, "use_chromium": true}, \
      "vdb": {"enable": true, "proxy": true, "use_chromium": true}, \
      "PizdatoeHD": {"enable": true, "proxy": true, "use_chromium": true}, \
      "pizdatoehd": {"enable": true, "proxy": true, "use_chromium": true}, \
      "Rezka": {"enable": true, "proxy": true, "use_chromium": true}, \
      "Kinogo": {"enable": true, "proxy": true, "use_chromium": true}, \
      "Kinobase": {"enable": true, "proxy": true, "use_chromium": true}, \
      "Collaps": {"enable": true, "proxy": true, "use_chromium": true}, \
      "HDVB": {"enable": true, "proxy": true, "use_chromium": true}, \
      "Alloha": {"enable": true, "proxy": true, "use_chromium": true} \
    }' > /lampac/system/accs.json && \
    cp /lampac/system/accs.json /lampac/system/config/accs.json

RUN mkdir -p /lampac/data /lampac/cache /run/nginx /tmp/dotnet_home && chmod -R 777 /lampac /tmp /var/lib/nginx /var/log/nginx /run/nginx

RUN echo '#!/bin/bash\n\
nginx &\n\
if [ ! -z "${LAMPAC_TOKEN}" ]; then\n\
  sed -i "s/TOKEN_PLACEHOLDER/${LAMPAC_TOKEN}/g" /lampac/init.conf\n\
fi\n\
export DOTNET_GCHeapHardLimit=1C2000000\n\
exec dotnet Core.dll --urls http://127.0.0.1:9118' > /lampac/entrypoint.sh && \
chmod +x /lampac/entrypoint.sh

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/lampac/entrypoint.sh"]
