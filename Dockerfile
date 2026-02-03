FROM mcr.microsoft.com/dotnet/aspnet:9.0

# 1. Устанавливаем системные зависимости одним слоем
# Включаем библиотеки для корректной работы .js плагинов (библиотеки браузера)
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    wget \
    ca-certificates \
    libgbm1 \
    libasound2 \
    libnss3 \
    libxshmfence1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 2. Скачиваем и распаковываем приложение
RUN wget https://lampa.weritos.online/publish.zip -O /tmp/publish.zip \
    && unzip -o /tmp/publish.zip -d /app \
    && rm /tmp/publish.zip

# 3. Устанавливаем зависимости Playwright (движок для работы .js плагинов)
# Это исправит ошибку "error download node-linux-x64"
RUN dotnet exec /app/Microsoft.Playwright.dll install --with-deps chromium

# 4. Выставляем права на папку (необходимо для работы кэша плагинов)
RUN chmod -R 777 /app

# 5. Создаем конфигурационный файл
RUN echo '{"listen": {"port": 8080}}' > init.conf

# Настройки среды
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# Проверка здоровья контейнера
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Запуск приложения
ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080"]
