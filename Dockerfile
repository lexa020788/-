# 1. Оригинал
FROM --platform=linux/amd64 ghcr.io/lampac-talks/lampac:amd64

# Системные либы (на всякий случай для прокси и веба)
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    libicu-dev \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 2. Собираем файлы (теперь ищем именно исполняемый файл Lampac)
RUN cp -rn /home/runner/work/lampac/lampac/* /app/ 2>/dev/null || :
RUN cp -rn /* /app/ 2>/dev/null || :

# 3. Репозиторий плагинов
RUN mkdir -p /app/module && \
    echo 'repositories:\n  - name: "Lampac"\n    url: "https://lampac.sh"' > /app/module/repository.yaml

# 4. Конфиг
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
}' > /app/init.conf

# Даем права на запуск самого файла Lampac (без расширения) и на конфиги
RUN chmod +x /app/Lampac 2>/dev/null || :
RUN chmod -R 777 /app/init.conf /app/module

# Среда
ENV DOTNET_GCHeapHardLimit=1C000000
ENV PORT=8080 
EXPOSE 8080

# 5. ЗАПУСК БЕЗ DOTNET
# Мы ищем файл Lampac (исполняемый) и запускаем его напрямую
ENTRYPOINT ["sh", "-c", "exec $(find / -name Lampac -type f -not -name '*.*' | head -n 1) --urls http://0.0.0.0:8080"]
