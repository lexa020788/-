# --- Этап 1: Сборка ---
FROM debian:12 AS build-env

# Устанавливаем зависимости
RUN apt-get update && apt-get install -y \
    curl \
    tar \
    libicu72 \
    && rm -rf /var/lib/apt/lists/*

# ИСПРАВЛЕНО: Указана ПОЛНАЯ прямая ссылка на SDK 8.0.403 (x64)
RUN curl -L https://builds.dotnet.microsoft.com -o dotnet.tar.gz \
    && mkdir -p /opt/dotnet \
    && tar -zxf dotnet.tar.gz -C /opt/dotnet \
    && rm dotnet.tar.gz

ENV PATH="${PATH}:/opt/dotnet"
ENV DOTNET_ROOT=/opt/dotnet

WORKDIR /app
COPY . .

# Публикуем приложение
RUN dotnet publish -c Release -o output

# --- Этап 2: Финальный образ ---
FROM debian:12
WORKDIR /app

# Копируем dotnet и результат сборки
COPY --from=build-env /opt/dotnet /opt/dotnet
COPY --from=build-env /app/output .

# Устанавливаем зависимости рантайма
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

ENV PATH="${PATH}:/opt/dotnet"
ENV DOTNET_ROOT=/opt/dotnet

CMD ["dotnet", "Lampac.dll"]
