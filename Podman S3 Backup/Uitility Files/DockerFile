FROM nginx:alpine

LABEL maintainer="your-email@example.com"
LABEL description="Podman Web Server with S3 Backup"

COPY html/ /usr/share/nginx/html/

RUN mkdir -p /app/data

COPY data/ /app/data/

RUN echo 'server { \
    listen 80; \
    server_name localhost; \
    location / { \
        root /usr/share/nginx/html; \
        index index.html; \
        try_files $uri $uri/ =404; \
    } \
    location /data { \
        alias /app/data; \
        autoindex on; \
        autoindex_exact_size off; \
        autoindex_format html; \
        autoindex_localtime on; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
