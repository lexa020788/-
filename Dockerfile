# Стейдж 1: Подготовка TorrServer и Lampac
FROM alpine:latest AS fetcher
RUN apk add --no-cache curl unzip

# Скачиваем TorrServer
RUN curl -L -o /torrserver https://github.com && \
    chmod +x /torrserver

# Скачиваем Lampac (скомпилированную версию)
RUN curl -L -o /app.zip https://github.com && \
    mkdir /lampac && unzip /app.zip -d /lampac

# Стейдж 2: Финальный образ
FROM node:20-slim
WORKDIR /app

# Устанавливаем ffmpeg для работы видео-движков
RUN apt-get update && apt-get install -y ffmpeg && rm -rf /var/lib/apt/lists/*

# Копируем всё из первого стейджа
COPY --from=fetcher /torrserver /usr/bin/torrserver
COPY --from=fetcher /lampac ./

# Настройки портов
ENV PORT=8080
ENV TS_PORT=8090
EXPOSE 8080
EXPOSE 8090

# Создаем скрипт запуска
RUN echo '#!/bin/sh\n\
/usr/bin/torrserver -p 8090 -d /app/db &\n\
node index.js\n\
' > /app/start.sh && chmod +x /app/start.sh

CMD ["/app/start.sh"]
