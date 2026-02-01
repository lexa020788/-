FROM debian:12

ENV DEST="/home/lampac"
ENV DOTNET_ROOT="/usr/share/dotnet"
ENV PATH="$PATH:$DOTNET_ROOT"
WORKDIR $DEST

# 1. Установка базовых зависимостей
RUN apt-get update && apt-get install -y \
    curl unzip ca-certificates libicu72 libssl3 \
    libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
    libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 \
    libgbm1 libasound2 libpango-1.0-0 libcairo2 \
    && rm -rf /var/lib/apt/lists/*

# 2. Ручная установка .NET 9 (бинарники напрямую)
RUN curl -L https://dot.net -o dotnet-install.sh \
    && chmod +x dotnet-install.sh \
    && ./dotnet-install.sh --channel 9.0 --runtime aspnetcore --install-dir $DOTNET_ROOT \
    && ln -s $DOTNET_ROOT/dotnet /usr/bin/dotnet \
    && rm dotnet-install.sh

# 3. Скачивание Lampac
RUN curl -L -k -o publish.zip https://lampa.weritos.online \
    && unzip -o publish.zip \
    && rm -f publish.zip

# 4. Конфиг (порт 8080 для Koyeb)
RUN echo '{"listen": {"port": 8080}}' > init.conf
RUN mkdir -p data && echo -n "1" > data/vers-minor.txt

EXPOSE 8080

CMD ["dotnet", "Lampac.dll"]
