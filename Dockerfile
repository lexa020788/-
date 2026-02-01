FROM dotnet/sdk:9.0

RUN apt-get update && apt-get install -y unzip curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN curl -L https://lampa.weritos.online -o publish.zip \
    && unzip -o publish.zip \
    && rm publish.zip

RUN echo '{"listen": {"port": 8080}}' > init.conf

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

CMD ["dotnet", "Lampac.dll"]
