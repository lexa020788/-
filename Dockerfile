# 1. Оригинал
FROM --platform=linux/amd64 ghcr.io/lampac-talks/lampac:amd64

# Системные либы
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    libicu-dev \
&& rm -rf /var/lib/apt/lists/*

# Создаем свою рабочую директорию
WORKDIR /app

# 2. Пытаемся собрать файлы в кучу (на случай, если они раскиданы)
RUN cp -rn /home/runner/work/lampac/lampac/* /app/ 2>/dev/null || :
RUN cp -rn /*.dll /app/ 2>/dev/null || :

# 3. Репозиторий плагинов
RUN mkdir -p /app/module && \
    echo 'repositories:\n  - name: "Lampac"\n    url: "https://lampac.sh"' > /app/module/repository.yaml

# 4. Конфиг прямо в /app
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

# Настраиваем права только на то, что создали (как ты и просил)
RUN chmod -R 777 /app/init.conf /app/module

# Среда под Koyeb
ENV DOTNET_GCHeapHardLimit=1C000000 
ENV ASPNETCORE_URLS=http://+:8080
ENV PORT=8080 
EXPOSE 8080

# 5. ЗАПУСК через поиск
ENTRYPOINT ["sh", "-c", "dotnet $(find / -name Lampac.dll | head -n 1) --urls http://0.0.0.0:8080"]
