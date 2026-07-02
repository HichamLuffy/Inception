FROM debian:bookworm

RUN apt-get update && apt-get install -y nginx openssl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/nginx/ssl

RUN openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/inception.key \
    -out /etc/nginx/ssl/inception.crt \
    -subj "/C=MA/ST=Khouribga/L=Khouribga/O=42/CN=yourlogin.42.fr"

COPY conf/nginx.conf /etc/nginx/conf.d/wordpress.conf

EXPOSE 443

ENTRYPOINT ["nginx", "-g", "daemon off;"]