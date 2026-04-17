# Multi-platform Dockerfile for linux/amd64 and linux/arm64
# Build with: docker buildx build --platform linux/amd64,linux/arm64 -t lampac:latest .

# Global ARGs
ARG DOTNET_VERSION=9.0.2
ARG DOTNET_SDK_VERSION=9.0.201

# Builder image
FROM --platform=$BUILDPLATFORM debian:13-slim AS builder

ARG BUILDARCH
ARG TARGETARCH
ARG DOTNET_VERSION
ARG DOTNET_SDK_VERSION

RUN mkdir -p /out
WORKDIR /build

COPY . .

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libicu76 \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN case "$BUILDARCH" in \
    arm64) DOTNET_SDK_URL="https://microsoft.com{DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-arm64.tar.gz" ;; \
    amd64) DOTNET_SDK_URL="https://microsoft.com{DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-x64.tar.gz" ;; \
    *) echo "Unsupported BUILDARCH: $BUILDARCH" && exit 1 ;; \
    esac \
    && case "$TARGETARCH" in \
    arm64) \
    DOTNET_RUNTIME_URL="https://microsoft.com{DOTNET_VERSION}/aspnetcore-runtime-${DOTNET_VERSION}-linux-arm64.tar.gz" \
    FFMPEG_URL="https://github.com" \
    RID=linux-arm64 ;; \
    amd64) \
    DOTNET_RUNTIME_URL="https://microsoft.com{DOTNET_VERSION}/aspnetcore-runtime-${DOTNET_VERSION}-linux-x64.tar.gz" \
    FFMPEG_URL="https://github.com" \
    RID=linux-x64 ;; \
    *) echo "Unsupported TARGETARCH: $TARGETARCH" && exit 1 ;; \
    esac \
    && curl -fSL -o /tmp/dotnet-sdk.tar.gz "${DOTNET_SDK_URL}" \
    && mkdir -p /out/usr/share/dotnet \
    && tar -oxzf /tmp/dotnet-sdk.tar.gz -C /out/usr/share/dotnet \
    && rm /tmp/dotnet-sdk.tar.gz \
    && DOTNET_CLI_TELEMETRY_OPTOUT=1 /out/usr/share/dotnet/dotnet publish --configuration Release --runtime "$RID" --output /out/lampac -p:PlaywrightPlatform="$RID" Core/Core.csproj \
    && rm -rf /out/usr/share/dotnet \
    && mkdir -p /out/usr/share/dotnet \
    && curl -fSL -o /tmp/dotnet-runtime.tar.gz "${DOTNET_RUNTIME_URL}" \
    && tar -oxzf /tmp/dotnet-runtime.tar.gz -C /out/usr/share/dotnet \
    && rm /tmp/dotnet-runtime.tar.gz \
    && mkdir -p /out/lampac/data \
    && curl -fSL -o /tmp/ffmpeg.tar.xz "${FFMPEG_URL}" \
    && tar -xJf /tmp/ffmpeg.tar.xz -C /tmp --wildcards "*/bin/ffmpeg" "*/bin/ffprobe" --strip-components=2 \
    && mv /tmp/ffmpeg /tmp/ffprobe /out/lampac/data/ \
    && chmod +x /out/lampac/data/ffmpeg /out/lampac/data/ffprobe \
    && rm /tmp/ffmpeg.tar.xz \
    && touch /out/lampac/isdocker

# Runner image
FROM debian:13-slim AS runner

ARG TARGETARCH

ENV DOTNET_ROOT=/usr/share/dotnet \
    PATH="${PATH}:/usr/share/dotnet" \
    DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    CHROMIUM_PATH=/usr/bin/chromium \
    CHROMIUM_FLAGS="--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage"

WORKDIR /lampac
EXPOSE 9118

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    chromium \
    curl \
    fontconfig \
    libicu76 \
    libnspr4 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/share/doc /usr/share/man /usr/share/info /usr/share/common-licenses

RUN groupadd -r -g 1000 lampac \
    && useradd -r -u 1000 -g lampac -d /lampac lampac

COPY --chown=lampac:lampac --from=builder /out /

USER lampac
ENTRYPOINT ["/usr/share/dotnet/dotnet", "Core.dll"]
