local _M = {}

local FIXED_WINDOW_SCRIPT = [[
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

    local script_sha = require('redis.main').get_cached_script(red, ngx, 'fixed_window_sha', FIXED_WINDOW_SCRIPT)
    local res, err
    if not script_sha then
        res, err = red:eval(FIXED_WINDOW_SCRIPT, 1, cache_key, max_requests, window)
    else
        res, err = red:evalsha(script_sha, 1, cache_key, max_requests, window)
    end

    if not res then
        ngx.log(ngx.ERR, "Fixed Window Rate Limit script execution failed: ", err)
        return false
    end

    red:set_keepalive(10000, 100)
    return res == 1
end

return _M
