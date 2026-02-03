FROM mcr.microsoft.com/dotnet/aspnet:9.0

# 1. Устанавливаем системные зависимости для Node.js и Playwright
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    ca-certificates \
    libgbm1 \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    && rm -rf /var/lib/apt/lists/*

# 2. Устанавливаем Node.js (необходим для работы JS плагинов через Playwright)
RUN curl -fsSL https://deb.nodesource.com | bash - && \
    apt-get install -y nodejs

WORKDIR /app

# 3. Скачиваем и распаковываем Lampac
RUN apt-get update && apt-get install -y wget && \
    wget https://lampa.weritos.online/publish.zip -O /tmp/publish.zip && \
    unzip -o /tmp/publish.zip -d /app && \
    rm /tmp/publish.zip && \
    apt-get purge -y wget && apt-get autoremove -y

# 4. Выставляем права (Playwright будет создавать папку .playwright здесь)
RUN chmod -R 777 /app

# Настройки среды
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# Создаем конфиг
RUN echo '{"listen": {"port": 8080}}' > init.conf

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
CMD curl -f http://localhost:8080/ || exit 1

ENTRYPOINT ["dotnet", "Lampac.dll"]
