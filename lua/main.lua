local rate_limit = require("rate_limit")
local ngx = ngx

local status, err = pcall(function()
    rate_limit.throttle(ngx, _G.rules, _G.ignored_ips, _G.ignored_users, _G.ignored_urls, ngx.shared.global_throttle_cache)
end)

if not status then
    ngx.log(ngx.ERR, "lua exception: ", err)
end
