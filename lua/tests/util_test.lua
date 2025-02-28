local ngx_mock = {
    var = {
        http_cf_connecting_ip = nil,
        http_x_forwarded_for = nil,
        remote_addr = '192.168.1.1',
        remote_user = nil,
    },
    req = {
        get_headers = function()
            return {}
        end
    },
    re = {
        match = function(path, pattern)
            return path:match(pattern) ~= nil
        end
    }
}

local util = require('util')
local os = require("os")
local stub = require('luassert.stub')

describe("Utilities", function()
    before_each(function()
        stub(os, 'getenv').returns('remote_addr')
    end)

    local function set_real_ip(ip_key, ip_value)
        stub(os, 'getenv').returns(ip_key)
    end

    it("should extract remote user from Authorization header", function()
        local result = util.get_remote_user({
            var = {},
            req = {
                get_headers = function()
                    return { Authorization = "user123:password" }
                end
            }
        })
        assert.are.equal(result, "user123")
    end)

    it("should return nil when no Authorization header is present", function()
        local result = util.get_remote_user(ngx_mock)
        assert.is_nil(result)
    end)

    it("should return correct real IP from CF-Connecting-IP header", function()
        set_real_ip('http_cf_connecting_ip', '203.0.113.1')
        ngx_mock.var.http_cf_connecting_ip = '203.0.113.1'
        local result = util.get_real_ip(ngx_mock)
        assert.are.equal(result, '203.0.113.1')
        ngx_mock.var.http_cf_connecting_ip = nil -- reset
    end)

    it("should return correct real IP from X-Forwarded-For header", function()
        set_real_ip('http_x_forwarded_for', '198.51.100.1, 198.51.100.2')
        ngx_mock.var.http_x_forwarded_for = '198.51.100.1, 198.51.100.2'
        local result = util.get_real_ip(ngx_mock)
        assert.are.equal(result, '198.51.100.1')
        ngx_mock.var.http_x_forwarded_for = nil -- reset
    end)

    it("should return remote_addr if no other headers are present", function()
        set_real_ip('remote_addr', '192.168.1.1')
        local result = util.get_real_ip(ngx_mock)
        assert.are.equal(result, '192.168.1.1')
    end)

    it("should extract IPs from rate limits table", function()
        local rate_limits = {
            ['192.168.1.2'] = 100,
            ['10.0.0.1'] = 200,
            ['0.0.0.0/0'] = 300
        }
        local extracted = util.extract_ips(rate_limits)
        assert.are.equal(extracted['192.168.1.2'], 100)
        assert.are.equal(extracted['10.0.0.1'], 200)
        assert.is_nil(extracted['0.0.0.0/0'])
    end)

    it("should find matching path rules", function()
        local rules = {
            ['/api/.*'] = { rate = 100 },
            ['/admin'] = { rate = 50 }
        }
        local result = util.find_path_rules(ngx_mock, '/api/test', rules)
        assert.are.same(result, { rate = 100 })
    end)

    it("should return nil when no matching path rule is found", function()
        local rules = {
            ['/admin'] = { rate = 50 }
        }
        local result = util.find_path_rules(ngx_mock, '/user', rules)
        assert.is_nil(result)
    end)

end)
