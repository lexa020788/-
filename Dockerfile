FROM ubuntu: 22.04

# 1. Устанавливаем базовые зависимости RUN apt-get update && apt-get install -y \ curl \ unzip \ ca-certificates && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y wget unzip

&& wget https://lampa.weritos.online/publish.zip -0 /tmp/publish.zip

&& unzip /tmp/publish.zip -d /app \

&& rm /tmp/publish.zip \

&& apt-get purge -y wget unzip && apt-get autoremove -y

ENV PATH="/usr/lib/dotnet:$PATH"

# ... (весь остальной код выше остается как был, с исправленной ссылкой на .zip)

WORKDIR /app

3. Скачиваем и устанавливаем Lampас с помощью официального скрипта

RUN curl -L -k -s https://lampac.sh

bash

# Конфиг порта

RUN echo '{"listen": {"port": 8080}}' > init.conf

ENV ASPNETCORE_URLS=http://+: 8080

EXPOSE 8080

# Используем абсолютный путь для запуска dotnet

CMD ["/usr/bin/dotnet","Lampac.dll"]
