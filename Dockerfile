FROM --platform=linux/amd64 ghcr.io/lampac-talks/lampac:amd64

RUN apt-get update && apt-get install -y curl ca-certificates libicu-dev && rm -rf /var/lib/apt/lists/*

WORKDIR /home

RUN mkdir -p /home/module && \
    echo 'repositories:\n  - name: "Lampac"\n    url: "https://lampac.sh"' > /home/module/repository.yaml

# ИСПРАВЛЕННЫЙ init.conf
RUN echo '{\
  "listenport": 9118, \
  "dlna": { "downloadSpeed": 25000000 },\
  "Rezka": { "streamproxy": true },\
  "Zetflix": {\
    "displayname": "Zetflix - 1080p", \
    "geostreamproxy": ["UA"], \
    "apn": { "list": ["http://apn.cfhttp.top"], "corseu": false }\
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
}' > /home/init.conf

RUN chmod -R 777 /home/init.conf /home/module

ENV PORT=9118
ENV ASPNETCORE_URLS=http://+:9118
EXPOSE 9118

ENTRYPOINT ["./Lampac", "--urls", "http://0.0.0.0:9118"]
