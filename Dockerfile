FROM ubuntu:22.04

# Устанавливаем .NET 9 и зависимости
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    wget \
    dotnet-sdk-9.0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Скачиваем Lampac
RUN wget https://lampa.weritos.online && \
    unzip -o publish.zip && \
    rm publish.zip

# Конфиг на порт 8080 (обязательно для Koyeb)
RUN echo '{"listen": {"port": 8080}}' > init.conf

# Настройки среды
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# Запуск
CMD ["dotnet", "Lampac.dll"]
