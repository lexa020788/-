# Global ARGs
ARG DOTNET_SDK_VERSION=10.0.201

# --- Сборка приложения ---
FROM debian:12-slim AS builder
ARG DOTNET_SDK_VERSION
WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl xz-utils libicu72 git && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com .

RUN SDK_URL="https://microsoft.com{DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-x64.tar.gz" \
    && curl -fSL -o /tmp/dotnet-sdk.tar.gz "${SDK_URL}" \
    && mkdir -p /out/usr/share/dotnet \
    && tar -xzf /tmp/dotnet-sdk.tar.gz -C /out/usr/share/dotnet \
    && rm /tmp/dotnet-sdk.tar.gz

RUN /out/usr/share/dotnet/dotnet publish --configuration Release --runtime linux-x64 \
    --output /out/lampac -p:PlaywrightPlatform="linux-x64" -p:Parallel=false Core/Core.csproj

# --- Финальный образ ---
FROM debian:12-slim AS runner
WORKDIR /lampac
EXPOSE 8080

# Переменные для .NET и Chromium
ENV ASPNETCORE_URLS=http://0.0.0 \
    DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    CHROMIUM_PATH=/usr/bin/chromium \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    PLAYWRIGHT_BROWSERS_PATH=0 \
    CHROMIUM_FLAGS="--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage --disable-gpu"

# Установка зависимостей Chromium и .NET Runtime одним блоком
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates chromium curl fontconfig libicu72 libnspr4 libnss3 \
    libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxcomposite1 \
    libxdamage1 libxext6 libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 libasound2 \
    && curl -fSL -o /tmp/dotnet-runtime.tar.gz https://microsoft.com \
    && mkdir -p /usr/share/dotnet && tar -zxf /tmp/dotnet-runtime.tar.gz -C /usr/share/dotnet \
    && rm /tmp/dotnet-runtime.tar.gz \
    && ln -sf /usr/bin/chromium /usr/bin/chromium-browser \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Копируем файлы приложения
COPY --from=builder /out/lampac /lampac

# Создаем нужные папки и даем права
RUN mkdir -p /lampac/data && touch /lampac/isdocker && chmod +x /usr/bin/chromium

# Запуск с ПРИНУДИТЕЛЬНЫМ указанием порта 8080
ENTRYPOINT ["/usr/share/dotnet/dotnet", "Core.dll", "--urls", "http://0.0.0"]
