# DEV_DOC.md — Developer Documentation

This document explains how to set up, build, run, and maintain the Inception project as a developer: environment setup, secrets, the Makefile/Compose workflow, container/volume management, and where data lives.

## 1. Project structure

```
.
├── Makefile
├── secrets/
│   ├── credentials.txt
│   ├── db_password.txt
│   ├── db_root_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
└── srcs/
    ├── .env
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/my.cnf
        │   └── tools/setup.sh
        ├── wordpress/
        │   ├── Dockerfile
        │   ├── conf/www.conf
        │   └── tools/setup.sh
        └── nginx/
            ├── Dockerfile
            └── conf/nginx.conf
```

`secrets/` and `srcs/.env` are both excluded from git via `.gitignore`, since they hold sensitive or machine-specific values.

## 2. Setting up the environment from scratch

### Prerequisites
- A Debian-based virtual machine (or equivalent Linux host)
- Docker Engine and the Docker Compose plugin installed
- Root/sudo access on the host, to write `/etc/hosts` and create data directories

### Configuration files to create before first run

**`srcs/.env`** — non-sensitive configuration:
```bash
DOMAIN_NAME=<login>.42.fr

# mariadb
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser

# wordpress
WP_TITLE=Inception
WP_ADMIN_USER=<login>_admin      # must NOT contain "admin"/"administrator"
WP_ADMIN_EMAIL=you@student.42.fr
WP_USER=regularuser
WP_USER_EMAIL=user@student.42.fr
```

**`secrets/` files** — one password per file, plain text, no trailing formatting needed:
```bash
echo "your_db_password"        > secrets/db_password.txt
echo "your_root_password"      > secrets/db_root_password.txt
echo "your_wp_admin_password"  > secrets/wp_admin_password.txt
echo "your_wp_user_password"   > secrets/wp_user_password.txt
```

**`/etc/hosts`** — so the domain resolves to this machine:
```bash
sudo sh -c 'echo "127.0.0.1    <login>.42.fr" >> /etc/hosts'
```
(Use the VM's actual IP instead of `127.0.0.1` if accessing it from a different host.)

## 3. Building and launching with the Makefile and Docker Compose

The `Makefile` is the single entry point; it wraps Docker Compose and ensures the host-side data directories exist before anything starts.

```bash
make          # create data dirs, build images, start all containers (detached)
make down     # stop and remove containers (volumes kept)
make stop     # stop containers without removing them
make clean    # down + remove volumes + delete host data directories
make fclean   # clean + prune all Docker build cache/images
make re       # fclean + make (full rebuild from a clean slate)
```

Under the hood, `make` runs approximately:
```bash
mkdir -p /home/$(USER)/data/mariadb
mkdir -p /home/$(USER)/data/wordpress
docker compose -f srcs/docker-compose.yml up --build -d
```

### What happens on `docker compose up --build`, in order

1. Compose reads `srcs/.env` automatically for variable substitution.
2. `--build` rebuilds each service's image from its own Dockerfile (`FROM debian:bookworm` as the pinned base — never `latest`).
3. The `inception` bridge network and the two named volumes (`db-data`, `wp-data`) are created if they don't already exist.
4. Containers are created respecting `depends_on` order: `mariadb` → `wordpress` → `nginx`. Note that `depends_on` only guarantees **start order**, not **readiness** — this is why `wordpress`'s entrypoint script contains its own retry loop (`mysqladmin ping`) before proceeding.
5. Each container's entrypoint runs:
   - `mariadb`: checks a marker file (`/var/lib/mysql/.initialized`); if absent, initializes the data directory, creates the `wordpress` database and its user, sets the root password, then execs `mariadbd` as PID 1.
   - `wordpress`: waits for MariaDB to respond, checks a marker file (`/var/www/html/.initialized`); if absent, downloads WordPress, configures it via `wp-cli`, creates the admin and second user, then execs `php-fpm` in the foreground as PID 1.
   - `nginx`: execs directly with `daemon off`, becoming PID 1 immediately (no custom script needed — nothing to initialize).

## 4. Managing containers and volumes — useful commands

**Container status and logs:**
```bash
docker ps                  # list running containers
docker ps -a                # include stopped/crashed containers
docker logs <container>      # view a specific container's logs
docker logs -f <container>   # follow logs live
```

**Entering a running container** (for debugging):
```bash
docker exec -it mariadb bash
docker exec -it wordpress bash
```

**Rebuilding after a code change:**
```bash
docker compose -f srcs/docker-compose.yml up --build
```
Only the layers affected by your change are rebuilt; Docker's build cache reuses everything unchanged (visible as `CACHED` in the build output).

**Full manual reset** (equivalent to `make re`, useful when volumes hold stale data from testing):
```bash
docker compose -f srcs/docker-compose.yml down -v
sudo rm -rf /home/$USER/data/mariadb /home/$USER/data/wordpress
mkdir -p /home/$USER/data/mariadb /home/$USER/data/wordpress
docker compose -f srcs/docker-compose.yml up --build
```

> Important: changes to `.env` values that affect database/user creation (e.g. `MYSQL_DATABASE`, `MYSQL_USER`) only take effect on a genuinely fresh volume. Because both `mariadb` and `wordpress` use a first-run marker file to avoid re-running setup on every restart, simply changing `.env` and restarting will **not** apply the change — a full volume wipe (above) is required.

## 5. Where data is stored and how it persists

Two named volumes back the persistent state, both backed by explicit host paths (via `driver_opts: type: none, o: bind`) rather than Docker's internal default location — this satisfies the requirement that data lives under `/home/<login>/data` while still being a managed named volume, not a raw bind mount:

| Volume     | Mounted at (in container)   | Physical location (on host)          | Contains                          |
|------------|------------------------------|----------------------------------------|------------------------------------|
| `db-data`  | `/var/lib/mysql` (mariadb)   | `/home/<login>/data/mariadb`          | The MariaDB database files          |
| `wp-data`  | `/var/www/html` (wordpress + nginx) | `/home/<login>/data/wordpress` | WordPress core files, themes, uploads |

`wp-data` is intentionally mounted into **both** the `wordpress` and `nginx` containers: `wordpress`/php-fpm writes and executes the PHP files, while `nginx` reads directly from the same volume to serve static assets (images, CSS, JS) without unnecessarily routing them through php-fpm.

Because these are real directories on the host disk, data survives `docker compose down`, container crashes, and rebuilds. It is only lost if you explicitly run `make clean` (or manually delete the host directories), which is the intended behavior for a deliberate full reset.