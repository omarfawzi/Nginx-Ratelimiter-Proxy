![Test Status](https://github.com/omarfawzi/Nginx-Ratelimiter-Proxy/actions/workflows/ci.yml/badge.svg)
[![codecov](https://codecov.io/github/omarfawzi/Nginx-Ratelimiter-Proxy/graph/badge.svg?token=UAFTLUSL8R)](https://codecov.io/github/omarfawzi/Nginx-Ratelimiter-Proxy)

# NGINX Rate Limiter Proxy

## Overview

This lightweight rate limiter serves as a **reverse proxy**, regulating incoming traffic and enforcing rate limits **before requests reach your backend**. By controlling excessive traffic and potential abuse, it enhances both security and performance.

## Key Features

- **Kubernetes Sidecar Proxy**: Designed to manage traffic **before it enters your main application container**, ensuring seamless rate limiting within a Kubernetes environment.
- **NGINX + Lua**: Implemented using **Lua scripting within NGINX**, leveraging `lua-resty-global-throttle` and `lua-resty-redis`.
- **Flexible Caching**: Supports both **Redis** and **Memcached** as distributed caching providers.
- **Configurable Rules**: Rate limit rules are **defined in a YAML file**, allowing for flexible and dynamic configurations.
- **Sliding Window Algorithm**: Uses a **sliding window rate-limiting algorithm** for both caching providers, ensuring fair and efficient traffic control.

## Architecture

```mermaid
graph LR
   subgraph Infrastructure
      B[Nginx Proxy] -- Rate Limit Check --> C{Store}
      C -- 429 Too Many Requests --> B

      style B fill:#f9f,stroke:#333,stroke-width:2px
      style C fill:#ccf,stroke:#333,stroke-width:2px
      style B fill:#f9f,stroke:#333,stroke-width:2px
      classDef rate_limiting fill:#ffc,stroke:#333;
      class C rate_limiting
   end

   subgraph Application
      E[Main Application]
      style E fill:#eef,stroke:#333,stroke-width:2px
   end

   B -- Forward if allowed --> E
   E -- Response --> B
   B -- Response --> A
   A -- Request --> B

   classDef external fill:#eee,stroke:#333
   class A external

   classDef container fill:#ccf,stroke:#333
   class E container

   classDef proxy fill:#f9f,stroke:#333
   class B proxy

   linkStyle 0,1,2,3 stroke:#0aa,stroke-width:2px;
   linkStyle 4,5 stroke:#080,stroke-width:2px;
   
   classDef cache fill:#ddf,stroke:#333
   class D1,D2,D3 cache

   subgraph Client
      A[Client]
   end
```

## Interaction Flow

1. **Client Request**: The client sends a request to the application.
2. **NGINX Proxy**: The request is intercepted by the NGINX proxy.
3. **Rate Limiting**: The proxy checks the request against the rate limiting rules defined in the YAML file.
4. **Decision-Making & Request Handling**:
   - **Ignored Segments**: The request IP/user is first checked against the ignoredSegments configuration. If matched, rate limiting is bypassed, and the request is forwarded.
   - **Rate Limit Exceeded**: If the request exceeds the defined rate limit, a `429 Too Many Requests` response is immediately returned to the client.
   - **Rate Limit Within Limits**: If the request is within the rate limit, it is proxied to the main application.
   - **Lua Exception Handling**: In the event of an exception within the Lua rate limiting script, the request is still proxied to the main application (this should be carefully considered and potentially logged/monitored).
   - **Rules Precedence**: Explicit IP addresses in the configuration take priority over users and generic CIDR ranges (e.g., 0.0.0.0/0).
5. **Main Application**: The request is processed by the main application if it passes the rate limiting check.
6. **Response**: The main application's response travels back through the NGINX proxy to the client.

## Configuration

### Rate Limit Rules

Rate limit rules are defined in the ratelimits.yaml file. The structure of the YAML file is as follows:

```yaml
ignoredSegments:
   users:
      - admin
   ips:
      - 127.0.0.1

rules:
  /v1:
    users:
      user2: 
        limit: 50
        window: 60
    ips:
      192.168.1.1: 
        limit: 200
        window: 60
  ^/v2/[0-9]$:
    users:
      user3:
        limit: 30
        window: 60
```
- `ignoredSegments`: Defines users and IPs for which rate limiting should be skipped. This is useful for administrative users or specific trusted IPs.
- `rules`: Contains the rate limit rules for different URI paths.
- `path`: The URI path to which the rate limit applies, to apply ratelimits for all paths you can provide `/` as a global path, for regex paths refer to https://github.com/openresty/lua-nginx-module?tab=readme-ov-file#ngxrematch.
- `user/IP`: The user or IP address to which the rate limit applies.
- `limit`: The maximum number of requests allowed within the time window.
- `window`: The time window in seconds during which the limit applies.

> **if** `0.0.0.0/0` is specified this will apply rate limiting for all incoming ips but per ip, 
> i.e suppose we have two ips `127.0.0.1` and `127.0.0.2` and rules are set to 10 rps each ip will be able to hit by 10 rps.

### Environment Variables

The following environment variables need to be set:

- `UPSTREAM_HOST`: The hostname of the main application.
- `UPSTREAM_TYPE`: The type of upstream server. Valid values are:
   - `http`: For HTTP upstreams.
   - `fastcgi`: For FastCGI upstreams.
- `INDEX_FILE`: The default index file for FastCGI upstreams (e.g., `index.php`).
- `SCRIPT_FILENAME`: The script filename for FastCGI upstreams (e.g., `/var/www/app/public/index.php`).
- `UPSTREAM_PORT`: The port of the main application.
- `DISTRIBUTED_CACHE_HOST`: The hostname of the distributed cache host.
- `DISTRIBUTED_CACHE_PORT`: The port of the distributed cache port.
- `DISTRIBUTED_CACHE_PROVIDER`: The provider of the distributed cache, either `redis` or `memcached`.

> To enable either `FastCGI` or `HTTP` upstreams, set the `UPSTREAM_TYPE` environment variable to the desired value (`fastcgi` or `http`).

### Running the Proxy

To run the NGINX Rate Limiter Proxy using Docker, you need to mount the rate limit configuration file and set the required environment variables.

```sh
docker run --rm --platform linux/amd64 \
  -v $(pwd)/ratelimits.yaml:/usr/local/openresty/nginx/lua/ratelimits.yaml \
  -e UPSTREAM_HOST=localhost \
  -e UPSTREAM_TYPE=http \
  -e UPSTREAM_PORT=3000 \
  -e DISTRIBUTED_CACHE_HOST=mcrouter \
  -e DISTRIBUTED_CACHE_PORT=5000 \
  -e DISTRIBUTED_CACHE_PROVIDER=memcached \
  ghcr.io/omarfawzi/nginx-ratelimiter-proxy:master
```

### Listening Port and Custom Configurations

By default, the NGINX Rate Limiter Proxy listens on port `80`. However, this can be overridden by mounting a custom `listen.conf` file to the following path:`/usr/local/openresty/nginx/conf/listen.conf` .

#### Custom Logic and Caching

For additional customization, such as caching specific URIs or adding other NGINX directives, you can mount a custom `custom.conf` file to: `/usr/local/openresty/nginx/conf/custom.conf` .

This allows for flexible modifications and further optimizations based on your application's requirements.

### Request flow 

```mermaid
graph TD
    subgraph IP Rules
        CheckIPRule{Is there an exact IP rule?} -->|Yes| ApplyIPRateLimit["Apply Rate Limit for IP"]
        ApplyIPRateLimit --> CheckLimit{Exceeded Limit?}
    end

    subgraph User Rules
        CheckUserRule{Is there a user rule?} -->|Yes| ApplyUserRateLimit["Apply Rate Limit for User"]
        ApplyUserRateLimit --> CheckLimit
    end

    subgraph CIDR Rules
        CheckCIDRRule{Does IP match CIDR rule?} -->|Yes| ApplyCIDRRateLimit["Apply Rate Limit for IP CIDR"]
        ApplyCIDRRateLimit --> CheckLimit
    end

    subgraph Global Rules
        CheckGlobalIPRule{Is there a global IP rule?} -->|Yes| ApplyGlobalIPRateLimit["Apply Global Rate Limit"]
        ApplyGlobalIPRateLimit --> CheckLimit
    end

    Start["Request Received"] --> CheckIgnore{Is IP or User Ignored?}
    CheckIgnore -->|Yes| AllowRequest["Allow Request"]
    CheckIgnore -->|No| CheckIPRule

    CheckIPRule -->|No| CheckUserRule
    CheckUserRule -->|No| CheckCIDRRule
    CheckCIDRRule -->|No| CheckGlobalIPRule
    CheckGlobalIPRule -->|No| AllowRequest

    CheckLimit -->|Yes| ThrottleResponse["Return 429 Too Many Requests"]
    CheckLimit -->|No| AllowRequest
```
