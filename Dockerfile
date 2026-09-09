# Берём готовый образ разработчика
FROM ghcr.io/lampac-nextgen/lampac:latest

# Переменные для жесткого ограничения .NET 10 (9500000 HEX = 156 МБ кучи)
ENV DOTNET_GCHeapHardLimit=9500000
ENV DOTNET_GCThreadCount=1
ENV DOTNET_GCLargeObjectHeapCompaction=1

# Отключаем Chromium прямо в конфиге ядра
RUN echo '{ \
  "listen": {"port": 9118}, \
  "server": {"host": "0.0.0.0", "allow_cors": true}, \
  "lowMemoryMode": true, \
  "chromium": { "enable": false } \
}' > /lampac/init.conf

# Создаем скрипт-прослойку, который создаст токен перед запуском ядра
RUN echo '#!/bin/sh\n\
if [ -n "$LAMPAC_TOKEN" ]; then\n\
  mkdir -p /lampac/system/config\n\
  echo "{\\"accsdb\\": {\\"enable\\": true, \\"requestKey\\": true, \\"accounts\\": {\\"$LAMPAC_TOKEN\\": \\"2040-01-01\\"坚}}}" > /lampac/system/config/accsdb.json\n\
fi\n\
exec /lampac/Core --urls http://0.0.0\n\
' > /lampac/run.sh && chmod +x /lampac/run.sh

EXPOSE 9118
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/lampac/run.sh"]
