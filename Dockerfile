FROM ubuntu:22.04

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

ENV PATH="/usr/lib/dotnet:$PATH"
WORKDIR /app

# Скачиваем скрипт, делаем исполняемым и запускаем.
# Флаг -s в скрипте обычно позволяет указать директорию, но мы просто переместим содержимое.
# ... (начало оставляем как есть до шага 3)

# Устанавливаем зависимости и распаковываем архив (уже работает у вас)
RUN apt-get update && apt-get install -y wget unzip curl ca-certificates && \
    wget https://lampa.weritos.online/publish.zip -O /tmp/publish.zip && \
    unzip -o /tmp/publish.zip -d /app && \
    rm /tmp/publish.zip

WORKDIR /app

# Создаем конфиг
RUN echo '{"listen": {"port": 8080}}' > init.conf

# Настройки среды
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# Проверка здоровья (используем curl, который установили выше)
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

CMD ["dotnet", "Lampac.dll"]
