FROM ubuntu:22.04

# Ставим зависимости для скрипта установки .NET
RUN apt-get update && apt-get install -y curl unzip icu-devtools && rm -rf /var/lib/apt/lists/*

# Официальный скрипт установки .NET (ставит всё сам без ошибок реестра)
RUN curl -sSL https://dot.net -o dotnet-install.sh \
    && chmod +x dotnet-install.sh \
    && ./dotnet-install.sh --channel 9.0 --install-dir /usr/share/dotnet \
    && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet

WORKDIR /app

# Качаем Lampac
RUN curl -L https://lampa.weritos.online -o publish.zip \
    && unzip -o publish.zip \
    && rm publish.zip

# Конфиг порта
RUN echo '{"listen": {"port": 8080}}' > init.conf

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

CMD ["dotnet", "Lampac.dll"]
