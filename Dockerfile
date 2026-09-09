# Global ARGs
ARG DOTNET_VERSION=10.0.5
ARG DOTNET_SDK_VERSION=10.0.201

# --- Builder Stage ---
FROM --platform=$BUILDPLATFORM debian:13-slim AS builder
ARG BUILDARCH
ARG TARGETARCH
ARG DOTNET_SDK_VERSION
WORKDIR /build
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl xz-utils libicu76 git && rm -rf /var/lib/apt/lists/*
RUN git clone https://github.com/lampac-nextgen/lampac .
RUN case "$BUILDARCH" in \
  arm64) SDK_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-arm64.tar.gz" ;; \
  *) SDK_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-x64.tar.gz" ;; \
  esac && \
  curl -fSL -o /tmp/dotnet-sdk.tar.gz "${SDK_URL}" && \
  mkdir -p /usr/share/dotnet && tar -xzf /tmp/dotnet-sdk.tar.gz -C /usr/share/dotnet && rm /tmp/dotnet-sdk.tar.gz
RUN case "$TARGETARCH" in \
  arm64) RID=linux-arm64 ;; \
  *) RID=linux-x64 ;; \
  esac && \
  /usr/share/dotnet/dotnet publish --configuration Release --runtime "$RID" --output /out/lampac -p:Parallel=false Core/Core.csproj

# --- Runner Stage ---
FROM debian:13-slim AS runner
ARG TARGETARCH
ARG DOTNET_VERSION
WORKDIR /lampac
EXPOSE 7860

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl fontconfig libicu76 procps nginx tini python3 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Скачиваем и устанавливаем легковесный .NET Runtime вместо тяжелого SDK
RUN case "$TARGETARCH" in \
  arm64) RUNTIME_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-arm64.tar.gz" ;; \
  *) RUNTIME_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_SDK_VERSION}/dotnet-sdk-${DOTNET_SDK_VERSION}-linux-arm64.tar.gz" ;; \
  esac && \
  curl -fSL -o /tmp/dotnet-runtime.tar.gz "${RUNTIME_URL}" && \
  mkdir -p /usr/share/dotnet && \
  tar -xzf /tmp/dotnet-runtime.tar.gz -C /usr/share/dotnet && \
  rm /tmp/dotnet-runtime.tar.gz

ENV PATH="${PATH}:/usr/share/dotnet" \
    DOTNET_RUNNING_IN_CONTAINER=true \
    ASPNETCORE_URLS=http://127.0.0.1:9118 \
    DOTNET_CLI_HOME=/tmp/dotnet_home

COPY --from=builder /out/lampac /lampac
COPY --from=builder /build/Shared /lampac/shared
COPY --from=builder /build/Online /lampac/online
COPY --from=builder /build/SISI /lampac/sisi
COPY --from=builder /build/Modules /lampac/modules
COPY --from=builder /build/Core/wwwroot /lampac/wwwroot
RUN chmod +x /lampac/Core

# ТОТАЛЬНАЯ ЗАЧИСТКА БАЛЛАСТА (Удаляем всё, кроме пары основных стабильных балансеров)
RUN rm -rf /lampac/online/AsiaGe* /lampac/online/Geosaitebi* /lampac/online/KinoUkr* \
           /lampac/online/UaKino* /lampac/online/UAFilm* /lampac/online/Ashdi* \
           /lampac/online/Tortuga* /lampac/online/BamBoo* /lampac/online/Eneyida* \
           /lampac/online/HdvbUA* /lampac/online/NextHUB* /lampac/online/Zetflix* \
           /lampac/online/KinoPub* /lampac/online/VoKino* /lampac/online/Filmix* \
           /lampac/online/Anime* /lampac/online/Ani* /lampac/online/Mikai* \
           /lampac/online/Kodik* /lampac/online/Dreamerscast* /lampac/online/AiLiberty* \
           /lampac/online/Baza* /lampac/online/Liba* /lampac/online/Evo*

RUN find /lampac/modules -name "*.js" -exec cp -f {} /lampac/wwwroot/ \; && \
    find /lampac/online -name "*.js" -exec cp -f {} /lampac/wwwroot/ \;

# Настройка init.conf: Переводим ридер в режим микро-запросов и жесткой экономии памяти
RUN echo '{ \
  "listen": {"port": 9118}, \
  "server": {"host": "0.0.0.0", "allow_cors": true}, \
  "cache": {"enable": true, "path": "/tmp/cache", "maxSize": 5, "memoryLimit": 2}, \
  "lowMemoryMode": true, \
  "readerv2": {"threads": 1, "timeout": 4000}, \
  "tmdb": { "enable": true, "proxy": true, "api_key": "@TMDB_PLACEHOLDER@" }, \
  "LampaWeb": { \
    "init": true, \
    "base_url": "https://lamposhka.koyeb.app", \
    "api_url": "https://lamposhka.koyeb.app" \
  }, \
  "chromium": { "enable": false }, \
  "useproxy": false \
}' > /lampac/init.conf

# Настройка accs.json: Оставляем только Rezka и VideoDB (они самые стабильные и легкие)
RUN mkdir -p /lampac/system /lampac/system/config && \
    echo '{ \
      "unzy": false, \
      "parseHot": false, \
      "VideoDB": {"enable": true, "proxy": false, "use_chromium": false}, \
      "Rezka": {"enable": true, "proxy": false, "use_chromium": false}, \
      "Kinogo": {"enable": false}, \
      "Kinobase": {"enable": false}, \
      "Collaps": {"enable": false}, \
      "HDVB": {"enable": false}, \
      "Alloha": {"enable": false}, \
      "Kodik": {"enable": false} \
    }' > /lampac/system/accs.json && \
    cp /lampac/system/accs.json /lampac/system/config/accs.json

RUN mkdir -p /lampac/data /lampac/cache /run/nginx /tmp/dotnet_home && chmod -R 777 /lampac /tmp /var/lib/nginx /var/log/nginx /run/nginx

RUN mkdir -p /lampac/auth && echo '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Lampac Auth</title><style>body{background:#141414;color:#fff;font-family:sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;margin:0}div{background:#2b2b2b;padding:40px;border-radius:8px;text-align:center;box-shadow:0 4px 15px rgba(0,0,0,0.5)}input{padding:12px;width:200px;border:none;border-radius:4px;margin-bottom:15px;font-size:16px;background:#444;color:#fff;text-align:center}button{padding:12px 24px;background:#e50914;color:#fff;border:none;border-radius:4px;cursor:pointer;font-size:16px;font-weight:bold;width:100%}#err{color:#e50914;margin-top:10px;font-weight:bold;height:20px;}</style></head><body><div><h2>Введите токен доступа</h2><input type="password" id="pwd" placeholder="Токен" required><br><button onclick="validateToken()">Войти</button><div id="err"></div></div><script>function validateToken(){var inputToken=document.getElementById("pwd").value;fetch("/verify_token?token="+encodeURIComponent(inputToken)).then(function(res){if(res.status===200){document.cookie="lampac_access="+inputToken+"; Path=/; Max-Age=31536000; Secure; SameSite=None";window.location.href="/";}else{document.getElementById("err").innerText="Неверный токен!";}});}</script></body></html>' > /lampac/auth/login.html

RUN printf 'import os\n\
import json\n\
import secrets\n\
\n\
token = os.environ.get("LAMPAC_TOKEN")\n\
if not token:\n\
    token = secrets.token_hex(32)\n\
\n\
tmdb_key = os.environ.get("TMDB_API_KEY", "")\n\
\n\
with open("/lampac/init.conf", "r") as f:\n\
    init_content = f.read()\n\
init_content = init_content.replace("@TMDB_PLACEHOLDER@", tmdb_key)\n\
with open("/lampac/init.conf", "w") as f:\n\
    f.write(init_content)\n\
\n\
config = {"accsdb": {"enable": True, "requestKey": True, "accounts": {token: "2040-01-01"}}}\n\
os.makedirs("/lampac/system/config", exist_ok=True)\n\
with open("/lampac/system/config/accsdb.json", "w") as f:\n\
    json.dump(config, f, indent=2)\n\
\n\
nginx_conf = f"""\n\
pid /tmp/nginx.pid;\n\
error_log /dev/stderr info;\n\
events {{ worker_connections 256; }}\n\
http {{\n\
    access_log /dev/stdout;\n\
    client_body_temp_path /tmp/client_body;\n\
    proxy_temp_path /tmp/proxy_temp;\n\
    server {{\n\
        listen 7860;\n\
        location = /verify_token {{\n\
            default_type text/plain;\n\
            if ($arg_token = "{token}") {{\n\
                add_header "Access-Control-Allow-Origin" "*" always;\n\
                return 200 "OK";\n\
            }}\n\
            return 401 "Unauthorized";\n\
        }}\n\
        location / {{\n\
            set $access "allow";\n\
            if ($request_uri ~* "^/($|init\\\\.js|msx)") {{\n\
                set $access "block";\n\
            }}\n\
            if ($arg_token = "{token}") {{ set $access "allow"; }}\n\
            if ($arg_account = "{token}") {{ set $access "allow"; }}\n\
            if ($http_cookie ~* "lampac_access={token}") {{ set $access "allow"; }}\n\
            if ($remote_addr = "127.0.0.1") {{ set $access "allow"; }}\n\
            if ($access = "allow") {{\n\
                proxy_pass http://127.0.0.1:9118;\n\
            }}\n\
            if ($access = "block") {{\n\
                root /lampac/auth;\n\
                rewrite ^(.*)$ /login.html break;\n\
                add_header "Access-Control-Allow-Origin" "*" always;\n\
            }}\n\
            proxy_http_version 1.1;\n\
            proxy_set_header Upgrade $http_upgrade;\n\
            proxy_set_header Connection "upgrade"; \n\
            proxy_set_header Host $host;\n\
        }}\n\
    }}\n\
}}\n\
"""\n\
with open("/tmp/nginx.conf", "w") as f:\n\
    f.write(nginx_conf)\n\
' > /lampac/entrypoint.py

# АГРЕССИВНЫЕ НАСТРОЙКИ ОЧИСТКИ ОЗУ ДЛЯ СРЕДЫ .NET (Оптимизировано под ультра-низкое потребление)
RUN printf '#!/bin/sh\n\
python3 /lampac/entrypoint.py\n\
nginx -c /tmp/nginx.conf -g "daemon on;"\n\
\n\
export COMPlus_GCThreadCount=1\n\
export DOTNET_GCHeapHardLimitPercent=40\n\
export DOTNET_GCWindowMemoryLimitPercent=40\n\
export DOTNET_GCLargeObjectHeapCompaction=1\n\
export DOTNET_GCHighMemVolumeThreshold=40\n\
export DOTNET_GCHeapHardLimit=50331648\n\
\n\
exec /lampac/Core --urls http://127.0.0.1:9118\n\
' > /lampac/init.sh && chmod +x /lampac/init.sh

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/lampac/init.sh"]
