--- Turbo.lua Unit test
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

_G.__TURBO_USE_LUASOCKET__ = os.getenv("TURBO_USE_LUASOCKET") and true or false
local TEST_WITH_SSL = os.getenv("TURBO_TEST_SSL")
if TEST_WITH_SSL then
    _G.TURBO_SSL = true
end

local turbo = require "turbo"
math.randomseed(turbo.util.gettimeofday())

describe("turbo.web Namespace", function()

    before_each(function()
        -- Make sure we start with a fresh global IOLoop to
        -- avoid random results.
        _G.io_loop_instance = nil
    end)

    describe("Application and RequestHandler classes", function()
        -- Most of tests here use the turbo.async.HTTPClient, so any errors
        -- in that will also show in these tests...
        it("Accept hello world.", function()
            local port = math.random(10000,40000)
            local io = turbo.ioloop.instance()
            local ExampleHandler = class("ExampleHandler", turbo.web.RequestHandler)
            function ExampleHandler:get()
                self:write("Hello World!")
            end
            turbo.web.Application({{"^/$", ExampleHandler}}):listen(port)

            io:add_callback(function()
                local res = coroutine.yield(turbo.async.HTTPClient():fetch(
                    "http://127.0.0.1:"..tostring(port).."/"))
                assert.falsy(res.error)
                assert.equal(res.body, "Hello World!")
                io:close()
            end)

            io:wait(5)
        end)

        it("Accept URL parameters", function()
            local port = math.random(10000,40000)
            local param = math.random(1000,10000)
            local io = turbo.ioloop.instance()
            local ExampleHandler = class("ExampleHandler", turbo.web.RequestHandler)
            function ExampleHandler:get(int, str)
                assert.equal(tonumber(int), param)
                assert.equal("testitem", str)
                self:write(int)
            end
            turbo.web.Application({
                {"^/(%d*)/(%a*)$", ExampleHandler}
            }):listen(port)

            io:add_callback(function()
                local res = coroutine.yield(turbo.async.HTTPClient():fetch(
                    "http://127.0.0.1:"..tostring(port).."/"..tostring(param).."/testitem"))
                assert.falsy(res.error)
                assert.equal(param, tonumber(res.body))
                io:close()
            end)

            io:wait(5)
        end)

        it("Accept GET parameters", function()
            local port = math.random(10000,40000)
            local io = turbo.ioloop.instance()
            local ExampleHandler = class("ExampleHandler", turbo.web.RequestHandler)
            function ExampleHandler:get()
                assert.equal(self:get_argument("item1"), "Hello")
                assert.equal(self:get_argument("item2"), "World")
                assert.equal(self:get_argument("item3"), "!")
                assert.equal(self:get_argument("item4"), "StrangeØÆØÅØLÆLØÆL@½$@£$½]@£}½")
                self:write("Hello World!")
            end
            turbo.web.Application({{"^/$", ExampleHandler}}):listen(port)

            io:add_callback(function()
                local res = coroutine.yield(turbo.async.HTTPClient():fetch(
                    "http://127.0.0.1:"..tostring(port).."/",
                    {
                        params={
                            item1="Hello",
                            item2="World",
                            item3="!",
                            item4="StrangeØÆØÅØLÆLØÆL@½$@£$½]@£}½"
                        }
                    }))
                assert.falsy(res.error)
                assert.equal(res.body, "Hello World!")
                io:close()
            end)

            io:wait(5)
        end)

        it("Accept POST multipart", function()
            local port = math.random(10000,40000)
            local io = turbo.ioloop.instance()
            local ExampleHandler = class("ExampleHandler", turbo.web.RequestHandler)
            function ExampleHandler:post()
                assert.equal(self:get_argument("item1"), "Hello")
                assert.equal(self:get_argument("item2"), "World")
                assert.equal(self:get_argument("item3"), "!")
                assert.equal(self:get_argument("item4"), "StrangeØÆØÅØLÆLØÆL@½$@£$½]@£}½")
                self:write("Hello World!")
            end
            turbo.web.Application({{"^/$", ExampleHandler}}):listen(port)

            io:add_callback(function()
                local res = coroutine.yield(turbo.async.HTTPClient():fetch(
                    "http://127.0.0.1:"..tostring(port).."/",
                    {
                        method="POST",
                        params={
                            item1="Hello",
                            item2="World",
                            item3="!",
                            item4="StrangeØÆØÅØLÆLØÆL@½$@£$½]@£}½"
                        }
                    }))
                assert.falsy(res.error)
                assert.equal(res.body, "Hello World!")
                io:close()
            end)

            io:wait(5)
        end)

        it("Accept JSON data", function()
            local port = math.random(10000,40000)
            local io = turbo.ioloop.instance()
            local ExampleHandler = class("ExampleHandler", turbo.web.RequestHandler)
            function ExampleHandler:post()
                json = self:get_json(true)
                assert.equal(json.item1, "Hello")
                assert.equal(json.item2, "StrangeØÆØÅØLÆLØÆL@½$@£$½]@£}½")
                self:write("Hello World!")
            end
            turbo.web.Application({{"^/$", ExampleHandler}}):listen(port)

            io:add_callback(function()
                local res = coroutine.yield(turbo.async.HTTPClient():fetch(
                    "http://127.0.0.1:"..tostring(port).."/",
                    {
                        method="POST",
                        body="{\"item1\": \"Hello\", \"item2\": \"StrangeØÆØÅØLÆLØÆL@½$@£$½]@£}½\"}"
                    }))
                assert.falsy(res.error)
                assert.equal(res.body, "Hello World!")
                io:close()
            end)

            io:wait(5)
        end)

        it("Test case for reported bug.", function()
            local port = math.random(10000,40000)
            local io = turbo.ioloop.instance()
            local closed = false
            turbo.log.categories.error = false
            turbo.log.categories.stacktrace = false

            local ExampleHandler = class("ExampleHandler", turbo.web.RequestHandler)
            function ExampleHandler:get()
                self:write("Hello World!")
            end
            turbo.web.Application({{"^/$", ExampleHandler}}):listen(port)

            io:add_callback(function()
                local hdr = "CONNECT mx2.mail2000.com.tw:25 HTTP/1.0\r\n\r\n"
                local sock, msg = turbo.socket.new_nonblock_socket(
                    turbo.socket.AF_INET,
                    turbo.socket.SOCK_STREAM,
                    0)
                if sock == -1 then
                    error("Could not create socket.")
                end
                local stream = turbo.iostream.IOStream:new(sock)
                local rc, msg = stream:connect(
                    "127.0.0.1",
                    port,
                    turbo.socket.AF_INET,
                    function()
                        stream:set_close_callback(function()
                            closed = true
                            io:close()
                        end)
                        coroutine.yield (turbo.async.task(stream.write, stream, hdr))
                        io:add_callback(function()
                            local res = coroutine.yield(turbo.async.HTTPClient():fetch(
                                "http://127.0.0.1:"..tostring(port).."/"))
                            assert.falsy(res.error)
                            assert.equal(res.body, "Hello World!")
                            io:close()
                        end)
                    end)
                if rc ~= 0 then
                    error("Could not connect")
                end
            end)

            io:wait(5)
            if not _G.__TURBO_USE_LUASOCKET__ then
                assert.equal(closed, true)
            end
            turbo.log.categories.error = true
            turbo.log.categories.stacktrace = true
        end)

        it("Supprt multiple cookies.", function()
            local port = math.random(10000,40000)
            local io = turbo.ioloop.instance()

            local test_value1 = "fghjrtopy67askdopfkaopsdkfkasodfkopkpp"
            local test_value2 = "@£¥£$½¥£$½¥¼‰/(%&)&/()"

            local SetCookieHandler = class("SetCookieHandler", turbo.web.RequestHandler)
            function SetCookieHandler:get()
                self:set_cookie("TestValue", test_value1)
                self:set_cookie("TestValue2", test_value2)
                self:write("Hello World!")
            end

            local GetCookieHandler = class("GetCookieHandler", turbo.web.RequestHandler)
            function GetCookieHandler:get()
                assert.equal(self:get_cookie("TestValue"), test_value1)
                assert.equal(self:get_cookie("TestValue2"), test_value2)
                self:write("Hello World!")
            end

            turbo.web.Application({
                {"^/set$", SetCookieHandler},
                {"^/get$", GetCookieHandler},
            }):listen(port)

            io:add_callback(function()
                local res = coroutine.yield(turbo.async.HTTPClient():fetch(
                    "http://127.0.0.1:"..tostring(port).."/set"))
                assert.falsy(res.error)
                assert.equal(res.body, "Hello World!")
                local cookiestr = res.headers:get("Set-Cookie")

                local res = coroutine.yield(turbo.async.HTTPClient():fetch(
                    "http://127.0.0.1:"..tostring(port).."/get", {
                        on_headers = function(h)
                            h:add("Cookie", cookiestr[1])
                            h:add("Cookie", cookiestr[2])
                        end
                    }))
                io:close()
            end)
            io:wait(5)

        end)

        it("Support cookie.", function()
            local port = math.random(10000,40000)
            local io = turbo.ioloop.instance()

            local test_value1 = "fghjrtopy67askdopfkaopsdkfkasodfkopkpp"

            local SetCookieHandler = class("SetCookieHandler", turbo.web.RequestHandler)
            function SetCookieHandler:get()
                self:set_cookie("TestValue", test_value1)
                self:write("Hello World!")
            end

            local GetCookieHandler = class("GetCookieHandler", turbo.web.RequestHandler)
            function GetCookieHandler:get()
                assert.equal(self:get_cookie("TestValue"), test_value1)
                self:write("Hello World!")
            end

            turbo.web.Application({
                {"^/set$", SetCookieHandler},
                {"^/get$", GetCookieHandler},
            }):listen(port)

            io:add_callback(function()
                local res = coroutine.yield(turbo.async.HTTPClient():fetch(
                    "http://127.0.0.1:"..tostring(port).."/set"))
                assert.falsy(res.error)
                assert.equal(res.body, "Hello World!")
                local cookiestr = res.headers:get("Set-Cookie")

                local res = coroutine.yield(turbo.async.HTTPClient():fetch(
                    "http://127.0.0.1:"..tostring(port).."/get", {
                        on_headers = function(h)
                            h:add("Cookie", cookiestr)
                        end
                    }))
                io:close()
            end)
            io:wait(5)

        end)

        if TEST_WITH_SSL then
        it("Support multiple secure cookies.", function()
            local port = math.random(10000,40000)
            local io = turbo.ioloop.instance()

            local test_value1 = "fghjrtopy67askdopfkaopsdkfkasodfkopkpp"
            local test_value2 = "@£¥£$½¥£$½¥¼‰/(%&)&/()"

            local SetCookieHandler = class("SetCookieHandler", turbo.web.RequestHandler)
            function SetCookieHandler:get()
                self:set_secure_cookie("TestValue", test_value1)
                self:set_secure_cookie("TestValue2", test_value2)
                self:write("Hello World!")
            end

            local GetCookieHandler = class("GetCookieHandler", turbo.web.RequestHandler)
            function GetCookieHandler:get()
                assert.equal(self:get_secure_cookie("TestValue"), test_value1)
                assert.equal(self:get_secure_cookie("TestValue2"), test_value2)
                self:write("Hello World!")
            end

            turbo.web.Application({
                {"^/set$", SetCookieHandler},
                {"^/get$", GetCookieHandler},
            }, {cookie_secret="akpodpo0jsadasjdfoj24234øæ"}):listen(port)

            io:add_callback(function()
                local res = coroutine.yield(turbo.async.HTTPClient():fetch(
                    "http://127.0.0.1:"..tostring(port).."/set"))
                assert.falsy(res.error)
                assert.equal(res.body, "Hello World!")
                local cookiestr = res.headers:get("Set-Cookie")

                local res = coroutine.yield(turbo.async.HTTPClient():fetch(
                    "http://127.0.0.1:"..tostring(port).."/get", {
                        on_headers = function(h)
                            h:add("Cookie", cookiestr[1])
                            h:add("Cookie", cookiestr[2])
                        end
                    }))
                io:close()
            end)
            io:wait(5)
        end)
        end


    end)

end)
