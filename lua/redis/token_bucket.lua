local _M = {}

local TOKEN_BUCKET_SCRIPT = [[
    local bucket_key = KEYS[1]
    local current_time = redis.call('TIME')[1]
    local last_refill = redis.call('HGET', bucket_key, 'last_refill')
    local tokens = redis.call('HGET', bucket_key, 'tokens')

    local capacity = tonumber(ARGV[1])
    local refill_rate = tonumber(ARGV[2])
    local request_tokens = tonumber(ARGV[3])

    if not last_refill then
        last_refill = current_time
        tokens = capacity
    end

    local elapsed_time = tonumber(current_time) - tonumber(last_refill)
    local new_tokens = math.min(capacity, tokens + (elapsed_time * refill_rate))

    if new_tokens < request_tokens then
        return 1
    end

    redis.call('HSET', bucket_key, 'tokens', new_tokens - request_tokens)
    redis.call('HSET', bucket_key, 'last_refill', current_time)
    redis.call('EXPIRE', bucket_key, ARGV[4])
    return 0
]]

function _M.throttle(red, ngx, cache_key, rule)
    local capacity = rule.limit
    local refill_rate = rule.limit / rule.window
    local ttl = rule.window

    local res, err = red:eval(TOKEN_BUCKET_SCRIPT, 1, cache_key, capacity, refill_rate, 1, ttl)
    if not res then
        ngx.log(ngx.ERR, "Token Bucket script failed: ", err)
        return false
    end

    red:set_keepalive(10000, 100)
    return res == 1
end

return _M