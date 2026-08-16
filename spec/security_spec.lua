--- Turbo.lua Unit test
--
-- Copyright 2026 John Abrahamsen
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

_G.__TURBO_USE_LUASOCKET__ = os.getenv("TURBO_USE_LUASOCKET") and true or false
_G.TURBO_SSL = true

local turbo = require "turbo"
local hash = require "turbo.hash"

describe("Security fixes", function()

    before_each(function()
        _G.io_loop_instance = nil
    end)

    describe("escape.html_escape", function()

        it("should raise an error when passed a non-string (nil)", function()
            assert.has_error(function()
                turbo.escape.html_escape(nil)
            end)
        end)

        it("should raise an error when passed a number", function()
            assert.has_error(function()
                turbo.escape.html_escape(42)
            end)
        end)

        it("should raise an error when passed a table", function()
            assert.has_error(function()
                turbo.escape.html_escape({})
            end)
        end)

        it("should escape HTML special characters in a valid string", function()
            assert.equal(
                turbo.escape.html_escape('<script>alert("xss")</script>'),
                "&lt;script&gt;alert(&quot;xss&quot;)&lt;&#47;script&gt;"
            )
        end)

        it("should escape ampersands", function()
            assert.equal(turbo.escape.html_escape("a & b"), "a &amp; b")
        end)

        it("should escape single quotes", function()
            assert.equal(turbo.escape.html_escape("it's"), "it&#39;s")
        end)

        it("should return unchanged string when no special chars present", function()
            assert.equal(turbo.escape.html_escape("hello world"), "hello world")
        end)

    end)

    -- get_secure_cookie is exercised via a minimal mock to avoid HTTP server
    -- SSL loading-order issues under busted.
    describe("secure cookies", function()
        local secret = "test_cookie_secret_key"

        -- Build a valid cookie string the same way set_secure_cookie does.
        -- The cookie name is part of the signed message (but not stored).
        local function make_cookie(name, value, s)
            local ts = tostring(math.floor(turbo.util.gettimeofday()))
            local len = tostring(#value)
            local sig = hash.HMAC(s,
                string.format("%s|%s|%s|%s", name, len, ts, value))
            return string.format("%s|%s|%s|%s", sig, len, ts, value)
        end

        -- Minimal mock: a table that inherits RequestHandler methods but has
        -- just enough state for get_cookie / get_secure_cookie to work.
        local function make_handler(cookie_name, cookie_str, s)
            local headers = turbo.httputil.HTTPHeaders:new()
            headers:set("Cookie", cookie_name .. "=" .. cookie_str)
            return setmetatable({
                request = { headers = headers },
                application = { kwargs = { cookie_secret = s } },
                _cookies_parsed = false,
                _cookies = {},
            }, { __index = turbo.web.RequestHandler })
        end

        it("should accept a valid signed cookie", function()
            local val = "mysessiontoken"
            local handler = make_handler("session",
                make_cookie("session", val, secret), secret)
            assert.equal(handler:get_secure_cookie("session"), val)
        end)

        -- Forged/stale cookies return the default, they do not raise.
        it("should return the default for a tampered HMAC", function()
            local cookie_str = make_cookie("session", "mysessiontoken", secret)
            -- Flip one hex digit of the HMAC, keeping the format intact.
            local c = cookie_str:sub(5, 5) == "a" and "b" or "a"
            local tampered = cookie_str:sub(1, 4)..c..cookie_str:sub(6)
            local handler = make_handler("session", tampered, secret)
            assert.equal(handler:get_secure_cookie("session", "fallback"),
                "fallback")
        end)

        it("should return the default for a cookie signed with another secret",
            function()
            local handler = make_handler("session",
                make_cookie("session", "mysessiontoken", "wrong_secret"),
                secret)
            assert.is_nil(handler:get_secure_cookie("session"))
        end)

        it("should return the default for a malformed cookie", function()
            local handler = make_handler("session", "not-a-cookie", secret)
            assert.equal(handler:get_secure_cookie("session", "fallback"),
                "fallback")
        end)

        -- Regression: the signature binds the name, so a value signed for one
        -- cookie name must not validate under a different name.
        it("should reject a value replayed under a different cookie name",
            function()
            local cookie_str = make_cookie("session", "mysessiontoken", secret)
            local as_admin = make_handler("admin", cookie_str, secret)
            assert.is_nil(as_admin:get_secure_cookie("admin"))
            -- Sanity: still valid under its real name.
            local as_session = make_handler("session", cookie_str, secret)
            assert.equal(as_session:get_secure_cookie("session"),
                "mysessiontoken")
        end)

    end)

    describe("util.secure_random_bytes", function()

        it("should return a string", function()
            local r = turbo.util.secure_random_bytes(16)
            assert.is_string(r)
        end)

        it("should return exactly the requested number of bytes", function()
            for _, n in ipairs({1, 4, 16, 32, 64, 256}) do
                assert.equal(#turbo.util.secure_random_bytes(n), n)
            end
        end)

        it("should return different values on successive calls", function()
            local a = turbo.util.secure_random_bytes(32)
            local b = turbo.util.secure_random_bytes(32)
            local c = turbo.util.secure_random_bytes(32)
            assert.not_equal(a, b)
            assert.not_equal(b, c)
            assert.not_equal(a, c)
        end)

        it("util.rand_str should use secure_random_bytes and return correct length", function()
            local s = turbo.util.rand_str(20)
            assert.is_string(s)
            assert.equal(#s, 20)
        end)

        it("util.rand_str default length should be 64 bytes", function()
            assert.equal(#turbo.util.rand_str(), 64)
        end)

        it("util.rand_str should only return printable characters", function()
            -- Callers put this straight into cookies and headers.
            for _, n in ipairs({1, 7, 20, 64}) do
                local s = turbo.util.rand_str(n)
                assert.equal(#s, n)
                assert.truthy(s:match("^[0-9a-f]+$"))
            end
        end)

    end)

    -- ssl_init only exists in the OpenSSL backend. The LuaSocket builds use
    -- LuaSec, which initializes itself.
    if turbo.platform.__LINUX__ and not _G.__TURBO_USE_LUASOCKET__ then
        describe("crypto.ssl_init", function()

            it("should initialize SSL without error", function()
                local crypto = require "turbo.crypto"
                assert.has_no.errors(function()
                    crypto.ssl_init()
                end)
            end)

            it("should be idempotent when called repeatedly", function()
                local crypto = require "turbo.crypto"
                assert.has_no.errors(function()
                    crypto.ssl_init()
                    crypto.ssl_init()
                end)
            end)

        end)
    end

end)
