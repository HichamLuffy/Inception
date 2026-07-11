# USER_DOC.md — User Documentation

This document explains how to use the Inception infrastructure as an end user or administrator: what it provides, how to start/stop it, how to access it, where credentials live, and how to check everything is healthy.

## 1. What services does this stack provide?

The project runs three containers, each with a single responsibility:

| Service   | Role                                                                 |
|-----------|-----------------------------------------------------------------------|
| `nginx`   | The only entrypoint into the infrastructure. Serves the site over HTTPS (TLSv1.3) on port 443, and forwards PHP requests to WordPress. |
| `wordpress` | Runs WordPress with php-fpm. Handles all the site's application logic (pages, posts, users, admin panel). |
| `mariadb` | The database. Stores everything WordPress needs: posts, settings, and user accounts. |

All three run on a private, isolated Docker network (`inception`). Only `nginx` is reachable from outside — `wordpress` and `mariadb` are never directly exposed.

## 2. Starting and stopping the project

All commands are run from the project root, where the `Makefile` lives.

**Start everything (build images if needed, then launch):**
```bash
make
```

**Stop the containers (keeps images and data):**
```bash
make stop
```

**Bring everything down (containers removed, data volumes kept):**
```bash
make down
```

**Full clean reset (removes containers, volumes, and stored data):**
```bash
make clean
```

**Full rebuild from scratch:**
```bash
make re
```

> A full clean reset deletes your WordPress site and database content permanently. Only use `make clean` or `make fclean` if you intend to start over.

## 3. Accessing the website and the administration panel

The site is only reachable through the domain configured for this project (matching your 42 login), for example:

```
https://<login>.42.fr
```

Before this works, the machine you're browsing from needs to know that this domain points to the server's IP address. This is configured in `/etc/hosts`:

```
<server_ip>    <login>.42.fr
```

Since the certificate is self-signed (not issued by a public Certificate Authority), your browser will show a security warning the first time you visit. This is expected — click through it ("Advanced" → "Proceed") to reach the site. The connection is still fully encrypted; only the identity verification step is skipped, which is normal for a local/internal project like this one.

**Front-end site:**
```
https://<login>.42.fr
```

**Admin panel (WordPress dashboard):**
```
https://<login>.42.fr/wp-admin
```

Log in with the admin username and password described below.

## 4. Locating and managing credentials

No password is ever hardcoded in the source code or committed to the repository. Credentials live in two separate places:

**`secrets/` folder (at the project root)** — contains the actual passwords, one per file:
- `db_password.txt` — password for the WordPress database user
- `db_root_password.txt` — password for the MariaDB root account
- `wp_admin_password.txt` — password for the WordPress administrator account
- `wp_user_password.txt` — password for the second (regular) WordPress account

This folder is excluded from version control (`.gitignore`) since it contains sensitive data.

**`srcs/.env` file** — contains non-sensitive configuration, including the usernames tied to the passwords above:
- `WP_ADMIN_USER` — the WordPress administrator's username
- `WP_USER` — the second WordPress user's username
- `MYSQL_USER` — the database username
- `DOMAIN_NAME` — the site's domain

To find or change a credential, open the relevant file in `secrets/` (for a password) or `srcs/.env` (for a username). Changing a password after the first run will not automatically update the database — see `DEV_DOC.md` for how to apply changes that require re-initialization.

## 5. Checking that services are running correctly

**Check the status of all three containers:**
```bash
docker ps
```
All three (`mariadb`, `wordpress`, `nginx`) should show a status of `Up`.

**Check the logs of a specific service** (useful if something looks wrong):
```bash
docker logs mariadb
docker logs wordpress
docker logs nginx
```

Healthy signs to look for:
- `mariadb`: ends with `mariadbd: ready for connections.`
- `wordpress`: ends with `Starting php-fpm...` and stays running (no restart loop)
- `nginx`: no error lines; the process simply keeps running silently once started

**Quick end-to-end check** — confirms the whole chain (nginx → php-fpm → database) works:
```bash
curl -k https://<login>.42.fr/
```
A successful response returns the site's HTML. `-k` is required because the certificate is self-signed.

If any container is missing from `docker ps`, or a `curl` request fails, see `DEV_DOC.md` for troubleshooting steps.