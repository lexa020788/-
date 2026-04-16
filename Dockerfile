# Multi-platform Dockerfile для Koyeb
ARG DOTNET_VERSION=10.0.5
ARG DOTNET_SDK_VERSION=10.0.201

# --- Builder Stage ---
FROM --platform=$BUILDPLATFORM debian:13-slim AS builder

ARG BUILDARCH
ARG TARGETARCH
ARG DOTNET_VERSION
ARG DOTNET_SDK_VERSION

WORKDIR /build
# Копируем всё содержимое репозитория
COPY . .

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl libicu76 xz-utils && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /out/usr/share/dotnet /out/lampac

# Установка SDK для сборки
RUN case "$BUILDARCH" in \
    arm64) SDK_URL="https://microsoft.com{DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-arm64.tar.gz" ;; \
    amd64) SDK_URL="https://microsoft.com{DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-x64.tar.gz" ;; \
    esac \
    && curl -fSL -o /tmp/dotnet-sdk.tar.gz "${SDK_URL}" \
    && tar -oxzf /tmp/dotnet-sdk.tar.gz -C /out/usr/share/dotnet \
    && rm /tmp/dotnet-sdk.tar.gz

# Сборка приложения
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
    # Автоматический поиск .csproj файла, если Core/Core.csproj не найден
    && PROJECT_FILE=$(find . -name "Core.csproj" | head -n 1) \
    && echo "Found project: $PROJECT_FILE" \
    && DOTNET_CLI_TELEMETRY_OPTOUT=1 /out/usr/share/dotnet/dotnet publish "$PROJECT_FILE" --configuration Release --runtime "$RID" --output /out/lampac -p:PlaywrightPlatform="$RID" \
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

ENV DOTNET_ROOT=/usr/share/dotnet \
    PATH="${PATH}:/usr/share/dotnet" \
    DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    ASPNETCORE_URLS=http://+:8080 \
    CHROMIUM_PATH=/usr/bin/chromium \
    CHROMIUM_FLAGS="--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage --headless"

WORKDIR /lampac
EXPOSE 8080

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates chromium curl fontconfig libicu76 libnspr4 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN groupadd -r -g 1000 lampac && useradd -r -u 1000 -g lampac -d /lampac lampac
COPY --chown=lampac:lampac --from=builder /out /

# Проверка работоспособности
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

USER lampac
ENTRYPOINT ["dotnet", "lampac/Core.dll"]
