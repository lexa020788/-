# Global ARGs
ARG DOTNET_VERSION=9.0.0
ARG DOTNET_SDK_VERSION=9.0.100

# --- Builder Stage ---
FROM debian:13-slim AS builder
ARG BUILDARCH
ARG TARGETARCH
ARG DOTNET_SDK_VERSION
WORKDIR /build

# Вместо RUN RUN apt-get...
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl xz-utils git libicu76 && rm -rf /var/lib/apt/lists/*

# Клонируем и жестко адаптируем код под .NET 9
RUN git clone https://github.com/lampac-nextgen/lampac . \
    && find . -name "*.csproj" -exec sed -i 's/<TargetFramework>net10.0<\/TargetFramework>/<TargetFramework>net9.0<\/TargetFramework>/g' {} + \
    && find . -name "*.csproj" -exec sed -i 's/Version="10.0.2"/Version="9.0.0"/g' {} + \
    && sed -i 's/KnownIPNetworks/ToString/g' Core/Startup.cs \
    && sed -i 's/KnownNetworks/ToString/g' Core/Startup.cs

# Установка SDK
RUN case "$BUILDARCH" in \
    arm64) SDK_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-arm64.tar.gz" ;; \
    *) SDK_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-x64.tar.gz" ;; \
    esac \
    && curl -fSL -o /tmp/dotnet-sdk.tar.gz "${SDK_URL}" \
    && mkdir -p /usr/share/dotnet \
    && tar -xzf /tmp/dotnet-sdk.tar.gz -C /usr/share/dotnet \
    && rm /tmp/dotnet-sdk.tar.gz

# Публикация
RUN case "$TARGETARCH" in \
    arm64) RID=linux-arm64 ;; \
    *) RID=linux-x64 ;; \
    esac \
    && /usr/share/dotnet/dotnet publish Core/Core.csproj --configuration Release --runtime "$RID" \
    --output /out/lampac -p:Parallel=false --self-contained false

# --- Runner Stage ---
FROM debian:13-slim AS runner
ARG TARGETARCH
ARG DOTNET_VERSION
WORKDIR /lampac
EXPOSE 9118

# ПРАВИЛЬНОЕ ЗАДАНИЕ ПЕРЕМЕННЫХ
ENV DOTNET_GCHeapHardLimit=200000000 \
    DOTNET_ROOT=/usr/share/dotnet \
    PATH="${PATH}:/usr/share/dotnet" \
    ASPNETCORE_URLS=http://0.0.0 \
    DOTNET_RUNNING_IN_CONTAINER=true \
    CHROMIUM_PATH=/usr/bin/chromium \
    CHROMIUM_FLAGS="--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage --disable-gpu --single-process --no-zygote"

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates chromium curl fontconfig libicu76 libnspr4 libnss3 libgbm1 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Копируем приложение
COPY --from=builder /out/lampac /lampac

# Установка Runtime 9.0
RUN case "$TARGETARCH" in \
    arm64) RID=arm64 ;; \
    *) RID=x64 ;; \
    esac \
    && DOTNET_RUNTIME_URL="https://builds.dotnet.microsoft.com/${DOTNET_VERSION}/aspnetcore-runtime-${DOTNET_VERSION}-linux-${RID}.tar.gz" \
    && curl -fSL -o /tmp/dotnet-runtime.tar.gz "${DOTNET_RUNTIME_URL}" \
    && mkdir -p /usr/share/dotnet \
    && tar -xzf /tmp/dotnet-runtime.tar.gz -C /usr/share/dotnet \
    && rm /tmp/dotnet-runtime.tar.gz

# Создаем конфиг
RUN echo '{ \
  "listen": {"port": 9118, "KnownProxies": [{"ip": "0.0.0.0", "prefixLength": 0}]}, \
  "chromium": {"enable": true, "binary": "/usr/bin/chromium", "args": ["--no-sandbox", "--disable-setuid-sandbox", "--single-process"]}, \
  "WAF": {"allowExternalIpAccess": true}, \
  "GC": {"Concurrent": true, "HighMemoryPercent": 70} \
}' > /lampac/init.conf

RUN touch /lampac/isdocker

ENTRYPOINT ["dotnet", "Core.dll", "--urls", "http://0.0.0.0:9118"]
