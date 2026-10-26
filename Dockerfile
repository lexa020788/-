FROM httpd:alpine3.15
ARG domain
ARG prefix="https://"
ARG secret_site

RUN test -n "$domain" || (echo "ERROR: domain is not set" && false)
RUN test -n "$secret_site" || (echo "ERROR: secret_site is not set" && false)

# Копируем всё содержимое репозитория в корневой каталог веб-сервера Apache
COPY . /usr/local/apache2/htdocs/

# Автоматически прописываем ваш личный домен Koyeb в конфигурацию автозапуска MSX
RUN if [ -f /usr/local/apache2/htdocs/msx/start.json ]; then \
        sed -i -e "s|{domain}|$domain|g" -e "s|{PREFIX}|$prefix|g" /usr/local/apache2/htdocs/msx/start.json; \
    fi

# Намертво вшиваем адрес вашего пиратского сайта в JS-код компонента парсера
RUN if [ -f /usr/local/apache2/htdocs/plugins/component.js ]; then \
        sed -i "s|{SECRET_SITE}|$secret_site|g" /usr/local/apache2/htdocs/plugins/component.js; \
    fi
