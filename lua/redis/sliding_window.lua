local _M = {}

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

function _M.throttle(red, ngx, cache_key, rule)
    local max_requests = rule.limit
    local window = rule.window

    local script_sha = require('redis.main').get_cached_script(red, ngx, 'sliding_window_sha', SLIDING_WINDOW_SCRIPT)
    local res, err
    if not script_sha then
        res, err = red:eval(SLIDING_WINDOW_SCRIPT, 1, cache_key, max_requests, window)
    else
        res, err = red:evalsha(script_sha, 1, cache_key, max_requests, window)
    end

    if not res then
        ngx.log(ngx.ERR, "Sliding Window Rate Limit script execution failed: ", err)
        return false
    end

    red:set_keepalive(10000, 100)
    return res == 1
end

return _M
