# Стейдж 1: Скачиваем TorrServer
FROM alpine:latest AS downloader
RUN apk add --no-cache curl
RUN curl -L -o /torrserver https://github.com
RUN chmod +x /torrserver

# Стейдж 2: Основное приложение (Lampac)
FROM node:20.18.0-slim

WORKDIR /app

# Устанавливаем системные зависимости
RUN apt-get update && apt-get install -y ffmpeg curl && rm -rf /var/lib/apt/lists/*

# Копируем TorrServer
COPY --from=downloader /torrserver /usr/bin/torrserver

# Копируем файлы проекта
COPY package.json yarn.lock* ./
RUN yarn install --production --frozen-lockfile
COPY . .

# Настройки портов
ENV PORT=8080
ENV NODE_ENV=production
ENV TS_PORT=8090
EXPOSE 8080
EXPOSE 8090

# Скрипт запуска двух сервисов сразу
RUN echo '#!/bin/sh\n\
/usr/bin/torrserver -p 8090 -d /app/db &\n\
node server.js\n\
' > /app/start.sh && chmod +x /app/start.sh

CMD ["/app/start.sh"]
