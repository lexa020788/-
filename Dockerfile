# Global ARGs
ARG DOTNET_VERSION=10.0.0
ARG DOTNET_SDK_VERSION=10.0.201

# Builder image
FROM debian:12-slim AS builder

ARG BUILDARCH
ARG TARGETARCH
ARG DOTNET_VERSION
ARG DOTNET_SDK_VERSION

WORKDIR /build

# 1. Устанавливаем git и инструменты (БЕЗ ЭТОГО НЕ ЗАРАБОТАЕТ)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl xz-utils libicu72 git \
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
FROM debian:12-slim AS runner
WORKDIR /lampac
EXPOSE 9118

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates chromium curl fontconfig libicu72 libnspr4 libnss3 \
    libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxcomposite1 \
    libxdamage1 libxext6 libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 libasound2 \
    && mkdir -p /lampac/Core/data \
    && ln -sf /usr/bin/chromium /usr/bin/chromium-browser \
    && ln -sf /usr/bin/chromium /lampac/chromium \
    && ln -sf /usr/bin/chromium /lampac/Core/data/chromium \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV ASPNETCORE_URLS=http://0.0.0 \
    DOTNET_RUNNING_IN_CONTAINER=true \
    # Пути для Chromium
    CHROMIUM_PATH=/usr/bin/chromium \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    PLAYWRIGHT_BROWSERS_PATH=0 \
    # Флаги для запуска в Docker
    CHROMIUM_FLAGS="--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage --disable-gpu --headless"

# Сначала удаляем старую папку, если она была создана символическими ссылками ранее
RUN rm -rf /lampac && mkdir -p /lampac

# Копируем результат сборки
COPY --from=builder /out/lampac /lampac

# 1. Переходим в папку приложения
WORKDIR /lampac

# Создаем файл-метку для докера
RUN touch isdocker

# Создаем ссылки заново ПРИ НАЛИЧИИ файлов приложения
RUN ln -sf /usr/bin/chromium /usr/bin/chromium-browser && \
    ln -sf /usr/bin/chromium /lampac/chromium && \
    mkdir -p /lampac/Core/data && \
    ln -sf /usr/bin/chromium /lampac/Core/data/chromium

# 3. Настраиваем переменные окружения, чтобы система видела dotnet
ENV DOTNET_ROOT=/usr/share/dotnet \
    PATH="/usr/share/dotnet:${PATH}"

# 4. Проверяем наличие файла и запускаем
RUN touch /lampac/isdocker
ENTRYPOINT ["dotnet", "Core.dll", "--urls", "http://0.0.0"]
