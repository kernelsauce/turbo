-- Turbo Unit test
--
-- Copyright 2013 John Abrahamsen
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

_G.TURBO_SSL = true
_G.__TURBO_USE_LUASOCKET__ = os.getenv("TURBO_USE_LUASOCKET") and true or false
local turbo = require "turbo"

describe("turbo.async Namespace", function()
    it("async.task", function()
        local io = turbo.ioloop.instance()

        local function typical_cb_func(num, cb, cb_arg)
            io:add_callback(function()
                assert.equal(num, 1234)
                cb(cb_arg,1,100,200,300,800)
            end)
        end

        -- Only global instance is supported for this convinience function.
        io:add_callback(function()
            local r1,r2,r3,r4,r5 = coroutine.yield (turbo.async.task(typical_cb_func, 1234))
            assert.equal(r1, 1)
            assert.equal(r2, 100)
            assert.equal(r3, 200)
            assert.equal(r4, 300)
            assert.equal(r5, 800)
            io:close()
        end)
        io:wait(2)
    end)

    it("Cookie support", function()
        local port = math.random(10000,40000)
        local io = turbo.ioloop.instance()
        local ExampleHandler = class("ExampleHandler", turbo.web.RequestHandler)
        function ExampleHandler:get()
            assert.equal("testvalue", self:get_cookie("testcookie"))
            assert.equal("secondvalue", self:get_cookie("testcookie2"))
            self:write("Hello World!")
        end
        turbo.web.Application({{"^/$", ExampleHandler}}):listen(port)

        io:add_callback(function()
            local res = coroutine.yield(turbo.async.HTTPClient():fetch(
                "http://127.0.0.1:"..tostring(port).."/", {
                cookie = {
                    testcookie="testvalue",
                    testcookie2="secondvalue"
                }}))
            assert.falsy(res.error)
            assert.equal(res.body, "Hello World!")
            io:close()
        end)
        io:wait(5)
    end)

    it("HEAD redirect", function()
        local port = math.random(10000,40000)
        local io = turbo.ioloop.instance()

        io:add_callback(function()
            local res = coroutine.yield(
                turbo.async.HTTPClient():fetch("http://t.co/rKAeu0zUNV", {method = "HEAD", allow_redirects = true}))
            assert.falsy(res.error)
            assert(res.code == 200)
            io:close()
        end)
        io:wait(5)
    end)


    it("HTTPS different sites", function()
        local port = math.random(10000,40000)
        local io = turbo.ioloop.instance()

        io:add_callback(function()
            local res = coroutine.yield(
                turbo.async.HTTPClient():fetch("https://google.com/", {allow_redirects=true}))
            assert.falsy(res.error)
            assert(res.code == 200)


            local res = coroutine.yield(
                turbo.async.HTTPClient():fetch("https://microsoft.com/", {allow_redirects=true}))
            assert.falsy(res.error)
            assert(res.code == 200)


            local res = coroutine.yield(
                turbo.async.HTTPClient():fetch("https://amazon.com/", {allow_redirects=true}))
            assert.falsy(res.error)
            assert(res.code == 200)

            io:close()
        end)
        io:wait(60)
    end)

end)
