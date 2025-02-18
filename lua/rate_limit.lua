local global_throttle = require("resty.global_throttle")
local resty_ipmatcher = require("resty.ipmatcher")
local util = require("util")

local _M = {}

local CACHE_THRESHOLD = 0.001
local ALL_IPS_RANGE = '0.0.0.0/0'
local GLOBAL_PATH = '/'

local function apply_rate_limiting(path, key, rule, cache, throttle_config)
    local cache_key = path .. ":" .. key

    local my_throttle = global_throttle.new('local', rule.limit, rule.window, throttle_config)

    local _, desired_delay, err
    _, desired_delay, err = my_throttle:process(cache_key)

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

local function is_rate_limited(ngx, path, key, rules, cache, throttle_config)
    local path_rules = util.find_path_rules(ngx, path, rules) or rules[GLOBAL_PATH]
    if not path_rules then return false end

    if path_rules[key] then
        return apply_rate_limiting(path, key, path_rules[key], cache, throttle_config)
    end

    if util.is_valid_ip(key) then
        local ip_matcher = resty_ipmatcher.new(util.extract_ips(path_rules))
        if ip_matcher and ip_matcher:match(key) then
            return apply_rate_limiting(path, key, path_rules[ip_matcher:match(key)])
        end
    end

    if path_rules[ALL_IPS_RANGE] then
        return apply_rate_limiting(path, key, path_rules[ALL_IPS_RANGE], cache, throttle_config)
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

function _M.throttle(ngx, rules, ignored_ips, ignored_users, cache, throttle_config)
    local remote_ip = util.get_real_ip(ngx)
    local username = util.get_remote_user(ngx)
    local request_path = ngx.var.uri

    if (remote_ip and cache:get(request_path .. ":" .. remote_ip)) or (username and cache:get(request_path .. ":" .. username)) then
        return ngx.exit(ngx.HTTP_TOO_MANY_REQUESTS)
    end

    if is_ignored(remote_ip, username, ignored_ips, ignored_users) then
        return
    end

    if (remote_ip and is_rate_limited(ngx, request_path, remote_ip, rules, cache, throttle_config)) then
        return ngx.exit(ngx.HTTP_TOO_MANY_REQUESTS)
    end

    if (username and is_rate_limited(ngx, request_path, username, rules, cache, throttle_config)) then
        return ngx.exit(ngx.HTTP_TOO_MANY_REQUESTS)
    end
end

return {
    throttle = _M.throttle,
    apply_rate_limiting = apply_rate_limiting,
    is_rate_limited = is_rate_limited,
    is_ignored = is_ignored
}
