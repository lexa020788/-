FROM --platform=linux/amd64 ghcr.io/lampac-talks/lampac:amd64

# Ставим только самое нужное
RUN apt-get update && apt-get install -y curl ca-certificates libicu-dev && rm -rf /var/lib/apt/lists/*

# Не создаем новые папки, работаем там, где уже есть Лампак
WORKDIR /

# Создаем конфиг прямо в корне (рядом с бинарником)
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

# Создаем папку модулей
RUN mkdir -p module && \
    echo 'repositories:\n  - name: "Lampac"\n    url: "https://lampac.sh"' > module/repository.yaml

# Даем права только на конфиг и модули
RUN chmod 777 init.conf && chmod -R 777 module

# Настройки Koyeb
ENV PORT=8080
EXPOSE 8080

# ЗАПУСК: Ищем бинарник Lampac и запускаем его напрямую
ENTRYPOINT ["sh", "-c", "chmod +x ./Lampac 2>/dev/null; ./Lampac --urls http://0.0.0.0:8080"]
