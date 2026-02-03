# Используем официальный образ Playwright с предустановленными браузерами
# Замените 'v1.57.0-noble' на актуальную версию, если знаете свою
FROM mcr.microsoft.com/playwright:v1.57.0-noble as base

# Устанавливаем .NET SDK для компиляции
FROM mcr.microsoft.com AS build

WORKDIR /app

# Копируем файлы проекта Kouseu (вам нужно их предоставить или скачать с репозитория)
COPY . . 

# Собираем проект
RUN dotnet publish "Kouseu.csproj" -c Release -o /app/publish

# Финальный образ
FROM base AS final

WORKDIR /app

# Копируем скомпилированное приложение из стадии build
COPY --from=build /app/publish .

# Запускаем приложение от имени root, чтобы избежать проблем с правами Playwright
USER root

# Определяем путь, который использует приложение (как на вашем скриншоте)
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright 

# Команда запуска сервера
CMD ["dotnet", "Kouseu.dll"]
