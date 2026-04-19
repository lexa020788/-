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

RUN rm -rf Modules/Anime Modules/SISI Modules/Market Modules/Guide

RUN sed -i 's/options.KnownIPNetworks.Add/\/\/ /g' Core/Startup.cs \
    && sed -i 's/options.KnownNetworks.Add/\/\/ /g' Core/Startup.cs \
    && sed -i '/Anime/d' Core/Startup.cs \
    && sed -i '/SISI/d' Core/Startup.cs

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
WORKDIR /lampac
EXPOSE 9118

# Вставь это в секцию FROM debian:13-slim AS runner
ENV DOTNET_GCHeapHardLimit=300000000 \
    DOTNET_ROOT=/usr/share/dotnet \
    PATH="${PATH}:/usr/share/dotnet" \
    ASPNETCORE_URLS=http://0.0.0 \
    DOTNET_RUNNING_IN_CONTAINER=true

# Устанавливаем только системные либы (БЕЗ CHROMIUM)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl fontconfig libicu76 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /out/lampac /lampac

# Установка Runtime
RUN case "$TARGETARCH" in \
    arm64) RID=arm64 ;; \
    *) RID=x64 ;; \
    esac \
    && DOTNET_RUNTIME_URL="https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/10.0.0/aspnetcore-runtime-10.0.0-linux-${RID}.tar.gz" \
    && curl -fSL -o /tmp/dotnet-runtime.tar.gz "${DOTNET_RUNTIME_URL}" \
    && mkdir -p /usr/share/dotnet \
    && tar -xzf /tmp/dotnet-runtime.tar.gz -C /usr/share/dotnet \
    && rm /tmp/dotnet-runtime.tar.gz

# Вставь это перед ENTRYPOINT
RUN echo '{ \
  "listen": {"port": 9118}, \
  "KnownProxies": [{"ip": "0.0.0.0", "prefixLength": 0}], \
  "chromium": {"enable": false}, \
  "WAF": {"allowExternalIpAccess": true}, \
  "Online": {"enable": true}, \
  "SISI": {"enable": false}, \
  "Anime": {"enable": false}, \
  "TorrServer": {"enable": false}, \
  "GC": {"Concurrent": true, "HighMemoryPercent": 85} \
}' > /lampac/init.conf


ENTRYPOINT ["dotnet", "Core.dll", "--urls", "http://0.0.0.0:9118"]
