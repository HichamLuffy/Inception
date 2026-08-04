*This project has been created as part of the 42 curriculum by hfhad.*

# Inception

## Description

Inception is a system administration project whose goal is to containerize a small, production-style web infrastructure using Docker, built entirely from scratch — no pre-made images beyond the base Alpine/Debian OS, no `docker-compose`-forbidden shortcuts, and every service isolated into its own dedicated container.

The stack deploys a WordPress site served over HTTPS, backed by a MariaDB database, all orchestrated with Docker Compose on a virtual machine:

- **NGINX** — the sole entrypoint into the infrastructure, serving HTTPS on port 443 (TLSv1.2/TLSv1.3 only) and forwarding PHP requests to WordPress.
- **WordPress + php-fpm** — runs the actual site logic, installed and configured automatically (via `wp-cli`) on first startup, with no manual browser-based setup wizard.
- **MariaDB** — stores WordPress's data, initialized and configured automatically on first startup.

Each service is built from its own Dockerfile (`FROM debian:bookworm`, the penultimate stable release at the time of writing), runs as PID 1 with no hacky infinite-loop patches (no `tail -f`, `sleep infinity`, etc.), restarts automatically on crash, and persists its data through named volumes backed by explicit host paths under `/home/hfhad/data`. No password appears anywhere in a Dockerfile or in the Git history — all credentials are supplied through a `.env` file (non-sensitive config) and Docker secrets (passwords), both excluded from version control.

## Instructions

### Prerequisites
- A Debian-based virtual machine
- Docker Engine + Docker Compose plugin
- sudo access on the host (for `/etc/hosts` and data directory creation)

### Setup
1. Create `srcs/.env` with your domain, database name, and usernames (see `DEV_DOC.md` for the exact variables required).
2. Create the password files under `secrets/` (`db_password.txt`, `db_root_password.txt`, `wp_admin_password.txt`, `wp_user_password.txt`).
3. Add your domain to `/etc/hosts`, pointing at the VM's IP:
   ```
   <vm_ip>    hfhad.42.fr
   ```

### Build and run
```bash
make
```
This creates the host-side data directories and builds/starts all three containers via Docker Compose.

Other available targets: `make down`, `make stop`, `make clean`, `make fclean`, `make re`.

### Access
- Site: `https://hfhad.42.fr`
- Admin panel: `https://hfhad.42.fr/wp-admin`

The certificate is self-signed, so your browser will warn you the first time — this is expected; proceed past the warning.

Full usage details are in `USER_DOC.md`, and full developer/setup details are in `DEV_DOC.md`.

## Project description — design choices

### Virtual Machines vs Docker
A VM virtualizes an entire physical machine, including its own full operating system — every VM needs its own OS instance, which is heavy (gigabytes of RAM/disk) and slow to boot. A container virtualizes the operating system layer instead: all containers on a host share the same underlying kernel, and each one only isolates the parts of the OS it needs (filesystem, processes, network namespace). This makes containers dramatically lighter and faster to start than VMs, while still providing strong isolation between services. Inception still requires the whole stack to run inside a VM, since the project itself is a system administration exercise, and a VM gives a fully isolated, disposable environment to practice managing infrastructure end to end — but the containers *inside* that VM are what actually run the application services efficiently.


## Resources

- *Getting Started with Docker* — Nigel Poulton (2025), used throughout for core Docker/Compose concepts (images, layers, registries, Compose services/networks/volumes, the OCI).
- Official MariaDB documentation — `mariadb-install-db`, user/privilege management (`CREATE USER`, `GRANT`, `FLUSH PRIVILEGES`), `bind-address` configuration.
- Official WordPress and WP-CLI documentation — `wp core install`, `wp config create`, `wp user create`.
- Official NGINX documentation — FastCGI configuration (`fastcgi_pass`, `fastcgi_param`), TLS directives (`ssl_certificate`, `ssl_protocols`).


**AI usage:** Claude (Anthropic) was used throughout this project as a learning and debugging aid never to generate unreviewed code dropped directly into the project. It was used to: explain underlying concepts before writing any code (containers vs VMs, PID 1, TLS/certificates, image layers, Docker networking).