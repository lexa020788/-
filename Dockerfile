# 1. AMD64 оригинал
FROM --platform=linux/amd64 ghcr.io/lampac-talks/lampac:amd64

# Системные зависимости
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    libicu-dev \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /

# 2. Плагины
RUN mkdir -p module && \
    echo 'repositories:\n  - name: "Lampac"\n    url: "https://lampac.sh"' > module/repository.yaml

# 3. Конфиг (под Koyeb порт 8080)
RUN echo '{\
  "listenport": 8080, \
  "dlna": { "downloadSpeed": 25000000 },\
  "Rezka": { "streamproxy": true },\
  "Zetflix": {\
    "displayname": "Zetflix - 1080p", \
    "geostreamproxy": ["UA"], \
    "apn": "http://apn.cfhttp.top"\
  },\
  "Kodik": {\
    "useproxy": true, \
    "proxy": { "list": ["socks5://91.1.1.1:5481", "91.2.2.2:5481"] }\
  },\
  "Ashdi": { "useproxy": true },\
  "Filmix": { "token": "protoken" },\
  "PornHub": { "enable": false },\
  "proxy": { "list": ["93.3.3.3:5481"] },\
  "globalproxy": [\
    { "pattern": "\\\\.onion", "list": ["socks5://127.0.0.1:9050"] }\
  ],\
  "overrideResponse": [\
    { "pattern": "/msx/start.json", "action": "file", "type": "application/json; charset=utf-8", "val": "myfile.json" }\
  ]\
}' > init.conf

RUN chmod -R 777 /

# Настройки среды для Koyeb
ENV DOTNET_GCHeapHardLimit=1C000000 
ENV ASPNETCORE_URLS=http://+:8080
# Koyeb любит переменную PORT
ENV PORT=8080 
EXPOSE 8080

# 5. ЗАПУСК
ENTRYPOINT ["dotnet", "Lampac.dll", "--urls", "http://0.0.0.0:8080"]
