# Используем базовый образ Ubuntu для проверки подключения
FROM ubuntu:latest as base

# Устанавливаем еще раз Ubuntu для проверки второй стадии сборки
FROM ubuntu:latest AS build

WORKDIR /app

# Копируем все файлы из вашего репозитория в контейнер
COPY . . 

# Тут могли бы быть команды сборки, но мы их пропускаем

# Финальный образ
FROM base AS final

WORKDIR /app

# Копируем файлы из первой стадии
COPY --from=build /app .

# Запускаем от имени root
USER root

# Определяем путь (эти переменные тут не сработают, но синтаксис верен)
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright 

# Команда запуска сервера (эта команда выдаст ошибку, т.к. нет dotnet в ubuntu)
CMD ["dotnet", "Kouseu.dll"]
