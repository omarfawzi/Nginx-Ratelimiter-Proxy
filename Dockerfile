FROM openresty/openresty:alpine-fat AS base

RUN apk add --no-cache git yaml-dev

RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-ipmatcher \
        --server=https://luarocks.org/dev && \
    /usr/local/openresty/luajit/bin/luarocks install lua-resty-global-throttle \
        --server=https://luarocks.org/dev && \
    /usr/local/openresty/luajit/bin/luarocks install lyaml \
        --server=https://luarocks.org/dev && \
    /usr/local/openresty/luajit/bin/luarocks install lua-resty-redis \
        --server=https://luarocks.org/dev && \
    /usr/local/openresty/luajit/bin/luarocks install nginx-lua-prometheus \
        --server=https://luarocks.org/dev

WORKDIR /usr/local/openresty/nginx/lua
COPY lua/ .

FROM base AS test
RUN /usr/local/openresty/luajit/bin/luarocks install busted \
        --server=https://luarocks.org/dev && \
    /usr/local/openresty/luajit/bin/luarocks install luacov \
        --server=https://luarocks.org/dev

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
