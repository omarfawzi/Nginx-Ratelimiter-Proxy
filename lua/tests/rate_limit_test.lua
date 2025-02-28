package.loaded["resty.global_throttle"] = {
    new = function()
        return {
            process = function() return nil, nil, nil end
        }
    end
}

local bit = require("bit")

local function ip_to_number(ip)
    local o1, o2, o3, o4 = ip:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")
    return bit.bor(bit.lshift(tonumber(o1), 24),
            bit.lshift(tonumber(o2), 16),
            bit.lshift(tonumber(o3), 8),
            tonumber(o4))
end

local function is_ip_in_cidr(ip, cidr)
    local network, prefix = cidr:match("(.+)/(%d+)")
    if not network or not prefix then return false end

    local ip_num = ip_to_number(ip)
    local net_num = ip_to_number(network)
    local mask = bit.band(0xFFFFFFFF, bit.lshift(0xFFFFFFFF, (32 - tonumber(prefix))))

    return bit.band(ip_num, mask) == bit.band(net_num, mask)
end


package.loaded["resty.ipmatcher"] = {
    new = function(ignored_ips)
        return {
            match = function(_, ip)
                for _, ignored_ip in ipairs(ignored_ips or {}) do
                    if ignored_ip:find("/") then
                        if is_ip_in_cidr(ip, ignored_ip) then
                            return true
                        end
                    elseif ip == ignored_ip then  -- Direct match
                        return true
                    end
                end
                return false
            end
        }
    end
}

local mock = require('luassert.mock')
local stub = require('luassert.stub')
local spy = require('luassert.spy')

local function mock_ngx()
    return {
        var = { uri = '/' },
        log = function() end,
        exit = function() end,
        HTTP_TOO_MANY_REQUESTS = 429,
        re = {
            match = function(path, pattern)
                return string.match(path, pattern)
            end
        }
    }
end

describe('Rate Limiting', function()
    local ngx, cache, rules
    local rate_limit

    before_each(function()
        ngx = mock_ngx()
        cache = mock({
            get = function() return nil end,
            safe_add = function() return true end
        })
        rules = {
            ['/v1'] = {
                ips = { ['127.0.0.1'] = { limit = 10, window = 60 } },
                users = { ['test_user'] = { limit = 5, window = 60 } }
            },
            ['/v2'] = {
                ips = { ['0.0.0.0/0'] = { limit = 10, window = 60 } },
                users = { ['test_user_2'] = { limit = 5, window = 60 } }
            }
        }

        spy.on(ngx, 'exit')

        rate_limit = require("rate_limit")

        stub(rate_limit, 'apply_rate_limiting', true)

        stub(os, 'getenv').returns('remote_addr')
    end)

    after_each(function()
        mock.revert(ngx)   -- Reset ngx mocks
        mock.revert(cache) -- Reset cache mocks
        package.loaded["rate_limit"] = nil -- Force reload of rate_limit next time
    end)

    it('should apply rate limiting for matching IP', function()
        ngx.var.uri = '/v1'
        ngx.var.remote_addr = '127.0.0.1'

        rate_limit.throttle(ngx, rules, {}, {}, {}, cache)

        assert.stub(rate_limit.apply_rate_limiting).was.called(1)
    end)

    it('should apply rate limiting for matching user', function()
        ngx.var.remote_user = 'test_user'
        ngx.var.uri = '/v1'

        rate_limit.throttle(ngx, rules, {}, {}, {}, cache)

        assert.spy(ngx.exit).was.called_with(ngx.HTTP_TOO_MANY_REQUESTS)
    end)

    it('should not apply rate limiting for non matching user or ip', function()
        ngx.var.uri = '/v1'
        ngx.var.remote_user = 'non_matching_user'
        ngx.var.remote_addr = '186.0.0.1'

        rate_limit.throttle(ngx, rules, {}, {}, {}, cache)

        assert.spy(ngx.exit).was_not_called()
    end)

    it('should not throttle ignored IPs', function()

        ngx.var.uri = '/v1'
        ngx.var.remote_addr = '127.0.0.1'

        rate_limit.throttle(ngx, rules, {'127.0.0.1'}, {}, {}, cache)

        assert.spy(ngx.exit).was_not_called()
    end)

    it('should not throttle ignored URLs', function()
        ngx.var.uri = '/v1/ping'
        ngx.var.remote_addr = '127.0.0.1'

        rate_limit.throttle(ngx, rules, {}, {}, {'/v1/ping'}, cache)

        assert.spy(ngx.exit).was_not_called()
    end)

    it('should not throttle ignored Users', function()
        ngx.var.uri = '/v1'
        ngx.var.remote_user = 'ignored_user'

        rate_limit.throttle(ngx, rules, {}, {'ignored_user'}, {}, cache)

        assert.spy(ngx.exit).was_not_called()
    end)

    it('should not throttle non matching URIs', function()
        ngx.var.uri = '/v3'
        ngx.var.remote_addr = '127.0.0.1'

        rate_limit.throttle(ngx, rules, {}, {}, {}, cache)

        assert.spy(ngx.exit).was_not_called()
    end)

    it('should throttle user when over limit', function()
        cache.get = function() return true end

        ngx.var.uri = '/v1'
        ngx.var.remote_addr = '127.0.0.1'
        rate_limit.throttle(ngx, rules, {}, {}, {}, cache)

        assert.spy(ngx.exit).was.called_with(ngx.HTTP_TOO_MANY_REQUESTS)
    end)

    it('should fallback to global CIDR if available', function()
        ngx.var.uri = '/v2'
        ngx.var.remote_addr = '127.0.0.1'

        rate_limit.throttle(ngx, rules, {}, {}, {}, cache)

        assert.spy(ngx.exit).was.called_with(ngx.HTTP_TOO_MANY_REQUESTS)
    end)

    it('should fallback to global URI if available', function()
        rules['/'] = {
            ips = { ['127.0.0.1'] = { limit = 10, window = 60 } },
            users = { ['test_user'] = { limit = 5, window = 60 } }
        }

        ngx.var.uri = '/v3'
        ngx.var.remote_addr = '127.0.0.1'

        rate_limit.throttle(ngx, rules, {}, {}, {}, cache)

        assert.spy(ngx.exit).was.called_with(ngx.HTTP_TOO_MANY_REQUESTS)
    end)

end)
