#!/bin/bash
mkdir -p /config/prowlarr

# Записываем конфигурацию Prowlarr с фиксированным API-ключом
echo '<Config><Port>9696</Port><ApiKey>1234567890abcdef1234567890abcdef</ApiKey><AuthenticationMethod>External</AuthenticationMethod><AuthenticationHandler>Forms</AuthenticationHandler></Config>' > /config/prowlarr/config.xml

# ЗАПУСК PROWLARR (Исправлен путь к бинарнику в образе linuxserver)
/app/prowlarr/bin/Prowlarr -nobrowser -data=/config &

echo "[Koyeb] Ожидание инициализации Prowlarr API..."
until curl -s -f -H "X-Api-Key: 1234567890abcdef1234567890abcdef" http://127.0.0 > /dev/null; do
    sleep 2
done

API_URL="http://127.0.0"
HEADERS=(-H "Content-Type: application/json" -H "X-Api-Key: 1234567890abcdef1234567890abcdef")

# Подключаем бесплатный HTTP-прокси Антизапрета прямо внутрь Prowlarr для обхода Cloudflare
echo "[Koyeb] Настройка путей обхода для трекеров..."
curl -s -X POST "${HEADERS[@]}" -d '{"name":"Antizapret","fields":[{"name":"host","value":"proxy.antizapret.prostovpn.org"},{"name":"port","value":3128}],"implementation":"Http","configContract":"HttpProxySettings"}' "http://127.0.0" > /dev/null

# Автоматически добавляем проверенные трекеры в вашу личную систему
echo "[Koyeb] Добавление встроенных трекеров..."
curl -s -X POST "${HEADERS[@]}" -d '{"name":"Rutor","enable":true,"protocol":"torrent","implementation":"Rutor","configContract":"RutorSettings","fields":[{"name":"baseUrl","value":"https://rutor.info"}]}' "$API_URL" > /dev/null
curl -s -X POST "${HEADERS[@]}" -d '{"name":"Kinozal","enable":true,"protocol":"torrent","implementation":"Kinozal","configContract":"KinozalSettings","fields":[{"name":"baseUrl","value":"https://kinozal.tv"}]}' "$API_URL" > /dev/null
curl -s -X POST "${HEADERS[@]}" -d '{"name":"Rutracker","enable":true,"protocol":"torrent","implementation":"Rutracker","configContract":"RutrackerSettings","fields":[{"name":"baseUrl","value":"https://rutracker.org"}]}' "$API_URL" > /dev/null
curl -s -X POST "${HEADERS[@]}" -d '{"name":"1337x","enable":true,"protocol":"torrent","implementation":"ThirteenThreeSevenX","configContract":"ThirteenThreeSevenXSettings","fields":[{"name":"baseUrl","value":"https://1337x.to"}]}' "$API_URL" > /dev/null
curl -s -X POST "${HEADERS[@]}" -d '{"name":"The Pirate Bay","enable":true,"protocol":"torrent","implementation":"ThePirateBay","configContract":"ThePirateBaySettings","fields":[{"name":"baseUrl","value":"https://thepiratebay.org"}]}' "$API_URL" > /dev/null

echo "[Koyeb] Все системы запущены. Передаем управление Node.js..."
exec node /app/server.js
