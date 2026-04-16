# Используем .NET 9, так как он был в вашем рабочем конфиге
ARG DOTNET_VERSION=9.0.2
ARG DOTNET_SDK_VERSION=9.0.200

# Stage 1: Сборка
FROM --platform=$BUILDPLATFORM debian:12-slim AS builder

ARG BUILDARCH=amd64
ARG TARGETARCH=amd64
ARG DOTNET_VERSION
ARG DOTNET_SDK_VERSION

WORKDIR /build
COPY . .

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl xz-utils libicu72 && rm -rf /var/lib/apt/lists/*

RUN case "$BUILDARCH" in \
    arm64) SDK_URL="https://microsoft.com{DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-arm64.tar.gz" ;; \
    *)     SDK_URL="https://microsoft.com{DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-x64.tar.gz" ;; \
    esac \
    && case "$TARGETARCH" in \
    arm64) RID=linux-arm64 ;; \
    *)     RID=linux-x64 ;; \
    esac \
    && curl -fSL -o /tmp/dotnet.tar.gz "${SDK_URL}" \
    && mkdir -p /usr/share/dotnet \
    && tar -zxf /tmp/dotnet.tar.gz -C /usr/share/dotnet \
    && /usr/share/dotnet/dotnet publish -c Release -r "$RID" --output /out Core/Core.csproj

# Stage 2: Финальный образ
FROM debian:12-slim

WORKDIR /home
EXPOSE 8000

# Установка рантайма и зависимостей
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip libicu72 libnspr4 && rm -rf /var/lib/apt/lists/*

# Скачиваем рантайма .NET 9
RUN curl -fSL -o dotnet.tar.gz https://microsoft.com \
    && mkdir -p /usr/share/dotnet \
    && tar -zxf dotnet.tar.gz -C /usr/share/dotnet \
    && rm dotnet.tar.gz

ENV PATH="${PATH}:/usr/share/dotnet"

# Копируем собранное приложение из builder
COPY --from=builder /out /home
RUN touch isdocker

# Ваши конфиги из "рабочего" билда
RUN echo '{"listen":{"port":8000,"scheme":"https","frontend":"cloudflare"},"KnownProxies":[{"ip":"0.0.0.0","prefixLength":0}],"mikrotik":true,"typecache":"mem"}' > /home/init.conf
RUN mkdir -p /home/module && echo '{"typesearch":"webapi","Anilibria":{"enable":true},"RuTracker":{"enable":true},"lostfilm":{"enable":true}}' > /home/module/JacRed.conf
RUN echo '[{"enable":true,"dll":"SISI.dll"},{"enable":true,"dll":"Online.dll"},{"enable":true,"initspace":"Catalog.ModInit","dll":"Catalog.dll"},{"enable":true,"initspace":"TorrServer.ModInit","dll":"TorrServer.dll"},{"enable":true,"initspace":"Jackett.ModInit","dll":"JacRed.dll"}]' > /home/module/manifest.json

# TorrServer
RUN mkdir -p torrserver && curl -L -o torrserver/TorrServer-linux https://github.com/YouROK/TorrServer/releases/latest/download/TorrServer-linux-amd64 \
    && chmod +x torrserver/TorrServer-linux

ENTRYPOINT ["/usr/share/dotnet/dotnet", "Lampac.dll"]
