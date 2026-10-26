FROM nginx:alpine
ARG domain

RUN test -n "$domain" || (echo "ERROR: domain is not set" && false)

# Очищаем стандартную папку Nginx и копируем туда наши файлы
RUN rm -rf /usr/share/nginx/html/*
COPY . /usr/share/nginx/html/

# Создаем конфигурационный файл Nginx с жестко встроенными CORS-разрешениями для ТВ
RUN echo 'server { \
    listen 80; \
    location / { \
        root /usr/share/nginx/html; \
        index index.html index.htm; \
        add_header Access-Control-Allow-Origin "*"; \
        add_header Access-Control-Allow-Methods "GET, POST, OPTIONS"; \
        add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range"; \
        if ($request_method = "OPTIONS") { \
            return 204; \
        } \
    } \
}' > /etc/nginx/conf.d/default.conf

# Прописываем домен в автозапуск MSX
RUN if [ -f /usr/share/nginx/html/msx/start.json ]; then \
        sed -i "s|{domain}|$domain|g" /usr/share/nginx/html/msx/start.json; \
    fi
