FROM debian:13-slim AS runner
WORKDIR /lampac
EXPOSE 9118

# Устанавливаем всё от root
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates chromium curl fontconfig libicu76 libnspr4 libnss3 \
    libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxcomposite1 \
    libxdamage1 libxext6 libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 libasound2 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Копируем файлы без ограничений прав
COPY --from=builder /out/lampac /lampac
COPY --from=builder /usr/share/dotnet /usr/share/dotnet

# Создаем конфиг (тоже от root)
RUN echo '{"listen":{"port":9118},"KnownProxies":[{"ip":"0.0.0.0","prefixLength":0}],"chromium":{"enable":true,"binary":"/usr/bin/chromium"}}' > /lampac/init.conf

# Даем полные права на запуск
RUN chmod +x /usr/bin/chromium && touch isdocker

ENV DOTNET_ROOT=/usr/share/dotnet \
    PATH="${PATH}:/usr/share/dotnet" \
    ASPNETCORE_URLS=http://0.0.0.0:9118

ENTRYPOINT ["/usr/share/dotnet/dotnet", "Core.dll", "--urls", "http://0.0.0.0:9118"]
