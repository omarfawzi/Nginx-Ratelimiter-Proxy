local _M = {}

local FIXED_WINDOW_SCRIPT = [[
    local current_time = redis.call('TIME')[1]
    local counter = redis.call('GET', KEYS[1])

    if counter and tonumber(counter) >= tonumber(ARGV[1]) then
        return 1
    end

    redis.call('INCR', KEYS[1])
    redis.call('EXPIRE', KEYS[1], ARGV[2])
    return 0
]]

function _M.throttle(red, ngx, cache_key, rule)
    local max_requests = rule.limit
    local window = rule.window

    local res, err = red:eval(FIXED_WINDOW_SCRIPT, 1, cache_key, max_requests, window)
    if not res then
        ngx.log(ngx.ERR, "Fixed Window Rate Limit script failed: ", err)
        return false
    end

    red:set_keepalive(10000, 100)
    return res == 1
end

return _M