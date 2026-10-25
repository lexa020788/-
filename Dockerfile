# syntax=docker/dockerfile:1
FROM linuxserver/prowlarr:latest

WORKDIR /app

# 1. Устанавливаем Node.js, curl, python3, pip, bash и ОБЯЗАТЕЛЬНО git для скачивания Solvearr
RUN apk add --no-cache \
    nodejs \
    npm \
    curl \
    python3 \
    py3-pip \
    bash \
    git

# 2. Устанавливаем Solvearr по полному корректному адресу репозитория
RUN pip3 install --break-system-packages solvearr

# 3. Копируем наш прокси-мост
COPY server.js /app/server.js

# 4. Скрипт автоматической настройки Prowlarr и привязки его к Solvearr
RUN mkdir -p /custom-cont-init.d && echo '#!/bin/bash\n\
mkdir -p /config/prowlarr\n\
echo "<Config><Port>9696</Port><ApiKey>1234567890abcdef1234567890abcdef</ApiKey><AuthenticationMethod>External</AuthenticationMethod><AuthenticationHandler>Forms</AuthenticationHandler></Config>" > /config/prowlarr/config.xml\n\
\n\
(\n\
  echo "[Koyeb Init] Ожидание запуска Prowlarr API..."\n\
  until curl -s -f -H "X-Api-Key: 1234567890abcdef1234567890abcdef" http://127.0.0 > /dev/null; do\n\
    sleep 3\n\
  done\n\
  \n\
  API_URL="http://127.0.0"\n\
  HEADERS=(-H "Content-Type: application/json" -H "X-Api-Key: 1234567890abcdef1234567890abcdef")\n\
  \n\
  echo "[Koyeb Init] Регистрируем локальный прокси Solvearr в Prowlarr..."\n\
  curl -s -X POST "${HEADERS[@]}" -d '"'"'{"name":"solvearr","fields":[{"name":"host","value":"http://127.0.0.1:8191"},{"name":"timeout","value":60}],"implementation":"FlareSolverr","configContract":"FlareSolverrSettings"}'"'"' "http://127.0.0" > /dev/null\n\
  \n\
  echo "[Koyeb Init] Добавляем русские и зарубежные трекеры..."\n\
  curl -s -X POST "${HEADERS[@]}" -d '"'"'{"name":"Rutor","enable":true,"protocol":"torrent","implementation":"Rutor","configContract":"RutorSettings","fields":[{"name":"baseUrl","value":"https://rutor.info"}]}'"'"' "$API_URL" > /dev/null\n\
  curl -s -X POST "${HEADERS[@]}" -d '"'"'{"name":"Rutracker","enable":true,"protocol":"torrent","implementation":"Rutracker","configContract":"RutrackerSettings","fields":[{"name":"baseUrl","value":"https://rutracker.org"}]}'"'"' "$API_URL" > /dev/null\n\
  curl -s -X POST "${HEADERS[@]}" -d '"'"'{"name":"Kinozal","enable":true,"protocol":"torrent","implementation":"Kinozal","configContract":"KinozalSettings","fields":[{"name":"baseUrl","value":"https://kinozal.tv"}]}'"'"' "$API_URL" > /dev/null\n\
  curl -s -X POST "${HEADERS[@]}" -d '"'"'{"name":"1337x","enable":true,"protocol":"torrent","implementation":"ThirteenThreeSevenX","configContract":"ThirteenThreeSevenXSettings","fields":[{"name":"baseUrl","value":"https://1337x.to"}]}'"'"' "$API_URL" > /dev/null\n\
  echo "[Koyeb Init] Все трекеры успешно заведены на локальный обходной путь!"\n\
) &\n\
' > /custom-cont-init.d/01-setup-trackers.sh && chmod +x /custom-cont-init.d/01-setup-trackers.sh

# 5. Демон автозапуска для Solvearr (порт 8191)
RUN mkdir -p /etc/services.d/solvearr && echo '#!/usr/bin/with-contenv bash\n\
exec python3 -m solvearr --port 8191\n\
' > /etc/services.d/solvearr/run && chmod +x /etc/services.d/solvearr/run

# 6. Демон автозапуска для нашего Node.js Proxy (порт 8080)
RUN mkdir -p /etc/services.d/node-server && echo '#!/usr/bin/with-contenv bash\n\
exec node /app/server.js\n\
' > /etc/services.d/node-server/run && chmod +x /etc/services.d/node-server/run

# Открываем внешний порт прокси-моста
EXPOSE 8080
