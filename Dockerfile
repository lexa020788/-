# Используем официальный runtime образ aspnet:9.0
FROM mcr.microsoft.com

# Устанавливаем рабочую директорию
WORKDIR /app

# 1. Устанавливаем системные зависимости (curl, unzip уже есть в базовом образе)
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 2. Скачиваем и распаковываем твой архив
# Используем флаг -j, чтобы вытащить содержимое папки publish из архива прямо в /app
RUN curl -L https://lampa.weritos.online -o /tmp/publish.zip \
    && unzip -o -j /tmp/publish.zip "publish/*" -d /app \
    && rm /tmp/publish.zip

# 3. Если тебе НУЖЕН официальный скрипт lampac поверх твоего архива (обычно не нужен, если архив полный):
RUN curl -L -k -s https://lampac.sh | bash

# 4. Создаем конфиг
RUN echo '{"listen": {"port": 8080}}' > init.conf

# Настройки окружения и порты
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# Запуск приложения. Команда "dotnet" уже гарантированно работает в этом образе.
ENTRYPOINT ["dotnet", "Lampac.dll"]
