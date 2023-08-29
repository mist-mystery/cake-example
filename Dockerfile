FROM registry.access.redhat.com/ubi8/ubi:8.6
ARG USER=user
ARG HOME_DIR="/home/${USER}"
ARG CAKE_ROOT="/var/www/cake"
RUN dnf localinstall -y http://dev.mysql.com/get/mysql80-community-release-el8-5.noarch.rpm \
  && rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2022 \
  && dnf update -y \
  && dnf module install -y httpd php:8.0 \
  && dnf install -y \
    git \
    glibc-locale-source \
    mysql-community-devel \
    php-intl \
    php-mysqlnd \
    procps \
    unzip \
    vim-enhanced \
  && localedef -f UTF-8 -i ja_JP -A /usr/share/locale/locale.alias ja_JP.utf8 \
  && echo "LANG=\"ja_JP.utf8\"" > /etc/locale.conf \
  && ln -fs /usr/share/zoneinfo/Asia/Tokyo /etc/localtime \
  && useradd -m ${USER} \
  && dnf remove -y glibc-locale-source \
  && dnf clean all \
  && mkdir /run/php-fpm

COPY httpd/server.key /etc/pki/tls/private/localhost.key
COPY httpd/server.crt /etc/pki/tls/certs/localhost.crt
ENV LANG="ja_JP.utf8"
ENV TZ=Asia/Tokyo
WORKDIR ${CAKE_ROOT}
RUN sed -i -r "s/error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT/error_reporting = E_ALL/;\
    s/display_errors = Off/display_errors = On/;\
    s/;mbstring.language = /mbstring.language = /;" /etc/php.ini \
  && { \
    echo "<VirtualHost *:80>"; \
    echo "  DocumentRoot ${CAKE_ROOT}/webroot"; \
    echo "  <Directory ${CAKE_ROOT}/webroot>"; \
    echo "    Require all granted"; \
    echo "  </Directory>";\
    echo "</VirtualHost>"; \
  } > /etc/httpd/conf.d/vhost.conf \
  && sed -i "s:#DocumentRoot \"/var/www/html\":DocumentRoot \"${CAKE_ROOT}/webroot\"\nProtocols h2 http/1.1\n<Directory ${CAKE_ROOT}/webroot>\nRequire all granted\n</Directory>\n:"\
    /etc/httpd/conf.d/ssl.conf \
  && chown ${USER} ${CAKE_ROOT}

USER ${USER}
RUN mkdir -p ~/.local/bin \
  && curl -sSO https://getcomposer.org/installer \
  && php installer --install-dir="${HOME_DIR}/.local/bin" --filename=composer \
  && unlink installer \
  && { \
    echo "alias ls='ls --color=auto'"; \
    echo "alias ll='ls -l --color=auto'"; \
    echo "alias la='ls -Al --color=auto'"; \
  } >> ~/.bashrc

USER root
EXPOSE 80
CMD ["bash", "-c", "php-fpm && /usr/sbin/httpd -DFOREGROUND"]