local _M = {}
local ALL_IPS_RANGE = '0.0.0.0/0'
local GLOBAL_PATH = '/'

local function extract_remote_user_from_authorization_header(header)
    local pos = string.find(header, ":", 1, true)
    return pos and string.sub(header, 1, pos - 1) or nil
end

function _M.matchPath(ngx, pattern, path)
    return ngx.re.match(path, pattern)
end

function _M.find_path_rules(ngx, path, rules)
    for pattern, pathRules in pairs(rules) do
        if pattern ~= GLOBAL_PATH and _M.matchPath(ngx, pattern, path) then
            return pathRules
        end
    end
end

function _M.build_cache_key(cache_key)
    local cache_prefix = os.getenv('CACHE_PREFIX') or ''

    return "{rate_limit}:" .. cache_prefix .. cache_key
end

function _M.get_real_ip(ngx)
    local cf_connecting_ip = ngx.var.http_cf_connecting_ip
    if cf_connecting_ip then
        return cf_connecting_ip
    end

    local x_forwarded_for = ngx.var.http_x_forwarded_for
    if x_forwarded_for then
        local real_ip = x_forwarded_for:match("([^,]+)")
        return real_ip
    end

    return ngx.var.remote_addr
end

function _M.add_to_local_cache(ngx, cache, cache_key, value, exptime)
    local ok, err = cache:safe_add(cache_key, value, exptime)
    if not ok then
        if err ~= "exists" then
            ngx.log(ngx.ERR, "failed to cache decision: ", err)
        end
    end
end

function _M.get_remote_user(ngx)
    if ngx.var.remote_user then
        return ngx.var.remote_user
    elseif ngx.req and ngx.req.get_headers()['Authorization'] then
        return extract_remote_user_from_authorization_header(ngx.req.get_headers()['Authorization'])
    end

    return nil
end

function _M.extract_ips(rate_limits)
    local rate_limit_ips = {}
    for key, value in pairs(rate_limits) do
        if key ~= ALL_IPS_RANGE then
            rate_limit_ips[key] = value
        end
    end
    return rate_limit_ips
end

return _M
