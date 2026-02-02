FROM ubuntu:22.04

# 1. Устанавливаем базовые зависимости
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Установка dotnet runtime 9.0 и скачивание архива одним слоем
RUN apt-get update && apt-get install -y wget unzip ca-certificates \
    && wget https://packages.microsoft.com -O prod.deb \
    && dpkg -i prod.deb && rm prod.deb \
    && apt-get update && apt-get install -y dotnet-runtime-9.0 \
    && wget https://lampa.weritos.online/publish.zip -O /tmp/publish.zip \
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
