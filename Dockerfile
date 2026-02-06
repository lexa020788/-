FROM --platform=linux/amd64 ghcr.io/lampac-talks/lampac:amd64

# Ставим только системные библиотеки (они легкие)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates libicu-dev \
    libnss3 libgbm1 libasound2 libatk-bridge2.0-0 libgtk-3-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /home

# Пропускаем npx playwright install здесь, чтобы не было таймаута при билде

RUN mkdir -p /home/module && \
    echo 'repositories:\n  - name: "Lampac"\n    url: "https://lampac.sh"' > /home/module/repository.yaml

# Ваш конфиг
RUN echo '{\
  "listenport": 9118, \
  "Rezka": { "streamproxy": true },\
  "Zetflix": { "displayname": "Zetflix - 1080p" },\
  "Kodik": { "useproxy": false },\
  "Ashdi": { "useproxy": true }\
}' > /home/init.conf

RUN chmod -R 777 /home/init.conf /home/module

ENV PORT=9118
EXPOSE 9118

ENTRYPOINT ["./Lampac", "--urls", "http://0.0.0.0:9118"]
