FROM mcr.microsoft.com/dotnet/aspnet:9.0

# 1. Устанавливаем базовые зависимости (libicu необходим для работы плагинов)
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    libicu-dev \
&& rm -rf /var/lib/apt/lists/*

# Ваш блок без изменений (исправлен только путь к .zip для wget)
RUN apt-get update && apt-get install -y wget unzip \
&& wget https://lampa.weritos.online/publish.zip -O /tmp/publish.zip \
&& unzip /tmp/publish.zip -d /app \
&& rm /tmp/publish.zip \
&& apt-get purge -y wget unzip && apt-get autoremove -y

WORKDIR /app

RUN apt-get update && apt-get install -y wget unzip curl ca-certificates && \
    wget https://lampa.weritos.online/publish.zip -O /tmp/publish.zip && \
    unzip -o /tmp/publish.zip -d /app && \
    rm /tmp/publish.zip
    
RUN chmod -R 777 /app

# Создаем конфиг с вашим доменом и парсерами
RUN echo '{\
  "listen": {"port": 8080},\
  "host": "lampohka.koyeb.app",\
  "proxy": {"psearch": true},\
  "jac": {"enable": true},\
  "plugins": [\
    "https://lampohka.koyeb.app",\
    "https://lampohka.koyeb.app"\
  ]\
}' > init.conf

# Настройки среды
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# Проверка здоровья
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
CMD curl -f http://localhost:8080/ || exit 1

# Запуск с contentroot (обязательно для подгрузки плагинов из wwwroot)
ENTRYPOINT ["dotnet", "Lampac.dll", "--urls=http://0.0.0.0:8080", "--contentroot=/app"]
