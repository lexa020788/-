FROM --platform=linux/amd64 ghcr.io/lampac-talks/lampac:amd64

RUN apt-get update && apt-get install -y curl ca-certificates libicu-dev && rm -rf /var/lib/apt/lists/*

# Лампак в этом образе работает из /home
WORKDIR /home

# Создаем структуру папок, которую он хочет
RUN mkdir -p /home/module && \
    echo 'repositories:\n  - name: "Lampac"\n    url: "https://lampac.sh"' > /home/module/repository.yaml

# Твой конфиг (я поменял в нем listenport на 8080, чтобы Koyeb был доволен)
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
  }\
}' > /home/init.conf

RUN chmod -R 777 /home/init.conf /home/module

# Настройки для Koyeb
ENV PORT=8080
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# Запуск напрямую, так как мы теперь точно знаем, что он в /home/Lampac
ENTRYPOINT ["./Lampac", "--urls", "http://0.0.0.0:8080"]
