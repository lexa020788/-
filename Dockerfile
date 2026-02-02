FROM ubuntu:22.04

# 1. Устанавливаем базовые зависимости
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y wget unzip \
    && wget https://lampa.weritos.online/publish.zip -O /tmp/publish.zip \
    && unzip /tmp/publish.zip -d /app \
    && rm /tmp/publish.zip \
    && apt-get purge -y wget unzip && apt-get autoremove -y

WORKDIR /app

# 3. Скачиваем и устанавливаем Lampac с помощью официального скрипта
RUN curl -L -k -s https://lampac.sh/home | bash

# Конфиг порта
RUN echo '{"listen": {"port": 8080}}' > init.conf

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

CMD ["dotnet", "Lampac.mx"]
