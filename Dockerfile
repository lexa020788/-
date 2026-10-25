# syntax=docker/dockerfile:1
FROM linuxserver/prowlarr:latest

WORKDIR /app

# 1. Устанавливаем Node.js, bash и curl (рабочий набор пакетов для Alpine)
RUN apk add --no-cache nodejs bash curl

# 2. Копируем файлы прокси-сервера и скрипта запуска из вашего репозитория
COPY server.js /app/server.js
COPY entrypoint.sh /app/entrypoint.sh

# 3. Даем права на выполнение скрипту запуска
RUN chmod +x /app/entrypoint.sh

# Открываем рабочий порт для плагина Lampa
EXPOSE 8080
ENTRYPOINT ["/app/entrypoint.sh"]
