# Global ARGs
ARG DOTNET_VERSION=10.0.0
ARG DOTNET_SDK_VERSION=10.0.201

# --- Builder Stage ---
FROM debian:13-slim AS builder
WORKDIR /build
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl xz-utils git libicu76 && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/lampac-nextgen/lampac .

RUN curl -fSL -o /tmp/dotnet-sdk.tar.gz https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-arm64.tar.gz \
    && mkdir -p /usr/share/dotnet && tar -xzf /tmp/dotnet-sdk.tar.gz -C /usr/share/dotnet

# Собираем как есть, БЕЗ ПРАВОК кода (чтобы не было ошибок CS1525)
RUN /usr/share/dotnet/dotnet publish Core/Core.csproj --configuration Release --output /out/lampac --self-contained false


# --- Runner Stage ---
FROM debian:13-slim AS runner
FROM debian:13-slim AS runner
WORKDIR /lampac
EXPOSE 9118

# Лимиты для 512MB (главный секрет выживания на Koyeb)
ENV DOTNET_GCHeapHardLimit=350000000 \
    ASPNETCORE_URLS=http://0.0.0 \
    DOTNET_RUNNING_IN_CONTAINER=true

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl libicu76 && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /out/lampac .

RUN curl -fSL -o /tmp/dotnet-sdk.tar.gz https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-arm64.tar.gz \
    && mkdir -p /usr/share/dotnet && tar -xzf /tmp/dotnet-sdk.tar.gz -C /usr/share/dotnet

# ОТКЛЮЧАЕМ ЛИШНЕЕ ЧЕРЕЗ КОНФИГ (это не ломает билд)
RUN echo '{ \
  "listen": {"port": 9118}, \
  "chromium": {"enable": false}, \
  "SISI": {"enable": false}, \
  "Anime": {"enable": false}, \
  "TorrServer": {"enable": false}, \
  "WAF": {"allowExternalIpAccess": true} \
}' > /lampac/init.conf

ENTRYPOINT ["/usr/share/dotnet/dotnet", "Core.dll"]
