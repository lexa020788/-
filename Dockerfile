# Используем Node.js как основу (Debian 12)
FROM node:20-bookworm

# Устанавливаем зависимости для .NET и системные библиотеки
RUN apt-get update && apt-get install -y \
    libicu-dev \
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
    wget \
    && rm -rf /var/lib/apt/lists/*

# Устанавливаем .NET 9 Runtime вручную
RUN wget https://dot.net -O dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --channel 9.0 --runtime aspnetcore && \
    ln -s /root/.dotnet/dotnet /usr/local/bin/dotnet && \
    rm dotnet-install.sh

# Проверка версий
RUN node -v && npm -v && dotnet --version
