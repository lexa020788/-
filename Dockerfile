# Global ARGs
ARG DOTNET_VERSION=10.0.0
ARG DOTNET_SDK_VERSION=10.0.201

# Builder image
FROM debian:13-slim AS builder

ARG BUILDARCH
ARG TARGETARCH
ARG DOTNET_VERSION
ARG DOTNET_SDK_VERSION

WORKDIR /build

# 1. Устанавливаем git и инструменты (БЕЗ ЭТОГО НЕ ЗАРАБОТАЕТ)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl xz-utils libicu76 git \
    && rm -rf /var/lib/apt/lists/*

# 2. Клонируем исходники Lampac напрямую (так как ваш репозиторий пуст)
RUN git clone https://github.com/lampac-nextgen/lampac .

# Проверьте, чтобы после .com был СЛЭШ, а перед переменной знак $
RUN case "$BUILDARCH" in \
        arm64) SDK_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-arm64.tar.gz" ;; \
    *) SDK_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-x64.tar.gz" ;; \
    esac \
    && curl -fSL -o /tmp/dotnet-sdk.tar.gz "${SDK_URL}" \
    && mkdir -p /out/usr/share/dotnet \
    && tar -xzf /tmp/dotnet-sdk.tar.gz -C /out/usr/share/dotnet \
    && rm /tmp/dotnet-sdk.tar.gz


# 3. Сборка с ограничением ресурсов (-p:Parallel=false чтобы не вылететь по памяти)
RUN case "$TARGETARCH" in \
    arm64) RID=linux-arm64 ;; \
    *) RID=linux-x64 ;; \
    esac \
    && /out/usr/share/dotnet/dotnet publish --configuration Release --runtime "$RID" \
    --output /out/lampac -p:PlaywrightPlatform="$RID" -p:Parallel=false Core/Core.csproj

# Runner image
FROM debian:13-slim AS runner
WORKDIR /lampac
EXPOSE 9118

ENV DOTNET_ROOT=/usr/share/dotnet \
    PATH="${PATH}:/usr/share/dotnet" \
    DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    CHROMIUM_PATH=/usr/bin/chromium \
    CHROMIUM_FLAGS="--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage" \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \

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

# Копируем результат сборки
COPY --from=builder /out/lampac /lampac
# 1. Переходим в папку приложения
WORKDIR /lampac

# 2. Скачиваем и устанавливаем ТОЛЬКО Runtime (среду запуска), а не тяжелый SDK
RUN case "$(uname -m)" in \
    aarch64) RID=arm64 ;; \
    x86_64) RID=x64 ;; \
    esac \
    && DOTNET_RUNTIME_URL="https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/10.0.0/aspnetcore-runtime-10.0.0-linux-${RID}.tar.gz" \
    && curl -fSL -o /tmp/dotnet-runtime.tar.gz "${DOTNET_RUNTIME_URL}" \
    && mkdir -p /usr/share/dotnet \
    && tar -xzf /tmp/dotnet-runtime.tar.gz -C /usr/share/dotnet \
    && rm /tmp/dotnet-runtime.tar.gz


# 3. Настраиваем переменные окружения, чтобы система видела dotnet
ENV DOTNET_ROOT=/usr/share/dotnet \
    PATH="/usr/share/dotnet:${PATH}"

# 4. Проверяем наличие файла и запускаем
RUN touch /lampac/isdocker
ENTRYPOINT ["dotnet", "Core.dll"]
