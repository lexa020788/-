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

ENV PATH="/usr/lib/dotnet:$PATH"
# WORKDIR /app  <-- Закомментируйте или удалите эту строку
# ...

# Убедитесь, что dotnet runtime установлен выше в Dockerfile (например, apt-get install -y dotnet-runtime-6.0)

# Изменяем рабочую директорию на ту, куда устанавливается Lampac
WORKDIR /home/lampac

# 3. Скачиваем и устанавливаем Lampac с помощью официального скрипта
RUN curl -L -k -s https://lampac.sh | bash

# Конфиг порта
RUN echo '{"listen": {"port": 8080}}' > init.conf

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# 4. Используем относительный путь для запуска dotnet (предполагая, что dotnet в PATH)
CMD ["dotnet", "Lampac.dll"]
