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

# --- Runner Stage ---
FROM debian:13-slim AS runner
ARG TARGETARCH
WORKDIR /lampac
EXPOSE 9118

# Добавляем переменные как у разработчика (это ВАЖНО для Chromium)
ENV DOTNET_ROOT=/usr/share/dotnet \
    PATH="${PATH}:/usr/share/dotnet" \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    DOTNET_RUNNING_IN_CONTAINER=true \
    CHROMIUM_PATH=/usr/bin/chromium \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    CHROMIUM_FLAGS="--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage"

# Установка зависимостей ТОЧНО как у разработчика (добавлен libnspr4)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates chromium curl fontconfig libicu76 libnspr4 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Копируем приложение
COPY --from=builder /out/lampac /lampac

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

# Финальный штрих: создаем метку и даем права (как у разработчика)
RUN touch /lampac/isdocker && chmod +x /usr/bin/chromium

ENTRYPOINT ["dotnet", "Core.dll", "--urls", "http://0.0.0.0:8080"]
