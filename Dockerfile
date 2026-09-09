# Берём готовый образ разработчика NextGen
FROM ghcr.io/lampac-nextgen/lampac:latest

# Перезаписываем init.conf, принудительно выставляя "enable": false для chromium
RUN echo '{ \
  "listen": {"port": 9118}, \
  "server": {"host": "0.0.0.0", "allow_cors": true}, \
  "lowMemoryMode": true, \
  "chromium": { "enable": false } \
}' > /lampac/init.conf

# Зажимаем .NET 10 в тиски (9500000 HEX = 156 МБ кучи)
ENV DOTNET_GCHeapHardLimit=9500000
ENV DOTNET_GCThreadCount=1
ENV DOTNET_GCLargeObjectHeapCompaction=1

# Открываем стандартный порт Лампака наружу
EXPOSE 9118
