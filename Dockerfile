FROM ubuntu:22.04

# Убираем интерактивные запросы при установке
ENV DEBIAN_FRONTEND=noninteractive
ENV DEST="/home/lampac"
WORKDIR $DEST

# Установка зависимостей и .NET 9
RUN apt-get update && apt-get install -y \
    curl unzip libicu-dev libnss3 libatk1.0-0 libatk-bridge2.0-0 \
    libcups2 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 \
    libxrandr2 libgbm1 libasound2 libpango-1.0-0 libcairo2 \
    && curl -sSL https://dot.net | bash /dev/stdin --channel 9.0 --runtime aspnetcore --install-dir /usr/share/dotnet \
    && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet

# Скачивание Lampac
RUN curl -L -k -o publish.zip https://lampa.weritos.online \
    && unzip -o publish.zip \
    && rm -f publish.zip

# Настройка конфига и порта
RUN echo '{"listen": {"port": 8080}}' > init.conf
RUN mkdir -p data && echo -n "1" > data/vers-minor.txt

EXPOSE 8080

# Запуск
CMD ["dotnet", "Lampac.dll"]
