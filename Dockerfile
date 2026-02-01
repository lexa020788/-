# --- Этап 1: Сборка ---
FROM ://mcr.microsoft.com AS build-env
WORKDIR /app

# Копируем файлы и собираем приложение
COPY . .
RUN dotnet publish -c Release -o output

# --- Этап 2: Финальный образ ---
FROM debian:12
WORKDIR /app

# Устанавливаем системные библиотеки
RUN apt-get update && apt-get install -y \
    libicu72 \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Копируем среду выполнения и результат сборки
COPY --from=://mcr.microsoft.com /usr/share/dotnet /opt/dotnet
COPY --from=build-env /app/output .

# Настройка путей
ENV PATH="${PATH}:/opt/dotnet"
ENV DOTNET_ROOT=/opt/dotnet

# Команда запуска
CMD ["dotnet", "Lampac.dll"]
