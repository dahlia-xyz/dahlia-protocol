FROM nginx:1.21

RUN mkdir /etc/nginx/templates
COPY default.conf.template /etc/nginx/templates
COPY index.html /usr/share/nginx/html/index.html
