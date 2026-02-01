FROM debian:12-slim
WORKDIR /app

# Устанавливаем только рантайм зависимости
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    libicu72 \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Копируем файлы из вашего репозитория в контейнер
COPY . .

# Koyeb требует, чтобы приложение слушало порт 8080
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# Запуск через встроенный бинарник или dotnet, если он есть в папке
# Если в папке есть файл "Lampac", запускаем его напрямую:
CMD ["chmod", "+x", "./Lampac"]
CMD ["./Lampac"]
