describe('redis main', function()
    it('caches script using provided key', function()
        local cache = {}
        cache.get = function() return nil end
        cache.set = function(_, key, val) cache.last_key = key; cache.last_val = val end
        local ngx = {
            shared = { redis_scripts_cache = cache },
            log = function() end,
            ERR = 'err'
        }
        local red = { script = function(_, _) return 'sha1' end }
        package.loaded['redis.main'] = nil
        local redis_main = require('redis.main')
        local sha = redis_main.get_cached_script(red, ngx, 'my_script_sha', 'script')
        assert.equals('sha1', sha)
        assert.equals('my_script_sha', cache.last_key)
        assert.equals('sha1', cache.last_val)
    end)
end)
