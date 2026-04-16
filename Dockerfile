FROM debian:12.5-slim
EXPOSE 8000
WORKDIR /home

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip libicu-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# .NET 9 Runtime
RUN curl -fSL -o dotnet.tar.gz https://microsoft.com \
    && mkdir -p /usr/share/dotnet && tar -oxzf dotnet.tar.gz -C /usr/share/dotnet && rm dotnet.tar.gz

# Lampac Nextgen
RUN curl -L -o publish.zip https://github.com \
    && unzip -o publish.zip && rm -f publish.zip \
    && rm -rf runtimes/win* runtimes/linux-arm* runtimes/linux-musl* \
    && touch isdocker

# Установка TorrServer (Матрица)
RUN mkdir -p torrserver && \
    curl -L -o torrserver/TorrServer-linux https://github.com && \
    chmod +x torrserver/TorrServer-linux

# Конфигурация модулей (включаем TorrServer и JacRed)
RUN mkdir -p /home/module && echo '[ \
    {"enable":true,"dll":"SISI.dll"}, \
    {"enable":true,"dll":"Online.dll"}, \
    {"enable":true,"initspace":"Catalog.ModInit","dll":"Catalog.dll"}, \
    {"enable":true,"initspace":"TorrServer.ModInit","dll":"TorrServer.dll"}, \
    {"enable":true,"initspace":"Jackett.ModInit","dll":"JacRed.dll"} \
]' > /home/module/manifest.json

# Базовые настройки
RUN echo '{"listen":{"port":8000},"KnownProxies":[{"ip":"0.0.0.0","prefixLength":0}],"WAF":{"allowExternalIpAccess":true},"serverproxy":{"verifyip":false}}' > /home/init.conf

ENTRYPOINT ["/usr/share/dotnet/dotnet", "Lampac.dll"]
