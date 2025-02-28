local _M = {}

local redis = require("resty.redis")

local ALGORITHMS = {
    ['token-bucket'] = 'redis.token_bucket',
    ['sliding-window'] = 'redis.sliding_window',
    ['leaky-bucket'] = 'redis.leaky_bucket',
    ['fixed-window'] = 'redis.fixed_window'
}

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


function _M.throttle(ngx, cache_key, rule)
    local red = _M.connect(ngx, os.getenv('CACHE_HOST'), tonumber(os.getenv('CACHE_PORT')))
    if not red then return false end

    local algorithm = os.getenv('CACHE_ALGO') or 'token-bucket'

    local module = require(ALGORITHMS[algorithm] or ALGORITHMS['fixed-window'])

    local cluster_safe_key = "{rate_limit}:" .. cache_key

    return module.throttle(red, ngx, cluster_safe_key, rule)
end

return _M
