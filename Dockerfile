FROM mcr.microsoft.com/dotnet/aspnet:9.0

# 1. Устанавливаем базовые зависимости
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    ca-certificates \
&& rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y wget unzip \
&& wget https://lampa.weritos.online/publish.zip -O /tmp/publish.zip \
&& unzip /tmp/publish.zip -d /app \
&& rm /tmp/publish.zip \
&& apt-get purge -y wget unzip && apt-get autoremove -y

WORKDIR /app

# Устанавливаем зависимости и распаковываем архив
RUN apt-get update && apt-get install -y wget unzip curl ca-certificates && \
    wget https://lampa.weritos.online/publish.zip -O /tmp/publish.zip && \
    unzip -o /tmp/publish.zip -d /app && \
    rm /tmp/publish.zip
   
RUN chmod -R 777 /app

# 1. Создаем расширенный конфиг (включаем все встроенные парсеры)
RUN echo '{"listen":{"port":8080},"koyeb":true,"api":{"host":"lampohka.koyeb.app"},"parser":{"jac":true,"eth":true,"proxy":true},"online":{"proxy":true},"proxy":{"all":true}}' > /app/init.conf

# 2. Создаем файл плагинов (обязательно в wwwroot)
RUN mkdir -p /app/wwwroot && echo '{"list":[{"name":"Koyeb.Bundle","url":"http://lampohka.koyeb.app"}]}' > /app/wwwroot/plugins.json

# 3. Принудительно создаем тот самый koyeb.js, чтобы он отдавал настройки парсеров
RUN echo 'window.lampa_settings = { "parser_use": true, "parser_host": "http://lampohka.koyeb.app" };' > /app/wwwroot/plugins/koyeb.js

# Настройки среды
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# Запуск с флагом обновления модулей (чтобы докачались DLL источников)
ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080", "--update=true"]
