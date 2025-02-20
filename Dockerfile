FROM openresty/openresty:alpine-fat

RUN apk add --no-cache git yaml-dev

RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-ipmatcher && \
    /usr/local/openresty/luajit/bin/luarocks install lua-resty-global-throttle && \
    /usr/local/openresty/luajit/bin/luarocks install lyaml && \
    /usr/local/openresty/luajit/bin/luarocks install busted

WORKDIR /usr/local/openresty/nginx/lua

COPY lua/* .

COPY nginx/nginx.kube.conf /usr/local/openresty/nginx/conf/nginx.conf

CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]