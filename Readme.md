# NGINX Rate Limiter Proxy

## Overview

This lightweight rate limiter is designed to be deployed alongside your main application pods, intercepting incoming traffic and proxying it to the main application only if the request rate is within the defined limits. This helps in protecting your application from being overwhelmed by too many requests.

The rate limiter is implemented using Lua scripting within NGINX, leveraging the `lua-resty-global-throttle` and `lua-resty-ipmatcher` libraries. The configuration for rate limits is defined in a YAML file, which allows for flexible and dynamic rate limiting rules.

## Architecture
```
+-------------------+       +-------------------+       +-------------------+
|                   |       |                   |       |                   |
|   Client Request  +------>+  NGINX Sidecar    +------>+  Main Application |
|                   |       |  (Rate Limiter)   |       |                   |
+-------------------+       +-------------------+       +-------------------+
```

## Interaction Flow

1. **Client Request**: The client sends a request to the application.
2. **NGINX Sidecar**: The request is intercepted by the NGINX sidecar container.
3. **Rate Limiting**: The sidecar checks the request against the rate limiting rules defined in the YAML file.
4. **Decision Making**:
   - If the request is within the rate limit, it is proxied to the main application.
   - If the request exceeds the rate limit, a `429 Too Many Requests` response is returned to the client.
   - If lua script triggered an exception, request will still be proxied to main application.
   - Ips takes priority over users, also explicit ips takes priority over 0.0.0.0/0 CIDR range.
5. **Main Application**: The request is processed by the main application if it passes the rate limiting check.

## Configuration

### Rate Limit Rules

Rate limit rules are defined in the ratelimits.yaml file. The structure of the YAML file is as follows:

```yaml
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

