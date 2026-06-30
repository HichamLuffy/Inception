# Inception
RUN CONTAINER OF MARIADB ALONE "
docker run -it -e MYSQL_DATABASE=wordpress -e MYSQL_USER=wpuser -v $(pwd)/../../../secrets/db_password.txt:/run/secrets/db_password:ro -v $(pwd)/../../../secrets/db_root_password.txt:/run/secrets/db_root_password:ro -v mariadb_test_volume:/var/lib/mysql mariadb