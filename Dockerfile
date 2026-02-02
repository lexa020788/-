FROM ubuntu:22.04

# 1. Устанавливаем базовые зависимости
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 2. Скачиваем и распаковываем твой архив, игнорируя внутреннюю папку publish
RUN curl -L https://lampa.weritos.online -o /tmp/publish.zip \
    && unzip -o -j /tmp/publish.zip "publish/*" -d /app \
    && rm /tmp/publish.zip

WORKDIR /app

# 3. Скачиваем и устанавливаем Lampac с помощью официального скрипта
RUN curl -L -k -s https://lampac.sh/home | bash

# Конфиг порта
RUN echo '{"listen": {"port": 8080}}' > init.conf

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

CMD ["dotnet", "Lampac.dll"]
