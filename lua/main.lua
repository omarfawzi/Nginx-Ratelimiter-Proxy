local rate_limit = require("rate_limit")
local ngx = ngx

local status, err = pcall(function()
    rate_limit.throttle(ngx, _G.rules, _G.ignored_ips, _G.ignored_users, ngx.shared.global_throttle_cache, {
        provider = 'memcached',
        host = os.getenv('DISTRIBUTED_CACHE_HOST'),
        port = os.getenv('DISTRIBUTED_CACHE_PORT'),
        connect_timeout = 50,
        max_idle_timeout = 50,
        pool_size = 50
    }, ngx.log)
end)

if not status then
    ngx.log(ngx.ERR, "lua exception: ", err)
end
