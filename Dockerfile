# syntax=docker/dockerfile:1
FROM alpine:latest

WORKDIR /app

# Устанавливаем чистый Node.js и curl
RUN apk add --no-cache nodejs npm curl

# Копируем только сервер
COPY server.js /app/server.js

# Открываем порт для Koyeb
EXPOSE 8080

# Запускаем напрямую Node.js без посредников
CMD ["node", "/app/server.js"]
