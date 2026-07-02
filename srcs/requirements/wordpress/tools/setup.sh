#!/bin/bash

MYSQL_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)

until mysqladmin ping -h"mariadb" -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --silent; do
    echo "Waiting for MariaDB to be ready..."
    sleep 2
done

if [ ! -f "/var/www/html/.initialized" ]; then
    echo "First run detected - setting up WordPress..."

    curl -O https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz -C /var/www/html --strip-components=1
    rm latest.tar.gz
    wp config create \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost="mariadb" \
        --path="/var/www/html" \
        --allow-root
    wp core install \
        --url="${DOMAIN_NAME}" \
        --title="Inception" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --path="/var/www/html" \
        --allow-root
    wp user create \
        "${WP_USER}" \
        "${WP_USER_EMAIL}" \
        --role=subscriber \
        --user_pass="${WP_USER_PASSWORD}" \
        --path="/var/www/html" \
        --allow-root
    touch /var/www/html/.initialized
    echo "WordPress setup complete."
fi

echo "Starting php-fpm..."
exec php-fpm8.2 -F