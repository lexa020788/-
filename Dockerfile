# СТЕНД 1: node-env (используется только для копирования бинарников Node.js)
FROM node:20-bookworm-slim AS node-env

# СТЕНД 2: base (ваш целевой образ .NET 9.0 ASP.NET)
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base

# Устанавливаем системные зависимости, перечисленные в исходном скрипте, через apt-get install
# Убедитесь, что пользователь имеет права root для установки системных пакетов
RUN apt-get update && apt-get install -y --no-install-recommends \
    librss3-dev libgtk-3-dev libxss-dev libasound2 \
    unzip curl libicu-dev libgdk-pixbuf2.0-dev libospr4 \
    libatk1.0-0 xvfb coreutils liboss3 libatk-bridge2.0-0 \
    libdrm-dev libxkbcommon-dev libxcomposite-dev libxdamage-dev \
    libxrandr-dev libgbm-dev libasound2-dev libpangocairo-1-0-0 \
    libpango-1.0-0 libcairo2-dev gnupg wget && \
    rm -rf /var/lib/apt/lists/*

# Копируем бинарники Node.js и npm из первого образа во второй
COPY --from=node-env /usr/local/bin/node /usr/local/bin/node
COPY --from=node-env /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/npm
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -s /usr/local/bin/node /usr/bin/node

# Дальнейшие шаги из вашего скрипта могут быть перенесены сюда вручную:
# Например, создание папки для приложения, копирование publish.zip и т.д.
# RUN mkdir -p /home/Lampac
# WORKDIR /home/Lampac
# RUN curl -O https://lampa.weritos.online/publish.zip && unzip publish.zip && rm publish.zip

# Проверка установки
RUN node -v && npm -v && dotnet --version

# Ваши финальные ENTRYPOINT / CMD

**Ключевые изменения:**
*   **Multi-stage build**: Добавлен первый этап `node-env` для получения Node.js.
*   **Копирование**: Используются команды `COPY --from=node-env` для переноса файлов Node.js и npm без установки через скрипты.
*   **Системные зависимости**: Все системные библиотеки устанавливаются через `apt-get install` одной командой, как того требует ваш исходный скрипт, но уже без bash.

Убедитесь, что вы **обновили ваш Dockerfile** в репозитории на этот вариант и запустили билд снова. Сообщите, если возникнут **новые ошибки** после этих изменений.
