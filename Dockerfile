FROM alpine:latest

MAINTAINER Troy Kelly <troy.kelly@really.ai>

ENV VERSION=1.13.7
ENV OPENSSL_VERSION=1.1.0g
ENV LIBPNG_VERSION=1.6.34
ENV LUAJIT_VERSION=2.0.5

# Build-time metadata as defined at http://label-schema.org
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
ARG OPENSSL_VERSION
ARG LIBPNG_VERSION
ARG LUAJIT_VERSION
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="NGINX with Certbot and lua support" \
      org.label-schema.description="Provides nginx ${VERSION} with lua (LuaJIT v${LUAJIT_VERSION}) support for certbot --nginx. Built with OpenSSL v${LIBPNG_VERSION} and LibPNG v${LIBPNG_VERSION}" \
      org.label-schema.url="https://really.ai/about/opensource" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/reallyreally/docker-nginx-certbot" \
      org.label-schema.vendor="Really Really, Inc." \
      org.label-schema.version=v$VERSION \
      org.label-schema.schema-version="1.0"

RUN build_pkgs="alpine-sdk curl perl libffi-dev py-pip linux-headers pcre-dev zlib-dev apr-dev apr-util-dev libjpeg-turbo-dev icu-dev python2-dev" && \
  runtime_pkgs="ca-certificates pcre apr-util libjpeg-turbo icu icu-libs python2 py-setuptools" && \
  apk add --update --no-cache ${build_pkgs} ${runtime_pkgs} && \
  mkdir -p /src /var/log/nginx /run/nginx /var/cache/nginx && \
  addgroup nginx && \
  adduser -s /usr/sbin/nologin -G nginx -D nginx && \
  cd /src && \
  wget -qO - https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz | tar xzf  - -C /src && \
  wget -qO - http://nginx.org/download/nginx-${VERSION}.tar.gz | tar xzf  - -C /src && \
  wget -qO - http://prdownloads.sourceforge.net/libpng/libpng-${LIBPNG_VERSION}.tar.gz | tar xzf  - -C /src && \
  wget -qO - http://luajit.org/download/LuaJIT-${LUAJIT_VERSION}.tar.gz | tar xzf  - -C /src && \
  cd /src/LuaJIT-${LUAJIT_VERSION} && \
  cd /src/libpng-${LIBPNG_VERSION} && \
  ./configure --build=$CBUILD --host=$CHOST --prefix=/usr --enable-shared --with-libpng-compat && \
  make -j$(nproc) install V=0 && \
  cd /src/openssl-${OPENSSL_VERSION} && \
  ./config no-async --prefix=/usr && \
  make -j$(nproc) depend && \
  make -j$(nproc) && \
  make -j$(nproc) install && \
  cd /src/nginx-${VERSION} && \
  ./configure \
  	--prefix=/etc/nginx \
  	--sbin-path=/usr/sbin/nginx \
  	--conf-path=/etc/nginx/nginx.conf \
  	--error-log-path=/var/log/nginx/error.log \
  	--http-log-path=/var/log/nginx/access.log \
  	--pid-path=/var/run/nginx.pid \
  	--lock-path=/var/run/nginx.lock \
  	--http-client-body-temp-path=/var/cache/nginx/client_temp \
  	--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
  	--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
  	--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
  	--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
  	--user=nginx \
  	--group=nginx \
  	--with-http_ssl_module \
  	--with-http_realip_module \
  	--with-http_addition_module \
  	--with-http_sub_module \
  	--with-http_dav_module \
  	--with-http_flv_module \
  	--with-http_mp4_module \
  	--with-http_gunzip_module \
  	--with-http_gzip_static_module \
  	--with-http_random_index_module \
  	--with-http_secure_link_module \
  	--with-http_stub_status_module \
  	--with-http_auth_request_module \
  	--without-http_autoindex_module \
  	--without-http_ssi_module \
  	--with-threads \
  	--with-stream \
  	--with-stream_ssl_module \
  	--with-mail \
  	--with-mail_ssl_module \
  	--with-file-aio \
  	--with-http_v2_module \
    --with-cc-opt="-fPIC -I /usr/include/apr-1" \
    --with-ld-opt="-luuid -lapr-1 -laprutil-1 -licudata -licuuc -lpng16 -lturbojpeg -ljpeg" \
    --with-openssl-opt="no-async enable-ec_nistp_64_gcc_128 no-shared no-ssl2 no-ssl3 no-comp no-idea no-weak-ssl-ciphers -DOPENSSL_NO_HEARTBEATS -O3 -fPIE -fstack-protector-strong -D_FORTIFY_SOURCE=2" \
  	--with-ipv6 \
  	--with-pcre-jit \
  	--with-openssl=/src/openssl-${OPENSSL_VERSION} && \
  make -j$(nproc) && \
  make -j$(nproc) install && \
  sed -i 's!#user  nobody!user nginx nginx!g' /etc/nginx/nginx.conf && \
  sed -i "s!^    # another virtual host!include /etc/nginx/conf.d/*.conf;\n    # another virtual host!g" /etc/nginx/nginx.conf && \
  cd ~ && \
  pip install certbot certbot-nginx && \
  apk del ${build_pkgs} && \
  apk add ${runtime_pkgs} && \
  chown -R nginx:nginx /run/nginx /var/log/nginx /var/cache/nginx

EXPOSE 80 443

COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]
