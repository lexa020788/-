# Берём официальный готовый образ NextGen от разработчика
FROM ghcr.io/lampac-nextgen/lampac:latest

# Отключаем Chromium на корню
ENV web_chromium=false

# Жесткие системные тиски для .NET 10 (9500000 в HEX = ровно 156 МБ кучи)
ENV DOTNET_GCHeapHardLimit=9500000
ENV DOTNET_GCThreadCount=1
ENV DOTNET_GCLargeObjectHeapCompaction=1

# Открываем стандартный порт Лампака наружу
EXPOSE 9118
