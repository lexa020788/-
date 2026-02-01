FROM debian:12-slim

# Устанавливаем зависимости и .NET 9
RUN apt-get update && apt-get install -y curl unzip wget gpg \
    && wget https://packages.microsoft.com -O prod.deb \
    && dpkg -i prod.deb \
    && rm prod.deb \
    && apt-get update \
    && apt-get install -y dotnet-sdk-9.0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Скачиваем Lampac (ВАЖНО: ссылка должна быть с /publish.zip)
RUN curl -L https://lampa.weritos.online -o publish.zip \
    && unzip -o publish.zip \
    && rm publish.zip

# Создаем конфиг
RUN echo '{"listen": {"port": 8080}}' > init.conf

# Настройки порта для Koyeb
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

CMD ["dotnet", "Lampac.dll"]
