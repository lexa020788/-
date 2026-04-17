# Global ARGs
ARG DOTNET_VERSION=10.0.5
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

# Определение ссылок для загрузки SDK
RUN case "$BUILDARCH" in \
    arm64) SDK_URL="https://microsoft.com${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-arm64.tar.gz" ;; \
    *) SDK_URL="https://microsoft.com${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-x64.tar.gz" ;; \
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
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates chromium curl fontconfig libicu76 libnspr4 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Копируем результат сборки
COPY --from=builder /out/lampac /lampac

# Устанавливаем среду выполнения .NET (Runtime)
RUN curl -fSL -o /tmp/dotnet-runtime.tar.gz "https://microsoft.com" \
    && mkdir -p /usr/share/dotnet \
    && tar -xzf /tmp/dotnet-runtime.tar.gz -C /usr/share/dotnet \
    && rm /tmp/dotnet-runtime.tar.gz

ENTRYPOINT ["dotnet", "Core.dll"]
