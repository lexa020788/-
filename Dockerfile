# Multi-platform Dockerfile для Koyeb (linux/amd64 и linux/arm64)
ARG DOTNET_VERSION=10.0.5
ARG DOTNET_SDK_VERSION=10.0.201

# --- Builder Stage ---
FROM --platform=$BUILDPLATFORM debian:13-slim AS builder

ARG BUILDARCH
ARG TARGETARCH
ARG DOTNET_VERSION
ARG DOTNET_SDK_VERSION

WORKDIR /build
COPY . .

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl libicu76 xz-utils && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /out/usr/share/dotnet /out/lampac

RUN case "$BUILDARCH" in \
    arm64) SDK_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-arm64.tar.gz" ;; \
    amd64) SDK_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-x64.tar.gz" ;; \
    esac \
    && curl -fSL -o /tmp/dotnet-sdk.tar.gz "${SDK_URL}" \
    && tar -oxzf /tmp/dotnet-sdk.tar.gz -C /out/usr/share/dotnet \
    && rm /tmp/dotnet-sdk.tar.gz

RUN case "$TARGETARCH" in \
    arm64) \
    RT_URL="https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/${DOTNET_VERSION}/aspnetcore-runtime-${DOTNET_VERSION}-linux-arm64.tar.gz" \
    FFMPEG_URL="https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linuxarm64-gpl.tar.xz" \
    RID=linux-arm64 ;; \
    amd64) \
    RT_URL="https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/${DOTNET_VERSION}/aspnetcore-runtime-${DOTNET_VERSION}-linux-x64.tar.gz" \
    FFMPEG_URL="https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz" \
    RID=linux-x64 ;; \
    esac \
    && DOTNET_CLI_TELEMETRY_OPTOUT=1 /out/usr/share/dotnet/dotnet publish --configuration Release --runtime "$RID" --output /out/lampac -p:PlaywrightPlatform="$RID" Core/Core.csproj \
    && rm -rf /out/usr/share/dotnet/* \
    && curl -fSL -o /tmp/dotnet-runtime.tar.gz "${RT_URL}" \
    && tar -oxzf /tmp/dotnet-runtime.tar.gz -C /out/usr/share/dotnet \
    && rm /tmp/dotnet-runtime.tar.gz \
    && curl -fSL -o /tmp/ffmpeg.tar.xz "${FFMPEG_URL}" \
    && tar -xJf /tmp/ffmpeg.tar.xz -C /tmp --wildcards "*/bin/ffmpeg" "*/bin/ffprobe" --strip-components=2 \
    && mv /tmp/ffmpeg /tmp/ffprobe /out/lampac/data/ \
    && chmod +x /out/lampac/data/ffmpeg /out/lampac/data/ffprobe \
    && touch /out/lampac/isdocker

# --- Runner Stage ---
FROM debian:13-slim AS runner

# Настройки для Koyeb
ENV DOTNET_ROOT=/usr/share/dotnet \
    PATH="${PATH}:/usr/share/dotnet" \
    DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    # Порт для Koyeb (приложение должно слушать 8080)
    ASPNETCORE_URLS=http://+:8080 \
    CHROMIUM_PATH=/usr/bin/chromium \
    CHROMIUM_FLAGS="--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage --headless"

WORKDIR /lampac
# Koyeb по умолчанию открывает 8080
EXPOSE 8080

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates chromium curl fontconfig libicu76 libnspr4 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Создаем пользователя (Koyeb поддерживает root, но non-root безопаснее)
RUN groupadd -r -g 1000 lampac && useradd -r -u 1000 -g lampac -d /lampac lampac

# Копируем бинарники
COPY --chown=lampac:lampac --from=builder /out /

# Koyeb сам следит за здоровьем контейнера, но HEALTHCHECK не помешает
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

USER lampac

# Запуск. Убедитесь, что Core.dll — это входная точка вашего приложения
ENTRYPOINT ["dotnet", "lampac/Core.dll"]
