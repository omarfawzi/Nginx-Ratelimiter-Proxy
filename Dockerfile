FROM openresty/openresty:alpine-fat AS base

RUN apk add --no-cache git yaml-dev

RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-ipmatcher && \
    /usr/local/openresty/luajit/bin/luarocks install lua-resty-global-throttle && \
    /usr/local/openresty/luajit/bin/luarocks install lyaml && \
    /usr/local/openresty/luajit/bin/luarocks install lua-resty-redis && \
    /usr/local/openresty/luajit/bin/luarocks install nginx-lua-prometheus

WORKDIR /usr/local/openresty/nginx/lua
COPY lua/* .

FROM base AS test
RUN /usr/local/openresty/luajit/bin/luarocks install busted && \
    /usr/local/openresty/luajit/bin/luarocks install luacov

FROM base AS docker
COPY nginx/resolvers/docker.conf /usr/local/openresty/nginx/conf/resolver.conf
COPY nginx/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]

FROM base AS kube
COPY nginx/resolvers/kube.conf /usr/local/openresty/nginx/conf/resolver.conf
COPY nginx/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]

FROM base AS local
COPY nginx/resolvers/google.conf /usr/local/openresty/nginx/conf/resolver.conf
COPY nginx/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
