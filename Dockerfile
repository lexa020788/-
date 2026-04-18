# Global ARGs
ARG DOTNET_VERSION=10.0.0
ARG DOTNET_SDK_VERSION=10.0.201

# --- Builder image ---
FROM debian:13-slim AS builder
ARG TARGETARCH
ARG DOTNET_SDK_VERSION
WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl xz-utils libicu76 git \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/lampac-nextgen/lampac .

# Установка SDK
RUN case "$TARGETARCH" in \
    arm64) SDK_ARCH="arm64" ;; \
    *) SDK_ARCH="x64" ;; \
    esac \
    && curl -fSL -o /tmp/dotnet-sdk.tar.gz "https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-${SDK_ARCH}.tar.gz" \
    && mkdir -p /usr/share/dotnet \
    && tar -xzf /tmp/dotnet-sdk.tar.gz -C /usr/share/dotnet \
    && rm /tmp/dotnet-sdk.tar.gz

ENV PATH="${PATH}:/usr/share/dotnet"

# Сборка (Release)
RUN case "$TARGETARCH" in \
    arm64) RID=linux-arm64 ;; \
    *) RID=linux-x64 ;; \
    esac \
    && dotnet publish Core/Core.csproj --configuration Release --runtime "$RID" \
    --output /out/lampac --self-contained false -p:Parallel=false

# --- Runner image ---
FROM debian:13-slim AS runner
WORKDIR /lampac

# Установка зависимостей для .NET и Playwright (Chromium)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl libicu76 libnss3 libnspr4 libatk1.0-0 \
    libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 libxcomposite1 \
    libxdamage1 libxrandr2 libgbm1 libpango-1.0-0 libcairo2 libasound2 \
    && rm -rf /var/lib/apt/lists/*

# Копируем результат сборки
COPY --from=builder /out/lampac /lampac
COPY --from=builder /usr/share/dotnet /usr/share/dotnet

# Настройки среды
ENV DOTNET_ROOT=/usr/share/dotnet \
    PATH="/usr/share/dotnet:${PATH}" \
    ASPNETCORE_URLS=http://+:9118 \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    LC_ALL=en_US.UTF-8

# Создаем маркер докера
RUN touch isdocker

# Открываем порт
EXPOSE 9118

ENTRYPOINT ["dotnet", "Core.dll"]
