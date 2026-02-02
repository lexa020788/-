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

# Устанавливаем рабочую директорию, куда был установлен Lampac скриптом
WORKDIR /home/lampac

# ...

# 4. Используем относительный путь для запуска dotnet
CMD ["dotnet", "Lampac.dll"]
