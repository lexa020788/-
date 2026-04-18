# Global ARGs
ARG DOTNET_VERSION=10.0.0
ARG DOTNET_SDK_VERSION=10.0.201

# --- Builder image ---
FROM debian:13-slim AS builder
ARG BUILDARCH
ARG TARGETARCH
ARG DOTNET_SDK_VERSION
WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl xz-utils libicu76 git \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/lampac-nextgen/lampac . \
    && rm -rf Plugins/SISI

RUN case "$BUILDARCH" in \
    arm64) SDK_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-arm64.tar.gz" ;; \
    *) SDK_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-x64.tar.gz" ;; \
    esac \
    && curl -fSL -o /tmp/dotnet-sdk.tar.gz "${SDK_URL}" \
    && mkdir -p /usr/share/dotnet \
    && tar -xzf /tmp/dotnet-sdk.tar.gz -C /usr/share/dotnet \
    && rm /tmp/dotnet-sdk.tar.gz

ENV PATH="${PATH}:/usr/share/dotnet"

# Сборка + установка Playwright (как у разработчика)
RUN case "$TARGETARCH" in \
    arm64) RID=linux-arm64 ;; \
    *) RID=linux-x64 ;; \
    esac \
    && dotnet publish Core/Core.csproj --configuration Release --runtime "$RID" --output /out/lampac \
    # Используем dotnet tool или прямой вызов библиотеки, это надежнее путей к .ps1
    && dotnet build Core/Core.csproj --configuration Release --runtime "$RID" \
    && cp Core/bin/Release/net10.0/$RID/playwright.sh /out/lampac/playwright.sh || true \
    # Вызов установки через dotnet (путь может отличаться, проверьте где лежит Microsoft.Playwright.dll)
    && dotnet exec /out/lampac/Microsoft.Playwright.dll install --with-deps \
    && cp -r /root/.cache /out/lampac/cache

# --- Runner image ---
FROM debian:13-slim AS runner
WORKDIR /lampac
EXPOSE 9118

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates chromium curl fontconfig libicu76 libnspr4 locales \
    libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 \
    libxcomposite1 libxdamage1 libxrandr2 libgbm1 libpango-1.0-0 libcairo2 libasound2 \
    && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /out/lampac /lampac
# Копируем кэш браузера из билдера
COPY --from=builder /out/lampac/cache /root/.cache

# Единый блок ENV без разрывов
ENV DOTNET_ROOT=/usr/share/dotnet \
    PATH="${PATH}:/usr/share/dotnet" \
    ASPNETCORE_URLS=http://+:9118 \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    CHROME_EXECUTABLE_PATH=/usr/bin/chromium \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    PLAYWRIGHT_BROWSERS_PATH=/lampac/cache \
    SISI_enable=false \
    SISI_all=false

RUN case "$(uname -m)" in \
    aarch64) RID=arm64 ;; \
    x86_64) RID=x64 ;; \
    esac \
    && DOTNET_RUNTIME_URL="https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/10.0.0/aspnetcore-runtime-10.0.0-linux-${RID}.tar.gz" \
    && curl -fSL -o /tmp/dotnet-runtime.tar.gz "${DOTNET_RUNTIME_URL}" \
    && mkdir -p /usr/share/dotnet \
    && tar -xzf /tmp/dotnet-runtime.tar.gz -C /usr/share/dotnet \
    && rm /tmp/dotnet-runtime.tar.gz

RUN touch /lampac/isdocker
ENTRYPOINT ["dotnet", "Core.dll"]
