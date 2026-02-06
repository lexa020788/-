FROM --platform=linux/amd64 ghcr.io/lampac-talks/lampac:amd64

# Устанавливаем системные зависимости для .NET и Playwright (Chromium)
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    libicu-dev \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpangocairo-1.0-0 \
    libxshmfence1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /home

# Скачиваем Chromium заранее, чтобы Lampac не выдавал ошибку при старте
RUN npx playwright install chromium

# Создаем структуру модулей
RUN mkdir -p /home/module && \
    echo 'repositories:\n  - name: "Lampac"\n    url: "https://lampac.sh"' > /home/module/repository.yaml

# Записываем исправленный init.conf
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

# Права доступа
RUN chmod -R 777 /home/init.conf /home/module

# Настройки сети
ENV PORT=9118
ENV ASPNETCORE_URLS=http://+:9118
EXPOSE 9118

# Запуск приложения
ENTRYPOINT ["./Lampac", "--urls", "http://0.0.0.0:9118"]
