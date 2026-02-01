FROM debian:12

ENV DEST="/home/lampac"
ENV DOTNET_ROOT="/opt/dotnet"
ENV PATH="$PATH:/opt/dotnet"
WORKDIR $DEST

# 1. Ставим только базовые пакеты и ca-certificates для curl
RUN apt-get update && apt-get install -y \
    curl unzip ca-certificates libicu-dev \
    libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
    libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 \
    libgbm1 libasound2 libpango-1.0-0 libcairo2 \
    && rm -rf /var/lib/apt/lists/*

# 2. Скачиваем .NET 9 бинарно (прямая ссылка)
RUN curl -L https://download.visualstudio.microsoft.com -o dotnet.tar.gz \
    && mkdir -p /opt/dotnet \
    && tar -zxf dotnet.tar.gz -C /opt/dotnet \
    && rm dotnet.tar.gz \
    && ln -s /opt/dotnet/dotnet /usr/bin/dotnet

# 3. Скачиваем Lampac
RUN curl -L -k -o publish.zip https://lampa.weritos.online \
    && unzip -o publish.zip \
    && rm -f publish.zip

# 4. Конфиг под порт 8080 (стандарт Koyeb)
RUN echo '{"listen": {"port": 8080}}' > init.conf
RUN mkdir -p data && echo -n "1" > data/vers-minor.txt

EXPOSE 8080

CMD ["dotnet", "Lampac.dll"]
