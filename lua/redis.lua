local _M = {}
local redis = require("resty.redis")
local CACHE_THRESHOLD = 0.001

-- reference: https://redis.io/learn/develop/dotnet/aspnetcore/rate-limiting/sliding-window
local SLIDING_WINDOW_SCRIPT = [[
    local current_time = redis.call('TIME')
    local trim_time = tonumber(current_time[1]) - tonumber(ARGV[2])
    redis.call('ZREMRANGEBYSCORE', KEYS[1], 0, trim_time)
    local request_count = redis.call('ZCARD', KEYS[1])

    if request_count < tonumber(ARGV[1]) then
        redis.call('ZADD', KEYS[1], current_time[1], current_time[1] .. current_time[2])
        redis.call('EXPIRE', KEYS[1], ARGV[2])
        return 0
    end
    return 1
]]

function _M.connect(ngx, host, port)
    local red = redis:new()
    red:set_timeout(50)

    local ok, err = red:connect(host, port)
    if not ok then
        ngx.log(ngx.ERR, "failed to connect to Redis: ", err)
        return nil
    end

    return red
end

function _M.throttle(ngx, cache_key, rule, cache)
    if not os.getenv('CACHE_HOST') or not os.getenv('CACHE_PORT') then
        ngx.log(ngx.ERR, "Failed to use cache provider, please set both CACHE_HOST and CACHE_PORT")
        return false
    end

    local red = _M.connect(ngx, os.getenv('CACHE_HOST'), tonumber(os.getenv('CACHE_PORT')))
    if not red then
        return false
    end
    local max_requests = rule.limit
    local window = rule.window

    local res, err = red:eval(SLIDING_WINDOW_SCRIPT, 1, cache_key, max_requests, window)
    if not res then
        ngx.log(ngx.ERR, "failed to execute rate limiting script: ", err)
        return false
    end

    if res == 1 then
        local ttl, err = red:ttl(cache_key)
        if ttl and ttl > CACHE_THRESHOLD then
            require('util').add_to_local_cache(ngx, cache, cache_key, 1, ttl)
        elseif err then
            ngx.log(ngx.ERR, "failed to fetch TTL: ", err)
        end
    end

    local ok, err = red:set_keepalive(10000, 100)
    if not ok then
        ngx.log(ngx.ERR, "failed to set keepalive: ", err)
    end

    return res == 1
end

return _M
