local global_throttle = require("resty.global_throttle")
local resty_ipmatcher = require("resty.ipmatcher")
local ngx = ngx
local ngx_exit = ngx.exit
local ngx_log = ngx.log
local ngx_ERR = ngx.ERR
local _M = {}
local DECISION_CACHE = ngx.shared.global_throttle_cache
local CACHE_THRESHOLD = 0.001
local ALL_IPS_RANGE = '0.0.0.0/0'

local memcached_config = {
   provider = 'memcached',
   host = os.getenv('MCROUTER_HOST'),
   port = os.getenv('MCROUTER_PORT'),
   connect_timeout = 50,
   max_idle_timeout = 50,
   pool_size = 50,
}

local ratelimits = _G.ratelimits or {}

local function extract_remote_user_from_authorization_header(header)
  local pos = string.find(header, ":", 1, true)
  return pos and string.sub(header, 1, pos - 1) or nil
end

local function get_remote_user()
    if ngx.var.remote_user then
        return ngx.var.remote_user
    elseif ngx.req.get_headers()['Authorization'] then
        return extract_remote_user_from_authorization_header(ngx.req.get_headers()['Authorization'])
    end

    return nil
end

local function apply_rate_limiting(path, key, rule)
    local cache_key = path .. ":" .. key
    if DECISION_CACHE:get(cache_key) then
        return true
    end

    local my_throttle, err = global_throttle.new('current', rule.limit, rule.window, memcached_config)
    if err then
        ngx.log(ngx.ERR, 'failed to initialize resty_global_throttle: ', err)
        return false
    end

    local desired_delay
    _, desired_delay, err = my_throttle:process(cache_key)
    if err then
      ngx.log(ngx.ERR, 'error while processing key: ', err)
      return false
    end

    if desired_delay then
        if desired_delay > CACHE_THRESHOLD then
          local ok
          ok, err = DECISION_CACHE:safe_add(cache_key, true, desired_delay)
          if not ok then
            if err ~= 'exists' then
              ngx_log(ngx_ERR, 'failed to cache decision: ', err)
            end
          end
        end
        ngx.header['X-Retry-After'] = desired_delay
        return true
    end

    return false
end

local function is_rate_limited(path, key, is_ip)
    local rules = ratelimits[path]
    if not rules then return false end

    local ip_matcher = is_ip and resty_ipmatcher.new({ key }) or nil

    for rule_key, rule in pairs(rules) do
        if rule_key ~= ALL_IPS_RANGE and (rule_key == key or (ip_matcher and ip_matcher:match(rule_key))) then
            return apply_rate_limiting(path, rule_key, rule)
        end
    end

    if rules[ALL_IPS_RANGE] then
        return apply_rate_limiting(path, ALL_IPS_RANGE, rules[ALL_IPS_RANGE])
    end

    return false
end

function _M.throttle()
    local remote_ip = ngx.var.remote_addr
    local username = get_remote_user()
    local request_path = ngx.var.uri

    if (remote_ip and is_rate_limited(request_path, remote_ip)) or (username and is_rate_limited(request_path, username)) then
        return ngx_exit(ngx.HTTP_TOO_MANY_REQUESTS)
    end
end

local status, err = pcall(function()
    _M.throttle()
end)

if not status then
    ngx.log(ngx.ERR, 'lua exception: ', err)
end

return _M
