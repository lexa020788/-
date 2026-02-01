# Используем базовый образ .NET Core Runtime
FROM mcr.microsoft.com/dotnet/runtime:9.0 AS base

# Рабочая директория
WORKDIR /app

# Копируем файлы приложения внутрь образа
COPY publish.zip .

# Распаковка архива
RUN unzip -o publish.zip && \\
    cmd publish.zip

# Устанавливаем необходимые зависимости
RUN apt-get update && \\
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \\
    curl \\
    libgtk-3-dev \\
    libxss-dev \\
    libasound2 \\
    libgdk-pixbuf2.0-dev \\
    libnspr4 \\
    libatk1.0-0 \\
    xvfb \\
    libnss3 \\
    libatk-bridge2.0-0 \\
    libdrm-dev \\
    libxkbcommon-dev \\
    libxcomposite-dev \\
    libxdamage-dev \\
    libxrandr-dev \\
    libgbm-dev \\
    libasound2-dev \\
    libpangocairo-1.0-0 \\
    libpango-1.0-0 \\
    libcairo2-dev && \\
    rm -rf /var/lib/apt/lists/*

# Настраиваем порт слушателя (стандартный порт для приложений на Koyeb - 8080)
RUN echo '{"listen": {"port": 8080}}' > init.conf

# Объявляем точку входа и команду запуска
ENTRYPOINT ["dotnet", "Lampac.dll"]

# Открываем порт для внешнего доступа
EXPOSE 8080
