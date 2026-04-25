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
    ca-certificates curl xz-utils git \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/lampac-nextgen/lampac .

# Установка SDK
RUN case "$BUILDARCH" in \
    arm64) SDK_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-arm64.tar.gz" ;; \
    *) SDK_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-x64.tar.gz" ;; \
    esac \
    && curl -fSL -o /tmp/dotnet-sdk.tar.gz "${SDK_URL}" \
    && mkdir -p /usr/share/dotnet \
    && tar -xzf /tmp/dotnet-sdk.tar.gz -C /usr/share/dotnet \
    && rm /tmp/dotnet-sdk.tar.gz

# Сборка без Playwright (так как Chromium отключен)
RUN case "$TARGETARCH" in \
    arm64) RID=linux-arm64 ;; \
    *) RID=linux-x64 ;; \
    esac \
    && /usr/share/dotnet/dotnet publish --configuration Release --runtime "$RID" \
    --output /out/lampac -p:Parallel=false Core/Core.csproj

# --- Runner Stage ---
FROM debian:13-slim AS runner
ARG TARGETARCH
ARG DOTNET_VERSION
WORKDIR /lampac

# Удален chromium и все его либы для экономии места и RAM
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl libicu76 procps socat tini \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Установка Runtime
RUN case "$TARGETARCH" in \
    arm64) RID=arm64 ;; \
    *) RID=x64 ;; \
    esac && \
    curl -fSL -o /tmp/rt.tar.gz "https://microsoft.com{DOTNET_VERSION}/aspnetcore-runtime-${DOTNET_VERSION}-linux-${RID}.tar.gz" && \
    mkdir -p /usr/share/dotnet && tar -xzf /tmp/rt.tar.gz -C /usr/share/dotnet && rm /tmp/rt.tar.gz

# Настройки для выживания в 512MB RAM
ENV PATH="${PATH}:/usr/share/dotnet" \
    DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_GCHeapHardLimit=200000000 \
    ASPNETCORE_URLS=http://0.0.0

COPY --from=builder /out/lampac /lampac
# Копируем только необходимые модули, если они собрались
COPY --from=builder /build/Modules/. /lampac/modules/ 2>/dev/null || true

# Конфигурация: отключен Chromium, порты под Koyeb
# Koyeb по умолчанию ожидает порт 8080 (или перенастройте в панели)
RUN echo '{"listen":{"port":8080},"server":{"host":"0.0.0.0"},"cache":{"enable":true},"online":{"enable":true,"proxy":true,"internal":true,"threads":1,"timeout":20},"online_config":{"mikai":{"enable":true,"proxy":true},"lumen":{"enable":true,"proxy":true},"rezka":{"enable":true,"proxy":true}},"LampaWeb":{"init":true,"plugins":["/online.js","/sisi.js"]},"chromium":{"enable":false}}' > /lampac/init.conf

RUN mkdir -p /lampac/data /lampac/cache && chmod -R 777 /lampac /tmp

EXPOSE 8080
ENTRYPOINT ["/usr/bin/tini", "--"]

# Запуск напрямую. На Koyeb socat обычно не нужен, если приложение слушает 8080
CMD ["dotnet", "Core.dll"]
