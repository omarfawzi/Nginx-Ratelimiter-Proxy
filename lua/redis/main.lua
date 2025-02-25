local _M = {}

local redis = require("resty.redis")

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

    local algorithm = os.getenv('CACHE_ALGO')

    if algorithm == 'token-bucket' then
        return require('redis.token_bucket').throttle(red, ngx, cache_key, rule)
    end

    if algorithm == 'sliding-window' then
        return require('redis.sliding_window').throttle(red, ngx, cache_key, rule)
    end

    return require('redis.fixed_window').throttle(red, ngx, cache_key, rule)
end

return _M
