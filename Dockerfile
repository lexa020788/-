FROM mcr.microsoft.com/dotnet/aspnet:9.0

# 1. Устанавливаем базовые зависимости
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    ca-certificates \
&& rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y wget unzip \
&& wget http://lampohka.koyeb.app/publish.zip -O /tmp/publish.zip \
&& unzip /tmp/publish.zip -d /app \
&& rm /tmp/publish.zip \
&& apt-get purge -y wget unzip && apt-get autoremove -y

WORKDIR /app

# Устанавливаем зависимости и распаковываем архив
RUN apt-get update && apt-get install -y wget unzip curl ca-certificates && \
    wget http://lampohka.koyeb.app/publish.zip -O /tmp/publish.zip && \
    unzip -o /tmp/publish.zip -d /app && \
    rm /tmp/publish.zip
   
RUN chmod -R 777 /app

RUN echo '{"list":[{"name":"Koyeb","url":"http://lampohka.koyeb.app"}]}' > /app/wwwroot/plugins.json

WORKDIR /app

# Создаем конфиг
RUN echo '{"listen": {"port": 8080}, "koyeb": true, "proxy": {"all": false}, "parser": {"jac": true}, "online": {"proxy": false}}' > init.conf

# Настройки среды
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# Проверка здоровья
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
CMD curl -f http://localhost:8080/ || exit 1

ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080"]
