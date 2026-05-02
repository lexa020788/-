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
RUN git clone --depth 1 https://github.com/lampac-nextgen/lampac .
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

# --- НОВЫЕ ЛИМИТЫ CPU И RAM ---
ENV PATH="${PATH}:/usr/share/dotnet" \
    DOTNET_RUNNING_IN_CONTAINER=true \
    ASPNETCORE_URLS=http://127.0.0.1:9118 \
    DOTNET_CLI_HOME=/tmp/dotnet_home \
    # ЖЕСТКОЕ ОГРАНИЧЕНИЕ: 1 ядро и 256МБ ОЗУ для .NET
    DOTNET_ProcessorCount=1 \
    COMPlus_GCThreadCount=1 \
    DOTNET_GCHeapHardLimit=268435456 \
    DOTNET_TieredCompilation=0

COPY --from=builder /out/lampac /lampac
COPY --from=builder /build/Shared /lampac/shared
COPY --from=builder /build/Online /lampac/online
COPY --from=builder /build/SISI /lampac/sisi
COPY --from=builder /build/Modules /lampac/modules
COPY --from=builder /build/Core/wwwroot /lampac/wwwroot

RUN find /lampac/modules -name "*.js" -exec cp -f {} /lampac/wwwroot/ \; && \
    find /lampac/online -name "*.js" -exec cp -f {} /lampac/wwwroot/ \;

RUN echo 'server { listen 7860; location / { proxy_pass http://127.0.0.1:9118; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host $host; } }' > /etc/nginx/sites-available/default

# Оптимизированный конфиг: Chromium зажат в 1 поток
RUN echo '{ \
"listen": {"port": 9118}, \
"lowMemoryMode": true, \
"tmdb": { "enable": true, "proxy": true, "api_key": "4ef0d735117c451680108888591f391d" }, \
"LampaWeb": { \
  "init": true, \
  "base_url": "https://lexa020788-lamposhka.hf.space", \
  "api_url": "https://lexa020788-lamposhka.hf.space" \
}, \
"chromium": { \
  "enable": true, \
  "executablePath": "/usr/bin/chromium", \
  "max_processes": 1, \
  "args": [ \
    "--no-sandbox","--disable-setuid-sandbox","--headless=new","--disable-gpu", \
    "--disable-dev-shm-usage","--no-zygote","--single-process", \
    "--disable-features=IsolateOrigins,site-per-process", \
    "--disable-software-rasterizer","--disable-background-networking", \
    "--js-flags=\"--max-old-space-size=128\"" \
  ] \
} \
}' > /lampac/init.conf

RUN mkdir -p /lampac/system /lampac/system/config && \
echo '{ \
"VideoDB": {"enable": true, "proxy": true, "use_chromium": false}, \
"Rezka": {"enable": true, "proxy": true, "use_chromium": true}, \
"Kinogo": {"enable": true, "proxy": true, "use_chromium": false}, \
"Kinobase": {"enable": true, "proxy": true, "use_chromium": false}, \
"Collaps": {"enable": true, "proxy": true}, \
"HDVB": {"enable": true, "proxy": true}, \
"Alloha": {"enable": true, "proxy": true} \
}' > /lampac/system/accs.json && \
cp /lampac/system/accs.json /lampac/system/config/accs.json

RUN mkdir -p /lampac/data /lampac/cache /run/nginx /tmp/dotnet_home && chmod -R 777 /lampac /tmp /var/lib/nginx /var/log/nginx /run/nginx

ENTRYPOINT ["/usr/bin/tini", "--"]
# Запуск с низким приоритетом (nice), чтобы не пугать мониторинг Hugging Face
CMD service nginx start && exec nice -n 19 /usr/share/dotnet/dotnet /lampac/Core.dll --urls http://127.0.0.1:9118
