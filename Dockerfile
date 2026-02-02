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
RUN curl -L -k -s https://lampac.sh > install.sh && \
    chmod +x install.sh && \
    ./install.sh && \
    # Перемещаем всё, включая скрытые файлы, и удаляем пустую папку
    cp -r /home/lampac/. /app/ && \
    rm -rf /home/lampac install.sh

# Конфиг порта (лучше создавать его сразу в /app)
RUN echo '{"listen": {"port": 8080}}' > /app/init.conf

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

CMD ["dotnet", "Lampac.dll"]
