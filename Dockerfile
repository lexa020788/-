# --- Этап 1: Сборка ---
FROM debian:12 AS build-env

# Устанавливаем зависимости для скачивания и работы .NET
RUN apt-get update && apt-get install -y \
    curl \
    tar \
    libicu72 \
    && rm -rf /var/lib/apt/lists/*

# Скачиваем ПРЯМУЮ ссылку на .NET 8 SDK
RUN curl -L https://dotnetcli.azureedge.net -o dotnet.tar.gz \
    && mkdir -p /opt/dotnet \
    && tar -zxf dotnet.tar.gz -C /opt/dotnet \
    && rm dotnet.tar.gz

# Добавляем dotnet в PATH, чтобы команда была доступна сразу
ENV PATH="${PATH}:/opt/dotnet"
ENV DOTNET_ROOT=/opt/dotnet

WORKDIR /app
COPY . .

# Публикуем приложение
RUN dotnet publish -c Release -o output

# --- Этап 2: Финальный образ ---
FROM debian:12
WORKDIR /app

# Копируем dotnet и опубликованное приложение из первого этапа
COPY --from=build-env /opt/dotnet /opt/dotnet
COPY --from=build-env /app/output .

# Устанавливаем зависимости для запуска Lampac
RUN apt-get update && apt-get install -y \
    libc6 \
    libgcc-s1 \
    libgssapi-krb5-2 \
    libicu72 \
    libssl3 \
    libstdc++6 \
    zlib1g \
    fontconfig \
    libfreetype6 \
    && rm -rf /var/lib/apt/lists/*

# Переменные окружения для работы dotnet в финальном образе
ENV PATH="${PATH}:/opt/dotnet"
ENV DOTNET_ROOT=/opt/dotnet

# Указываем команду запуска
CMD ["dotnet", "Lampac.dll"]
