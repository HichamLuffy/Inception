#!/bin/bash

MYSQL_PASSWORD=$(cat /run/secrets/db_password)
MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

if [ ! -d "/var/lib/mysql/.initialized" ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql
    mariadbd --user=mysql --skip-networking &
    sleep 5

    while ! mariadb -u root -e "SELECT 1" > /dev/null 2>&1; do
        echo "Waiting for Mariadb to be ready..."
        sleep 1
    done
    mariadb -u root <<EOF
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF
    mysqladmin -u root -p${MYSQL_ROOT_PASSWORD} shutdown
    touch /var/lib/mysql/.initialized
fi
echo "Starting MariaDB..."
exec mariadbd --user=mysql
