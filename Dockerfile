# Используем .NET 9
ARG DOTNET_VERSION=9.0.2
ARG DOTNET_SDK_VERSION=9.0.200

# Stage 1: Сборка
FROM --platform=$BUILDPLATFORM debian:12-slim AS builder

ARG BUILDARCH
ARG TARGETARCH
ARG DOTNET_SDK_VERSION

WORKDIR /build
# Сначала копируем только файлы проекта для кеширования (опционально)
COPY . .

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl xz-utils libicu72 && rm -rf /var/lib/apt/lists/*

# Исправленные ссылки (Azure CDN) и синтаксис
RUN ARCH_TYPE=${BUILDARCH:-amd64} && \
    if [ "$ARCH_TYPE" = "arm64" ]; then \
      SDK_URL="https://azureedge.net{DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-arm64.tar.gz"; \
    else \
      SDK_URL="https://azureedge.net{DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-x64.tar.gz"; \
    fi && \
    curl -fSL -o /tmp/dotnet.tar.gz "${SDK_URL}" && \
    mkdir -p /usr/share/dotnet && \
    tar -zxf /tmp/dotnet.tar.gz -C /usr/share/dotnet

# Определяем RID для публикации
RUN TARGET_TYPE=${TARGETARCH:-amd64} && \
    if [ "$TARGET_TYPE" = "arm64" ]; then RID="linux-arm64"; else RID="linux-x64"; fi && \
    /usr/share/dotnet/dotnet publish -c Release -r "$RID" --self-contained false --output /out Core/Core.csproj

# Stage 2: Финальный образ
FROM debian:12-slim

ARG TARGETARCH
ARG DOTNET_VERSION
WORKDIR /home
EXPOSE 8000

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip libicu72 libnspr4 && rm -rf /var/lib/apt/lists/*

# Установка рантайма (исправлено скачивание)
RUN TARGET_TYPE=${TARGETARCH:-amd64} && \
    if [ "$TARGET_TYPE" = "arm64" ]; then \
      R_URL="https://azureedge.net{DOTNET_VERSION}/dotnet-runtime-${DOTNET_VERSION}-linux-arm64.tar.gz"; \
    else \
      R_URL="https://azureedge.net{DOTNET_VERSION}/dotnet-runtime-${DOTNET_VERSION}-linux-x64.tar.gz"; \
    fi && \
    curl -fSL -o /tmp/dotnet.tar.gz "${R_URL}" && \
    mkdir -p /usr/share/dotnet && \
    tar -zxf /tmp/dotnet.tar.gz -C /usr/share/dotnet && \
    rm /tmp/dotnet.tar.gz

ENV PATH="${PATH}:/usr/share/dotnet"
ENV DOTNET_ROOT="/usr/share/dotnet"

COPY --from=builder /out /home
RUN touch isdocker

# Конфигурационные файлы
RUN echo '{"listen":{"port":8000,"scheme":"https","frontend":"cloudflare"},"KnownProxies":[{"ip":"0.0.0.0","prefixLength":0}],"mikrotik":true,"typecache":"mem"}' > /home/init.conf
RUN mkdir -p /home/module && echo '{"typesearch":"webapi","Anilibria":{"enable":true},"RuTracker":{"enable":true},"lostfilm":{"enable":true}}' > /home/module/JacRed.conf
RUN echo '[{"enable":true,"dll":"SISI.dll"},{"enable":true,"dll":"Online.dll"},{"enable":true,"initspace":"Catalog.ModInit","dll":"Catalog.dll"},{"enable":true,"initspace":"TorrServer.ModInit","dll":"TorrServer.dll"},{"enable":true,"initspace":"Jackett.ModInit","dll":"JacRed.dll"}]' > /home/module/manifest.json

# TorrServer (авто-выбор архитектуры)
RUN TARGET_TYPE=${TARGETARCH:-amd64} && \
    if [ "$TARGET_TYPE" = "arm64" ]; then T_ARCH="arm64"; else T_ARCH="amd64"; fi && \
    mkdir -p torrserver && \
    curl -L -o torrserver/TorrServer-linux "https://github.com{T_ARCH}" && \
    chmod +x torrserver/TorrServer-linux

ENTRYPOINT ["/usr/share/dotnet/dotnet", "Lampac.dll"]
