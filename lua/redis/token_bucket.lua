local _M = {}

local TOKEN_BUCKET_SCRIPT = [[
    local bucket_key = KEYS[1]
    local current_time = tonumber(redis.call('TIME')[1])

    local capacity = tonumber(ARGV[1])
    local refill_rate = tonumber(ARGV[2])
    local request_tokens = tonumber(ARGV[3])
    local expiration = tonumber(ARGV[4])

    local data = redis.call('HMGET', bucket_key, 'last_refill', 'tokens')
    local last_refill = tonumber(data[1]) or current_time
    local tokens = tonumber(data[2]) or capacity

    -- Calculate new token count based on elapsed time
    local elapsed_time = current_time - last_refill
    local new_tokens = math.min(capacity, tokens + (elapsed_time * refill_rate))

    if new_tokens < request_tokens then
        return 1  -- Rate limit exceeded
    end

    new_tokens = new_tokens - request_tokens

    redis.call('HMSET', bucket_key, 'tokens', new_tokens, 'last_refill', current_time)
    redis.call('EXPIRE', bucket_key, expiration)

    return 0
]]

function _M.throttle(red, ngx, cache_key, rule)
    local capacity = rule.limit
    local refill_rate = rule.limit / rule.window
    local ttl = rule.window

    local script_sha = require('redis.main').get_cached_script(red, ngx, 'token_bucket_sha', TOKEN_BUCKET_SCRIPT)
    if not script_sha then
        return false
    end

    local res, err = red:evalsha(script_sha, 1, cache_key, capacity, refill_rate, 1, ttl)

    if not res then
        ngx.log(ngx.ERR, "Token Bucket Rate Limit script execution failed: ", err)
        return false
    end

    red:set_keepalive(10000, 100)
    return res == 1
end

return _M
