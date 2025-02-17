# NGINX Rate Limiter Proxy

## Overview

This lightweight rate limiter acts as a reverse proxy in front of your main application, controlling incoming traffic and enforcing rate limits before requests reach your backend. It helps protect your application from excessive traffic and potential abuse.

The rate limiter is implemented using Lua scripting within NGINX, leveraging the `lua-resty-global-throttle` and `lua-resty-ipmatcher` libraries. Rate limit configurations are defined in a YAML file, allowing flexible and dynamic rule enforcement.

## Architecture
```
+-------------------+       +-------------------+       +-------------------+
|                   |       |                   |       |                   |
|   Client Request  +------>+  NGINX Proxy      +------>+  Main Application |
|                   |       |  (Rate Limiter)   |       |                   |
+-------------------+       +-------------------+       +-------------------+
```

## Interaction Flow

1. **Client Request**: The client sends a request to the application.
2. **NGINX Sidecar**: The request is intercepted by the NGINX proxy.
3. **Rate Limiting**: The proxy checks the request against the rate limiting rules defined in the YAML file.
4. **Decision Making**:
   - Request IP/user is first validated against ignoredSegments. If matched, rate limiting is skipped. 
   - If the request is within the rate limit, it is proxied to the main application. 
   - If the request exceeds the rate limit, a 429 Too Many Requests response is returned to the client. 
   - If the Lua script triggers an exception, the request is still proxied to the main application. 
   - Explicit IPs take priority over generic CIDR ranges (e.g., 0.0.0.0/0).
5. **Main Application**: The request is processed by the main application if it passes the rate limiting check.

## Configuration

### Rate Limit Rules

Rate limit rules are defined in the ratelimits.yaml file. The structure of the YAML file is as follows:

```yaml
ignoredSegments:
   users:
      - admin
   ips:
      - 127.0.0.1

ratelimits:
  /path1:
    user2: { limit: 50, window: 60 }
    "192.168.1.1": { limit: 200, window: 60 }
  /path2:
    user3: { limit: 30, window: 60 }
```

- **path**: The URI path to which the rate limit applies.
- **user/IP**: The user or IP address to which the rate limit applies.
- **limit**: The maximum number of requests allowed within the time window.
- **window**: The time window in seconds during which the limit applies.

### Environment Variables

The following environment variables need to be set:

- **UPSTREAM_HOST**: The hostname of the main application.
- **UPSTREAM_PORT**: The port of the main application.
- **MCROUTER_HOST**: The hostname of the McRouter server.
- **MCROUTER_PORT**: The port of the McRouter server.

