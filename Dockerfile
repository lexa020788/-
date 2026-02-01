FROM mcr.microsoft.com AS build-env
WORKDIR /app

# Копируем всё содержимое репозитория
COPY . .

# Ищем любой файл .csproj в любой папке и собираем его
RUN dotnet publish $(find . -name "*.csproj" | head -n 1) -c Release -o output

FROM mcr.microsoft.com
WORKDIR /app

RUN apt-get update && apt-get install -y libicu-dev libssl-dev ca-certificates && rm -rf /var/lib/apt/lists/*

# Копируем результат сборки
COPY --from=build-env /app/output .

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# Запуск. Если Lampac.dll не в корне output, команда ниже его найдет
CMD ["sh", "-c", "dotnet $(find . -name Lampac.dll | head -n 1)"]
