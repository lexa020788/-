# Global ARGs
ARG DOTNET_VERSION=10.0.0
ARG DOTNET_SDK_VERSION=10.0.201

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
    && /out/usr/share/dotnet/dotnet publish --configuration Release --runtime "$RID" \
    --output /out/lampac -p:PlaywrightPlatform="$RID" -p:Parallel=false Core/Core.csproj

# --- Часть 1: Сборка (Builder) ---
FROM debian:13-slim AS builder
WORKDIR /build

# Устанавливаем инструменты для сборки
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl xz-utils libicu76 git \
    && rm -rf /var/lib/apt/lists/*

# Клонируем исходники Lampac
RUN git clone https://github.com .

# Скачиваем .NET SDK для сборки
RUN SDK_URL="https://microsoft.com" \
    && curl -fSL -o /tmp/dotnet-sdk.tar.gz "${SDK_URL}" \
    && mkdir -p /usr/share/dotnet \
    && tar -xzf /tmp/dotnet-sdk.tar.gz -C /usr/share/dotnet \
    && rm /tmp/dotnet-sdk.tar.gz

# Собираем приложение
RUN /usr/share/dotnet/dotnet publish --configuration Release --runtime linux-x64 \
    --output /out/lampac -p:PlaywrightPlatform="linux-x64" -p:Parallel=false Core/Core.csproj

# --- Часть 2: Запуск (Runner) ---
FROM debian:13-slim AS runner
WORKDIR /lampac
EXPOSE 9118

# Устанавливаем Chromium и библиотеки (от Root)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates chromium curl fontconfig libicu76 libnspr4 libnss3 \
    libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxcomposite1 \
    libxdamage1 libxext6 libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 libasound2 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Копируем .NET Runtime прямо из официального источника (надежнее)
RUN curl -fSL -o /tmp/dotnet-runtime.tar.gz https://microsoft.com \
    && mkdir -p /usr/share/dotnet && tar -xzf /tmp/dotnet-runtime.tar.gz -C /usr/share/dotnet \
    && rm /tmp/dotnet-runtime.tar.gz

# Копируем файлы приложения из первой стадии
COPY --from=builder /out/lampac /lampac

# Переменные среды
ENV DOTNET_ROOT=/usr/share/dotnet \
    PATH="${PATH}:/usr/share/dotnet" \
    ASPNETCORE_URLS=http://0.0.0.0:9118 \
    DOTNET_RUNNING_IN_CONTAINER=true \
    CHROMIUM_PATH=/usr/bin/chromium \
    CHROMIUM_FLAGS="--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage"

# Создаем конфиг доверия для Koyeb и включаем Chromium
RUN echo '{"listen":{"port":9118},"KnownProxies":[{"ip":"0.0.0.0","prefixLength":0}],"chromium":{"enable":true,"binary":"/usr/bin/chromium"},"WAF":{"allowExternalIpAccess":true}}' > /lampac/init.conf

RUN chmod +x /usr/bin/chromium && touch isdocker

ENTRYPOINT ["/usr/share/dotnet/dotnet", "Core.dll", "--urls", "http://0.0.0.0:9118"]
