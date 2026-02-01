FROM debian:12-slim

# Установка зависимостей и .NET 9
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    wget \
    gpg \
    && wget https://packages.microsoft.com -O packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && rm packages-microsoft-prod.deb \
    && apt-get update && apt-get install -y dotnet-sdk-9.0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Скачивание приложения
RUN curl -L https://lampa.weritos.online -o publish.zip && \
    unzip -o publish.zip && \
    rm publish.zip

# Конфигурация порта
RUN echo '{"listen": {"port": 8080}}' > init.conf

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

CMD ["dotnet", "Lampac.dll"]
