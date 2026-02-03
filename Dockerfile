FROM mcr.microsoft.com/dotnet/aspnet:9.0


# 1. Устанавливаем базовые зависимости
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    ca-certificates \
&& rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y wget unzip \
&& wget https://lampa.weritos.online/publish.zip -O /tmp/publish.zip \
&& unzip /tmp/publish.zip -d /app\
&& rm /tmp/publish.zip \
&& apt-get purge -y wget unzip && apt-get autoremove -y

# ... (остальной код остается без изменений)

# ... (весь остальной код выше остается как был)

WORKDIR /app

# Скачиваем скрипт, делаем исполняемым и запускаем.
# Флаг -s в скрипте обычно позволяет указать директорию, но мы просто переместим содержимое.
# ... (начало оставляем как есть до шага 3)

# Устанавливаем зависимости и распаковываем архив (уже работает у вас)
RUN apt-get update && apt-get install -y wget unzip curl ca-certificates && \
    wget https://lampa.weritos.online/publish.zip -O /tmp/publish.zip && \
    unzip -o /tmp/publish.zip -d /app && \
    rm /tmp/publish.zip
    
# Устанавливаем Node.js и npm (необходимы для установщика Playwright CLI)
RUN apt-get update && apt-get install -y nodejs npm && \
    npm install -g npm 

# Устанавливаем глобальный Playwright CLI
RUN npm install -g playwright-cli

# Устанавливаем все браузеры (Chromium, Firefox, WebKit) вместе с системными зависимостями
# Это гарантирует, что все apt-пакеты будут установлены
RUN playwright install --with-deps

# Очищаем кэш apt для уменьшения размера образа
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Создаем конфиг
RUN echo '{"listen": {"port": 8080}}' > init.conf

# Настройки среды
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# Проверка здоровья (используем curl, который установили выше)
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
CMD curl -f http://localhost:8080/ || exit 1

ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080"]
