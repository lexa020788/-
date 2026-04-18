# Global ARGs
ARG DOTNET_VERSION=9.0.0
ARG DOTNET_SDK_VERSION=9.0.100

# --- Builder Stage ---
FROM debian:13-slim AS builder
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
    && mkdir -p /out/usr/share/dotnet \
    && tar -xzf /tmp/dotnet-sdk.tar.gz -C /out/usr/share/dotnet \
    && rm /tmp/dotnet-sdk.tar.gz

RUN case "$TARGETARCH" in \
    arm64) RID=linux-arm64 ;; \
    *) RID=linux-x64 ;; \
    esac \
    && /out/usr/share/dotnet/dotnet publish Core/Core.csproj --configuration Release --runtime "$RID" \
    --output /out/lampac -p:PlaywrightPlatform="$RID" -p:Parallel=false \
    -p:TargetFramework=net9.0 --self-contained false

# --- Runner Stage ---
FROM debian:13-slim AS runner
ARG TARGETARCH
WORKDIR /lampac
EXPOSE 9118

# Добавляем переменные как у разработчика (это ВАЖНО для Chromium)
ENV DOTNET_GCHeapHardLimit=300000000 \
    DOTNET_ROOT=/usr/share/dotnet \
    PATH="${PATH}:/usr/share/dotnet" \
    ASPNETCORE_URLS=http://0.0.0 \
    DOTNET_RUNNING_IN_CONTAINER=true \
    CHROMIUM_PATH=/usr/bin/chromium \
    CHROMIUM_FLAGS="--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage --disable-gpu --single-process"

# Установка зависимостей (добавь libnss3 и libgbm1 — без них Хром на Debian 13 не заведется!)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates chromium curl fontconfig libicu76 libnspr4 libnss3 libgbm1 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Копируем приложение (БЕЗ --chown=lampac, работаем от ROOT)
COPY --from=builder /out /

# Установка Runtime (твоя рабочая схема)
RUN case "$TARGETARCH" in \
    arm64) RID=arm64 ;; \
    *) RID=x64 ;; \
    esac \
    && DOTNET_RUNTIME_URL="https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/10.0.0/aspnetcore-runtime-10.0.0-linux-${RID}.tar.gz" \
    && curl -fSL -o /tmp/dotnet-runtime.tar.gz "${DOTNET_RUNTIME_URL}" \
    && mkdir -p /usr/share/dotnet \
    && tar -xzf /tmp/dotnet-runtime.tar.gz -C /usr/share/dotnet \
    && rm /tmp/dotnet-runtime.tar.gz

WORKDIR /lampac

RUN mkdir -p /lampac/data /lampac/module /lampac/wwwroot

# Создаем конфиг с разрешением внешнего доступа и путем к хрому
RUN echo '{ \
  "listen": {"port": 9118, "KnownProxies": [{"ip": "0.0.0.0", "prefixLength": 0}]}, \
  "chromium": {"enable": true, "binary": "/usr/bin/chromium", "args": ["--no-sandbox", "--disable-setuid-sandbox"]}, \
  "WAF": {"allowExternalIpAccess": true}, \
  "GC": {"Concurrent": true, "HighMemoryPercent": 95} \
}' > /lampac/init.conf

# Права и метка докера
RUN chmod +x /usr/bin/chromium && touch /lampac/isdocker

# Запуск с полным путем
ENTRYPOINT ["/usr/share/dotnet/dotnet", "Core.dll", "--urls", "http://0.0.0.0:9118"]
