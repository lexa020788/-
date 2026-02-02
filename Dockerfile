FROM ubuntu:22.04

# 1. Устанавливаем базовые зависимости
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 2. Добавляем репозиторий Microsoft и ставим .NET 9 напрямую
RUN curl -sSL https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -o prod.deb \
    && dpkg -i prod.deb \
    && rm prod.deb \
    && apt-get update \
    && apt-get install -y dotnet-sdk-9.0

WORKDIR /app

# 3. Качаем Lampac
# 3. Качаем Lampac (ссылка Lampa MX/официальный репо)
RUN curl -fL https://github.com -o publish.zip \
    && unzip -o publish.zip \
    && rm publish.zip

# Конфиг порта
RUN echo '{"listen": {"port": 8080}}' > init.conf

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

CMD ["dotnet", "Lampac.dll"]
