FROM alpine:3.18.4

RUN apk add nginx openssl

# There are better options than generating certificate key pairs directly into the image. Compromising
#   with this solution in the short term for demonstratin purposes and planning to iterate.
#
#   TODO: Consider and explore the following:
#     * Store the certificate and key in AWS SSM Parameter Store and install using an ENTRYPOINT
#         wrapper script when the container initializes
#     * Store the certificate and key on an EFS volume that is mounted on all the application containers
#
RUN openssl req -x509 -newkey rsa:4096 -keyout /etc/ssl/private/key.pem -out /etc/ssl/certs/cert.pem -sha256 -days 3650 -nodes -subj "/CN=localhost"

COPY nginx.conf /etc/nginx/http.d/default.conf
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 443

CMD ["/bin/sh", "-c", "/usr/sbin/nginx -g 'daemon off;'", "/usr/sbin/nginx"]
