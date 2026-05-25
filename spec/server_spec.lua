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

_G.TURBO_SSL = false
_G.__TURBO_USE_LUASOCKET__ = os.getenv("TURBO_USE_LUASOCKET") and true or false
local turbo = require "turbo"

-- A minimal localhost request/response round-trip. This exercises the event
-- loop end to end (accept, read, write via epoll/kqueue). It regression-guards
-- the aarch64 epoll_event layout bug, where a packed struct misread epoll_wait
-- results, spun the loop on "no handler for fd: 0" and served nothing.
describe("HTTP server round-trip", function()

    before_each(function()
        _G.io_loop_instance = nil
    end)

    it("serves a request through the event loop", function()
        local port = math.random(20000, 40000)
        local io = turbo.ioloop.instance()
        local Handler = class("Handler", turbo.web.RequestHandler)
        function Handler:get() self:write("pong") end
        turbo.web.Application({{"^/$", Handler}}):listen(port)

        local code, body
        io:add_callback(function()
            local res = coroutine.yield(turbo.async.HTTPClient():fetch(
                "http://127.0.0.1:" .. tostring(port) .. "/"))
            code, body = res.code, res.body
            io:close()
        end)
        io:wait(5)

        assert.equal(code, 200)
        assert.equal(body, "pong")
    end)

end)
