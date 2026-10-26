FROM httpd:alpine3.15
ARG domain

RUN test -n "$domain" || (echo "ERROR: domain is not set" && false)

# Очищаем стандартную папку Apache и копируем туда наши файлы
RUN rm -rf /usr/local/apache2/htdocs/*
COPY . /usr/local/apache2/htdocs/

# ВКЛЮЧАЕМ CORS ЗАГОЛОВКИ БЕЗОПАСНОСТИ ДЛЯ ТЕЛЕВИЗОРОВ
RUN sed -i 's/#LoadModule headers_module/LoadModule headers_module/g' /usr/local/apache2/httpd.conf
RUN echo 'Header set Access-Control-Allow-Origin "*"' >> /usr/local/apache2/httpd.conf
RUN echo 'Header set Access-Control-Allow-Methods "GET, POST, OPTIONS"' >> /usr/local/apache2/httpd.conf
RUN echo 'Header set Access-Control-Allow-Headers "X-Requested-With, Content-Type, Origin, Authorization, Accept, Client-Security-Token, Accept-Encoding"' >> /usr/local/apache2/httpd.conf

# Прописываем домен в автозапуск MSX
RUN if [ -f /usr/local/apache2/htdocs/msx/start.json ]; then \
        sed -i "s|{domain}|$domain|g" /usr/local/apache2/htdocs/msx/start.json; \
    fi
