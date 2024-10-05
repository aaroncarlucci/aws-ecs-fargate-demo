FROM alpine:3.18.4

RUN apk add nginx openssl

COPY nginx.conf /etc/nginx/http.d/default.conf
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 443

COPY entrypoint.sh /usr/sbin/entrypoint.sh
RUN chmod 755 /usr/sbin/entrypoint.sh

ENTRYPOINT ["/bin/sh", "/usr/sbin/entrypoint.sh"]
