# Runner image — берем уже готовый образ с установленным .NET 10
FROM ://microsoft.com AS runner
WORKDIR /lampac
EXPOSE 9118

# 1. Устанавливаем Chromium и зависимости (теперь без скачивания dotnet!)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    chromium \
    curl \
    fontconfig \
    libnspr4 \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libpango-1.0-0 \
    libasound2 \
    && ln -sf /usr/bin/chromium /usr/bin/chromium-browser \
    && ln -sf /usr/bin/chromium /lampac/chromium \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. Переменные окружения (путь к dotnet в этом образе стандартный)
ENV DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    CHROMIUM_PATH=/usr/bin/chromium \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    PLAYWRIGHT_BROWSERS_PATH=0 \
    CHROMIUM_FLAGS="--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage --disable-gpu"

# Копируем приложение
COPY --from=builder /out/lampac /lampac

# Запуск
ENTRYPOINT ["dotnet", "Core.dll", "--urls", "http://0.0.0"]
