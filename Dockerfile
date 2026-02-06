# 1. Используем официальный образ (в нем Lampac уже установлен в корень /)
FROM --platform=linux/amd64 ghcr.io/lampac-talks/lampac:amd64

# Устанавливаем зависимости (важно для парсеров и утилит)
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    libicu-dev \
&& rm -rf /var/lib/apt/lists/*

# 2. Настраиваем репозиторий плагинов
# В этом образе корень приложения — это /
RUN mkdir -p /module && \
    echo 'repositories:\n  - name: "Lampac"\n    url: "https://lampac.sh"' > /module/repository.yaml

# 3. ВАШ НОВЫЙ КОНФИГ init.conf (создаем его в корне /)
RUN echo '{\
  "listenport": 9120, \
  "dlna": {\
    "downloadSpeed": 25000000 \
  },\
  "Rezka": {\
    "streamproxy": true \
  },\
  "Zetflix": {\
    "displayname": "Zetflix - 1080p", \
    "geostreamproxy": ["UA"], \
    "apn": "http://apn.cfhttp.top"\
  },\
  "Kodik": {\
    "useproxy": true, \
    "proxy": {\
      "list": [\
        "socks5://91.1.1.1:5481", \
        "91.2.2.2:5481" \
      ]\
    }\
  },\
  "Ashdi": {\
    "useproxy": true \
  },\
  "Filmix": {\
    "token": "protoken" \
  },\
  "PornHub": {\
    "enable": false \
  },\
  "proxy": {\
    "list": [\
      "93.3.3.3:5481"\
    ]\
  },\
  "globalproxy": [\
    {\
      "pattern": "\\\\.onion",\
      "list": [\
        "socks5://127.0.0.1:9050"\
      ]\
    }\
  ],\
  "overrideResponse": [\
    {\
      "pattern": "/msx/start.json",\
      "action": "file",\
      "type": "application/json; charset=utf-8",\
      "val": "myfile.json"\
    }\
  ]\
}' > /init.conf

# 4. Права доступа (только на нужные папки, чтобы не было ошибки Read-only file system)
RUN chmod 777 /init.conf && chmod -R 777 /module

# Настройки среды (Обновляем порт на 9120!)
ENV DOTNET_GCHeapHardLimit=1C000000 
ENV ASPNETCORE_URLS=http://+:9120
EXPOSE 9120

# 5. ФИНАЛЬНЫЙ ЗАПУСК (указываем путь от корня, где лежит DLL в этом образе)
ENTRYPOINT ["dotnet", "/Lampac.dll", "--urls=http://0.0.0.0:9120", "--contentroot=/"]
