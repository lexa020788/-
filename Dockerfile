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

# 3. Скачиваем и устанавливаем Lampac с помощью официального скрипта (устанавливает в /home/lampac)
RUN curl -L -k -s https://lampac.sh | bash

# Перемещаем все файлы из директории установки (/home/lampac) в рабочую директорию (/app)
RUN mv /home/lampac/* /app/

# Конфиг порта
RUN echo '{"listen": {"port": 8080}}' > init.conf

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# 4. Используем относительный путь для запуска dotnet (так как файлы теперь в /app)
CMD ["dotnet", "Lampac.dll"]
