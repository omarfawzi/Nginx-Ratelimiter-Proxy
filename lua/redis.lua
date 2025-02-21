local _M = {}
local redis = require("resty.redis")

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

function _M.throttle(ngx, path, key, rule)
    local red = redis:new()
    red:set_timeout(50)

    local ok, err = red:connect(os.getenv('DISTRIBUTED_CACHE_HOST'), tonumber(os.getenv('DISTRIBUTED_CACHE_PORT')))
    if not ok then
        ngx.log(ngx.ERR, "failed to connect to Redis: ", err)
        return false
    end

    local cache_key = path .. ":" .. key
    local max_requests = rule.limit
    local window = rule.window

    local res, err = red:eval(SLIDING_WINDOW_SCRIPT, 1, cache_key, max_requests, window)
    if not res then
        ngx.log(ngx.ERR, "failed to execute rate limiting script: ", err)
        return false
    end

    local ok, err = red:set_keepalive(10000, 50)
    if not ok then
        ngx.log(ngx.ERR, "failed to set keepalive: ", err)
    end

    return res == 1
end

return _M
