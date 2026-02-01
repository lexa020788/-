# --- Этап 1: Сборка ---
# Используем зеркало Google для получения образа SDK
FROM mirror.gcr.io/microsoft/dotnet/sdk:8.0 AS build-env
WORKDIR /app

COPY . .
RUN dotnet publish -c Release -o output

# --- Этап 2: Финальный образ ---
FROM debian:12
WORKDIR /app

# Устанавливаем системные зависимости
RUN apt-get update && apt-get install -y \
    libicu72 \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Копируем рантайм из зеркалированного образа
COPY --from=mirror.gcr.io/microsoft/dotnet/runtime:8.0 /usr/share/dotnet /opt/dotnet
COPY --from=build-env /app/output .

ENV PATH="${PATH}:/opt/dotnet"
ENV DOTNET_ROOT=/opt/dotnet

CMD ["dotnet", "Lampac.dll"]
