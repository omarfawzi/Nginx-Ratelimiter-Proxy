local _M = {}
local resty_ipmatcher = require("resty.ipmatcher")
local ALL_IPS_RANGE = '0.0.0.0/0'

local function extract_remote_user_from_authorization_header(header)
    local pos = string.find(header, ":", 1, true)
    return pos and string.sub(header, 1, pos - 1) or nil
end

function _M.get_remote_user(ngx)
    if ngx.var.remote_user then
        return ngx.var.remote_user
    elseif ngx.req.get_headers()['Authorization'] then
        return extract_remote_user_from_authorization_header(ngx.req.get_headers()['Authorization'])
    end

    return nil
end

function _M.is_valid_ip(ip)
    return resty_ipmatcher.parse_ipv4(ip) or resty_ipmatcher.parse_ipv6(ip) or
            resty_ipmatcher.new({ip}) or resty_ipmatcher.new({ip})
end

function _M.extract_ips(rate_limits)
    local rate_limit_ips = {}
    for key, value in pairs(rate_limits) do
        if key ~= ALL_IPS_RANGE and _M.is_valid_ip(key) then
            rate_limit_ips[key] = value
        end
    end
    return rate_limit_ips
end

return _M
