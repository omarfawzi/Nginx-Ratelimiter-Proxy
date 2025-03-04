local _M = {}

local LEAKY_BUCKET_SCRIPT = [[
    local current_time = tonumber(redis.call('TIME')[1])

    local bucket_capacity = tonumber(ARGV[1])
    local leak_rate = tonumber(ARGV[2])
    local expiration = tonumber(ARGV[3])

    local data = redis.call('HMGET', KEYS[1], 'last_time', 'water_level')
    local last_time = tonumber(data[1]) or current_time
    local water_level = tonumber(data[2]) or 0

    local elapsed_time = current_time - last_time
    local leaked = elapsed_time * leak_rate
    water_level = math.max(0, water_level - leaked)

    if water_level + 1 > bucket_capacity then
        return 1
    end

    water_level = water_level + 1

    redis.call('HMSET', KEYS[1], 'last_time', current_time, 'water_level', water_level)
    redis.call('EXPIRE', KEYS[1], expiration)

    return 0
]]

function _M.throttle(red, ngx, cache_key, rule)
    local bucket_capacity = rule.limit
    local leak_rate = rule.flowRate or (rule.limit / rule.window)
    local expiration = rule.window

    local script_sha = require('redis.main').get_cached_script(red, ngx, 'leaky_bucket_sha', LEAKY_BUCKET_SCRIPT)
    local res, err
    if not script_sha then
        res, err = red:eval(LEAKY_BUCKET_SCRIPT, 1, cache_key, bucket_capacity, leak_rate, expiration)
    else
        res, err = red:evalsha(script_sha, 1, cache_key, bucket_capacity, leak_rate, expiration)
    end

    if not res then
        ngx.log(ngx.ERR, "Leaky Bucket Rate Limit script execution failed: ", err)
        return false
    end

    red:set_keepalive(10000, 100)
    return res == 1
end

return _M
