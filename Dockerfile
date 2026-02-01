# Используем официальный образ .NET 9 для запуска
FROM mcr.microsoft.com

# Устанавливаем необходимые системные зависимости
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    libicu-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Скачиваем и распаковываем Lampac
# Koyeb требует, чтобы приложение слушало на порту 8080 (или через переменную PORT)
RUN curl -LO https://lampa.weritos.online && \
    unzip -o publish.zip && \
    rm publish.zip

# Создаем конфигурацию с портом 8080
RUN echo '{"listen": {"port": 8080}}' > init.conf

# Настройка переменных окружения для .NET
ENV ASPNETCORE_URLS=http://+:8080
ENV DOTNET_RUNNING_IN_CONTAINER=true

# Открываем порт
EXPOSE 8080

# Запуск приложения
CMD ["dotnet", "Lampac.dll"]
