local _M = {}
local CACHE_THRESHOLD = 0.001

function _M.throttle(ngx, path, key, rule, cache)
    local global_throttle = require("resty.global_throttle")

    local cache_key = path .. ":" .. key

    local throttle = global_throttle.new('local', rule.limit, rule.window, {
        provider = 'memcached',
        host = os.getenv('DISTRIBUTED_CACHE_HOST'),
        port = os.getenv('DISTRIBUTED_CACHE_PORT'),
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
            local ok
            ok, err = cache:safe_add(cache_key, true, desired_delay)
            if not ok then
                if err ~= "exists" then
                    ngx.log(ngx.ERR, "failed to cache decision: ", err)
                end
            end
        end
        return true
    end

    return false
end

return _M