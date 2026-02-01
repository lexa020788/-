# Используем образ mcr.microsoft.com/dotnet/sdk для сборки приложения
FROM mcr.microsoft.com/dotnet/sdk:latest AS build-env
WORKDIR /app

# Копируем файлы проекта и публикуем приложение
COPY . .
RUN dotnet publish -c Release -o output

# Используем образ mcr.microsoft.com/dotnet/aspnet для запуска приложения
FROM mcr.microsoft.com/dotnet/aspnet:latest
WORKDIR /app

# Устанавливаем необходимые зависимости
RUN apt-get update && \\
    apt-get install -y libicu-dev libssl-dev ca-certificates && \\
    rm -rf /var/lib/apt/lists/*

# Копируем опубликованное приложение из этапа сборки
COPY --from=build-env /app/output .

# Настраиваем переменную окружения и открываем порт
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# Запускаем приложение
CMD ["dotnet", "Lampac.dll"]
