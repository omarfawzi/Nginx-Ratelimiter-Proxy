local global_throttle = require("resty.global_throttle")
local resty_ipmatcher = require("resty.ipmatcher")
local util = require("util")

local _M = {}

local CACHE_THRESHOLD = 0.001
local ALL_IPS_RANGE = '0.0.0.0/0'
local GLOBAL_PATH = '/' 

local function apply_rate_limiting(path, key, rule, cache, throttle_config)
    local cache_key = path .. ":" .. key
    if cache:get(cache_key) then
        return true
    end

    local my_throttle = global_throttle.new('local', rule.limit, rule.window, throttle_config)

    local _, desired_delay
    _, desired_delay, err = my_throttle:process(cache_key)

    if err then
        ngx.log(ngx.ERR, "Error while throttling: ", err)
    end

    if desired_delay and desired_delay > CACHE_THRESHOLD then
        cache:safe_add(cache_key, true, desired_delay)
        return true
    end

    return false
end

local function is_rate_limited(path, key, rules, cache, throttle_config)
    if not rules then return false end

    if rules[key] then
        return apply_rate_limiting(path, key, rules[key], cache, throttle_config)
    end

    if util.is_valid_ip(key) then
        local ip_matcher = resty_ipmatcher.new(util.extract_ips(rules))
        if ip_matcher and ip_matcher:match(key) then
            return apply_rate_limiting(path, key, rules[ip_matcher:match(key)])
        end
    end

    if rules[ALL_IPS_RANGE] then
        return apply_rate_limiting(path, key, rules[ALL_IPS_RANGE], cache, throttle_config)
    end

    return false
end

local function is_ignored(ip, user, ignored_ips, ignored_users)
    local ip_matcher = resty_ipmatcher.new(ignored_ips)
    if ip_matcher:match(ip) then
        return true
    end

    for _, ignored_user in ipairs(ignored_users) do
        if user == ignored_user then
            return true
        end
    end

    return false
end

function _M.throttle(ngx, ratelimits, ignored_ips, ignored_users, cache, throttle_config)
    local remote_ip = ngx.var.remote_addr
    local username = util.get_remote_user(ngx)
    local request_path = ngx.var.uri

    if is_ignored(remote_ip, username, ignored_ips, ignored_users) then
        return
    end

    if (remote_ip and is_rate_limited(request_path, remote_ip, ratelimits[request_path] or ratelimits[GLOBAL_PATH], cache, throttle_config)) then
        return ngx.exit(ngx.HTTP_TOO_MANY_REQUESTS)
    end

    if (username and is_rate_limited(request_path, username, ratelimits[request_path] or ratelimits[GLOBAL_PATH], cache, throttle_config)) then
        return ngx.exit(ngx.HTTP_TOO_MANY_REQUESTS)
    end
end

return {
    throttle = _M.throttle,
    apply_rate_limiting = apply_rate_limiting,
    is_rate_limited = is_rate_limited,
    is_ignored = is_ignored
}
