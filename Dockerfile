FROM openresty/openresty:alpine-fat AS base

RUN apk add --no-cache git curl yaml-dev

# Download and install Lua modules directly via .rockspec files
WORKDIR /tmp/rocks

# Install lua-resty-ipmatcher
RUN curl -LO https://luarocks.org/manifests/membphis/lua-resty-ipmatcher-0.6.1-0.rockspec && \
    /usr/local/openresty/luajit/bin/luarocks install lua-resty-ipmatcher-0.6.1-0.rockspec

# Install lua-resty-global-throttle
RUN curl -LO https://luarocks.org/manifests/elvinefendi/lua-resty-global-throttle-0.2.0-1.rockspec && \
    /usr/local/openresty/luajit/bin/luarocks install lua-resty-global-throttle-0.2.0-1.rockspec

# Install lyaml
RUN curl -LO https://luarocks.org/manifests/gvvaughan/lyaml-6.2.7-1.rockspec && \
    /usr/local/openresty/luajit/bin/luarocks install lyaml-6.2.7-1.rockspec

# Install lua-resty-redis
RUN curl -LO https://luarocks.org/manifests/rafatio/lua-resty-redis-0.27-0.rockspec && \
    /usr/local/openresty/luajit/bin/luarocks install lua-resty-redis-0.27-0.rockspec

# Install nginx-lua-prometheus
RUN curl -LO https://luarocks.org/manifests/knyar/nginx-lua-prometheus-0.20240525-1.rockspec && \
    /usr/local/openresty/luajit/bin/luarocks install nginx-lua-prometheus-0.20240525-1.rockspec

# Copy Lua source code
WORKDIR /usr/local/openresty/nginx/lua
COPY lua/ .

FROM base AS test

# Lua CLI Args
RUN curl -LO https://luarocks.org/manifests/lunarmodules/lua_cliargs-3.0.2-1.rockspec && \
    /usr/local/openresty/luajit/bin/luarocks install lua_cliargs-3.0.2-1.rockspec

# LuaFileSystem
RUN curl -LO https://luarocks.org/manifests/hisham/luafilesystem-1.8.0-1.rockspec && \
    /usr/local/openresty/luajit/bin/luarocks install luafilesystem-1.8.0-1.rockspec

# DKJSON
RUN curl -LO https://luarocks.org/manifests/dhkolf/dkjson-2.5-2.rockspec && \
    /usr/local/openresty/luajit/bin/luarocks install dkjson-2.5-2.rockspec

# Say
RUN curl -LO https://luarocks.org/manifests/lunarmodules/say-1.4.1-3.rockspec && \
    /usr/local/openresty/luajit/bin/luarocks install say-1.4.1-3.rockspec

# Luassert
RUN curl -LO https://luarocks.org/manifests/lunarmodules/luassert-1.9.0-1.rockspec && \
    /usr/local/openresty/luajit/bin/luarocks install luassert-1.9.0-1.rockspec

# Lua Term
RUN curl -LO https://luarocks.org/manifests/hoelzro/lua-term-0.7-1.rockspec && \
    /usr/local/openresty/luajit/bin/luarocks install lua-term-0.7-1.rockspec

# Penlight
RUN curl -LO https://luarocks.org/manifests/steved/penlight-1.5.4-1.rockspec && \
    /usr/local/openresty/luajit/bin/luarocks install penlight-1.5.4-1.rockspec

# Mediator Lua
RUN curl -LO https://luarocks.org/manifests/olivine-labs/mediator_lua-1.1.2-0.rockspec && \
    /usr/local/openresty/luajit/bin/luarocks install mediator_lua-1.1.2-0.rockspec

# Lua Cli args
RUN curl -LO https://luarocks.org/manifests/lunarmodules/lua_cliargs-3.0-0.rockspec && \
    /usr/local/openresty/luajit/bin/luarocks install lua_cliargs-3.0-0.rockspec

# Lua System
RUN curl -LO https://luarocks.org/manifests/lunarmodules/luasystem-scm-0.rockspec && \
    /usr/local/openresty/luajit/bin/luarocks install luasystem-scm-0.rockspec

# Busted
RUN curl -LO https://luarocks.org/manifests/lunarmodules/busted-2.2.0-1.rockspec && \
    /usr/local/openresty/luajit/bin/luarocks install busted-2.2.0-1.rockspec

# Luacov
RUN curl -LO https://luarocks.org/manifests/mpeterv/luacov-0.12.0-1.rockspec && \
    /usr/local/openresty/luajit/bin/luarocks install luacov-0.12.0-1.rockspec

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
