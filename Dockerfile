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
    --output /out/lampac -p:Parallel=false Core/Core.csproj

# --- Runner Stage ---
FROM debian:13-slim AS runner
ARG TARGETARCH
ARG DOTNET_SDK_VERSION
WORKDIR /lampac
EXPOSE 8000

# Устанавливаем минимум для работы (без браузеров)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl libicu76 procps nginx tini \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN case "$TARGETARCH" in arm64) RID=arm64 ;; *) RID=x64 ;; esac && \
    curl -fSL -o /tmp/sdk.tar.gz "https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-${RID}.tar.gz" && \
    mkdir -p /usr/share/dotnet && tar -xzf /tmp/sdk.tar.gz -C /usr/share/dotnet && rm /tmp/sdk.tar.gz

ENV PATH="${PATH}:/usr/share/dotnet" \
    DOTNET_RUNNING_IN_CONTAINER=true \
    ASPNETCORE_URLS=http://127.0.0.1:9118 \
    DOTNET_CLI_HOME=/tmp/dotnet_home

COPY --from=builder /out/lampac /lampac
COPY --from=builder /build/Shared /lampac/shared
COPY --from=builder /build/Online /lampac/online
COPY --from=builder /build/SISI /lampac/sisi
COPY --from=builder /build/Modules /lampac/modules
COPY --from=builder /build/Core/wwwroot /lampac/wwwroot

RUN find /lampac/modules -name "*.js" -exec cp -f {} /lampac/wwwroot/ \; && \
    find /lampac/online -name "*.js" -exec cp -f {} /lampac/wwwroot/ \;

# Настройка Nginx прокси
RUN echo 'server { listen 8000; location / { proxy_pass http://127.0.0.1:9118; proxy_set_header Host $host; proxy_set_header X-Real-IP $remote_addr; } }' > /etc/nginx/sites-available/default

# Создаем конфиг с твоим Jackett (Hugging Face)
RUN echo '{ \
  "jackett": { \
    "enable": true, \
    "host": "https://lexa020788-jaket.hf.space", \
    "key": "s8bfguunqrbgfwend70p8ph5m135helo", \
    "rutor": true, \
    "nnm": true, \
    "kinozal": true, \
    "bitru": true \
  }, \
  "api": { "online": true, "torrent": true } \
}' > /lampac/init.conf

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD service nginx start && dotnet Lampac.dll
