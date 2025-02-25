local _M = {}

local LEAKY_BUCKET_SCRIPT = [[
    local current_time = redis.call('TIME')[1]
    local last_time = redis.call('HGET', KEYS[1], 'last_time') or current_time
    local water_level = redis.call('HGET', KEYS[1], 'water_level') or 0

    last_time = tonumber(last_time)
    water_level = tonumber(water_level)

    local elapsed_time = current_time - last_time
    local leaked = elapsed_time * tonumber(ARGV[2])  -- Leak rate * elapsed time
    water_level = math.max(0, water_level - leaked)  -- Water level cannot be negative

    if water_level + 1 > tonumber(ARGV[1]) then
        return 1
    end

    water_level = water_level + 1
    redis.call('HSET', KEYS[1], 'water_level', water_level)
    redis.call('HSET', KEYS[1], 'last_time', current_time)
    redis.call('EXPIRE', KEYS[1], ARGV[3])  -- Expiration to avoid stale keys

    return 0
]]

function _M.throttle(red, ngx, cache_key, rule)
    local bucket_capacity = rule.limit
    local leak_rate = rule.limit / rule.window
    local expiration = rule.window

    local res, err = red:eval(LEAKY_BUCKET_SCRIPT, 1, cache_key, bucket_capacity, leak_rate, expiration)
    if not res then
        ngx.log(ngx.ERR, "Leaky Bucket Rate Limit script failed: ", err)
        return false
    end

    red:set_keepalive(10000, 100)
    return res == 1
end

return _M
