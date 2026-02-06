FROM --platform=linux/amd64 ghcr.io/lampac-talks/lampac:amd64

# Ставим зависимости
RUN apt-get update && apt-get install -y curl ca-certificates libicu-dev && rm -rf /var/lib/apt/lists/*

# Создаем конфиг в корне, потом мы его скопируем куда надо
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
}' > /init.conf

# Настройки Koyeb
ENV PORT=8080
EXPOSE 8080

# СУПЕР-ЗАПУСК
# 1. Находим путь к файлу Lampac
# 2. Переходим в эту папку (чтобы он видел свои библиотеки)
# 3. Копируем наш конфиг туда
# 4. Запускаем
ENTRYPOINT ["sh", "-c", "\
    BINARY_PATH=$(find / -name Lampac -type f -executable -not -path '*/.*' | head -n 1); \
    if [ -z \"$BINARY_PATH\" ]; then BINARY_PATH=$(find / -name Lampac -type f | head -n 1); fi; \
    echo \"Found binary at: $BINARY_PATH\"; \
    BINARY_DIR=$(dirname \"$BINARY_PATH\"); \
    cd \"$BINARY_DIR\"; \
    cp /init.conf ./init.conf; \
    chmod +x ./Lampac; \
    ./Lampac --urls http://0.0.0.0:8080"]
