# 1. Используем официальный образ
FROM --platform=linux/amd64 ghcr.io/lampac-talks/lampac:amd64

# Устанавливаем зависимости
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    libicu-dev \
&& rm -rf /var/lib/apt/lists/*

# Устанавливаем рабочую директорию (ВАЖНО)
WORKDIR /app

# 2. Настраиваем репозиторий плагинов (путь /app/module)
RUN mkdir -p /app/module && \
    echo 'repositories:\n  - name: "Lampac"\n    url: "https://lampac.sh"' > /app/module/repository.yaml

# 3. Создаем init.conf в рабочей директории /app/
RUN echo '{\
  "listenport": 9120, \
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
}' > /app/init.conf

# 4. Права доступа
RUN chmod -R 777 /app

# Настройки среды
ENV DOTNET_GCHeapHardLimit=1C000000 
ENV ASPNETCORE_URLS=http://+:9120
EXPOSE 9120

# 5. ИСПРАВЛЕННЫЙ ЗАПУСК
# Проверяем путь /app/Lampac.dll
ENTRYPOINT ["dotnet", "Lampac.dll", "--urls", "http://0.0.0.0:9120"]
