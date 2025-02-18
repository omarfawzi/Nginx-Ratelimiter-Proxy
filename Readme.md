# NGINX Rate Limiter Proxy

## Overview

This lightweight rate limiter acts as a reverse proxy in front of your main application, controlling incoming traffic and enforcing rate limits before requests reach your backend. It helps protect your application from excessive traffic and potential abuse.

The rate limiter is implemented using Lua scripting within NGINX, leveraging the `lua-resty-global-throttle` and `lua-resty-ipmatcher` libraries. Rate limit configurations are defined in a YAML file, allowing flexible and dynamic rule enforcement.

## Architecture

```mermaid
graph TD
   subgraph Infrastructure
      B[Nginx Proxy] -- Rate Limit Check --> C{Mcrouter}
      C -- Get/Set --> D1[Memcached 1]
      C -- Get/Set --> D2[Memcached 2]
      C -- Get/Set --> D3[Memcached 3]

      classDef memcached fill:#ddf,stroke:#333;
      class D1,D2,D3 memcached

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

   linkStyle 0,4 stroke:#0aa,stroke-width:2px;
   linkStyle 5,6 stroke:#080,stroke-width:2px;
   linkStyle 1,2,3 stroke:#888,stroke-width:1.5px,stroke-dasharray: 5 5;
   linkStyle 6 stroke:#080,stroke-width:2px;
   
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
   - **Rate Limit Exceeded**: If the request exceeds the defined rate limit, a 429 Too Many Requests response is immediately returned to the client.
   - **Rate Limit Within Limits**: If the request is within the rate limit, it is proxied to the main application.
   - **Lua Exception Handling**: In the event of an exception within the Lua rate limiting script, the request is still proxied to the main application (this should be carefully considered and potentially logged/monitored).
   - **IP Precedence**: Explicit IP addresses in the configuration take priority over generic CIDR ranges (e.g., 0.0.0.0/0).
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
  /path1:
    user2: { limit: 50, window: 60 }
    "192.168.1.1": { limit: 200, window: 60 }
  /path2:
    user3: { limit: 30, window: 60 }
```
- `ignoredSegments`: Defines users and IPs for which rate limiting should be skipped. This is useful for administrative users or specific trusted IPs.
- `rules`: Contains the rate limit rules for different URI paths.
- `path`: The URI path to which the rate limit applies.
- `user/IP`: The user or IP address to which the rate limit applies.
- `limit`: The maximum number of requests allowed within the time window.
- `window`: The time window in seconds during which the limit applies.

### Environment Variables

The following environment variables need to be set:

- `UPSTREAM_HOST`: The hostname of the main application.
- `UPSTREAM_TYPE`: The type of upstream server. Valid values are:
   - `http`: For HTTP upstreams.
   - `fastcgi`: For FastCGI upstreams.
- `INDEX_FILE`: The default index file for FastCGI upstreams (e.g., `index.php`).
- `SCRIPT_FILENAME`: The script filename for FastCGI upstreams (e.g., `/var/www/app/public/index.php`).
- `UPSTREAM_PORT`: The port of the main application.
- `MCROUTER_HOST`: The hostname of the McRouter server.
- `MCROUTER_PORT`: The port of the McRouter server.

> To enable either **FastCGI** or **HTTP** upstreams, set the **UPSTREAM_TYPE** environment variable to the desired value (**fastcgi** or **http**).