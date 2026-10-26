FROM httpd:alpine3.15
ARG domain
ARG prefix="https://"

# Оставляем проверку только для вашего домена Koyeb
RUN test -n "$domain" || (echo "ERROR: domain is not set" && false)

# Очищаем стандартную папку Apache и копируем туда наши файлы
RUN rm -rf /usr/local/apache2/htdocs/*
COPY . /usr/local/apache2/htdocs/

# Прописываем домен в автозапуск MSX
RUN if [ -f /usr/local/apache2/htdocs/msx/start.json ]; then \
        sed -i -e "s|{domain}|$domain|g" -e "s|{PREFIX}|$prefix|g" /usr/local/apache2/htdocs/msx/start.json; \
    fi
