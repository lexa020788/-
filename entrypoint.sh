#!/bin/bash
mkdir -p /config/prowlarr

# Записываем конфигурацию Prowlarr на порт 9696
echo '<Config><Port>9696</Port><ApiKey>1234567890abcdef1234567890abcdef</ApiKey><AuthenticationMethod>External</AuthenticationMethod><AuthenticationHandler>Forms</AuthenticationHandler></Config>' > /config/prowlarr/config.xml

# Запускаем Prowlarr (перенаправляем логи, чтобы они не забивали консоль Koyeb)
/app/prowlarr/bin/Prowlarr -nobrowser -data=/config > /dev/null 2>&1 &

echo "[Koyeb] Ожидание инициализации Prowlarr API на порту 9696..."
until curl -s -f -H "X-Api-Key: 1234567890abcdef1234567890abcdef" http://127.0.0 > /dev/null; do
    sleep 2
done

API_URL="http://127.0.0"
HEADERS=(-H "Content-Type: application/json" -H "X-Api-Key: 1234567890abcdef1234567890abcdef")

# Подключаем бесплатный HTTP-прокси Антизапрета
echo "[Koyeb] Настройка путей обхода для трекеров..."
curl -s -X POST "${HEADERS[@]}" -d '{"name":"Antizapret","fields":[{"name":"host","value":"proxy.antizapret.prostovpn.org"},{"name":"port","value":3128}],"implementation":"Http","configContract":"HttpProxySettings"}' "http://127.0.0" > /dev/null

# Автоматически добавляем трекеры
echo "[Koyeb] Добавление встроенных трекеров..."
curl -s -X POST "${HEADERS[@]}" -d '{"name":"Rutor","enable":true,"protocol":"torrent","implementation":"Rutor","configContract":"RutorSettings","fields":[{"name":"baseUrl","value":"https://rutor.info"}]}' "$API_URL" > /dev/null
curl -s -X POST "${HEADERS[@]}" -d '{"name":"Kinozal","enable":true,"protocol":"torrent","implementation":"Kinozal","configContract":"KinozalSettings","fields":[{"name":"baseUrl","value":"https://kinozal.tv"}]}' "$API_URL" > /dev/null
curl -s -X POST "${HEADERS[@]}" -d '{"name":"Rutracker","enable":true,"protocol":"torrent","implementation":"Rutracker","configContract":"RutrackerSettings","fields":[{"name":"baseUrl","value":"https://rutracker.org"}]}' "$API_URL" > /dev/null
curl -s -X POST "${HEADERS[@]}" -d '{"name":"1337x","enable":true,"protocol":"torrent","implementation":"ThirteenThreeSevenX","configContract":"ThirteenThreeSevenXSettings","fields":[{"name":"baseUrl","value":"https://1337x.to"}]}' "$API_URL" > /dev/null

echo "[Koyeb] Передаем управление Node.js на порт 8080..."
# Запускаем Node.js строго на порту 8080, который слушает внешняя сеть Koyeb
exec node /app/server.js 8080
