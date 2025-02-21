FROM openresty/openresty:alpine-fat AS base

RUN apk add --no-cache git yaml-dev

RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-ipmatcher && \
    /usr/local/openresty/luajit/bin/luarocks install lua-resty-global-throttle && \
    /usr/local/openresty/luajit/bin/luarocks install lyaml

WORKDIR /usr/local/openresty/nginx/lua
COPY lua/* .

FROM base AS test
RUN /usr/local/openresty/luajit/bin/luarocks install busted && \
    /usr/local/openresty/luajit/bin/luarocks install luacov

FROM base AS config
COPY nginx/base/lua_init.conf /usr/local/openresty/nginx/conf/lua_init.conf
COPY nginx/base/dynamic_upstream.conf /usr/local/openresty/nginx/conf/dynamic_upstream.conf
COPY nginx/base/log_format.conf /usr/local/openresty/nginx/conf/log_format.conf
COPY nginx/base/custom.conf /usr/local/openresty/nginx/conf/custom.conf
COPY nginx/base/listen.conf /usr/local/openresty/nginx/conf/listen.conf

FROM config AS docker
COPY nginx/nginx.docker.conf /usr/local/openresty/nginx/conf/nginx.conf
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]

FROM config AS kube
COPY nginx/nginx.kube.conf /usr/local/openresty/nginx/conf/nginx.conf
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]

FROM config AS local
COPY nginx/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
