local _M = {}
local CACHE_THRESHOLD = 0.001

function _M.throttle(ngx, cache_key, rule, cache)
    if not os.getenv('CACHE_HOST') or not os.getenv('CACHE_PORT') then
        ngx.log(ngx.ERR, "Failed to use cache provider, please set both CACHE_HOST and CACHE_PORT")
        return false
    end

    local global_throttle = require("resty.global_throttle")

    local throttle = global_throttle.new('local', rule.limit, rule.window, {
        provider = 'memcached',
        host = os.getenv('CACHE_HOST'),
        port = tonumber(os.getenv('CACHE_PORT')),
        connect_timeout = 50,
        max_idle_timeout = 50,
        pool_size = 50
    })

    local _, desired_delay, err
    _, desired_delay, err = throttle:process(cache_key)

    if err then
        ngx.log(ngx.ERR, "error while throttling: ", err)
    end

    if desired_delay then
        if desired_delay > CACHE_THRESHOLD then
            require('util').add_to_local_cache(ngx, cache, cache_key, 1, desired_delay)
        end
        return true
    end

    return false
end

return _M