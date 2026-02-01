# 1. Сборка
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build-env
WORKDIR /app
COPY . .
# Самодостаточная публикация под Linux x64 (стандарт Koyeb)
RUN dotnet publish -c Release -o output -r linux-x64 --self-contained false

# 2. Финальный образ (используем готовый aspnet, чтобы не ставить зависимости вручную)
FROM ://mcr.microsoft.com
WORKDIR /app

# Установка доп. библиотек, которые часто нужны Lampac
RUN apt-get update && apt-get install -y --no-install-recommends \
    libicu-dev \
    libssl-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build-env /app/output .

# ВАЖНО: Lampac должен слушать 0.0.0.0, а не localhost
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

CMD ["dotnet", "Lampac.dll"]

