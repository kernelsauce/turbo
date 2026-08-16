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

describe("turbo.websocket Namespace", function()

    local function make_handler(url_args)
        local stream = {
            set_close_callback = function() end,
            read_bytes = function() end,
        }
        local opened_with
        local handler = setmetatable({
            stream = stream,
            _url_args = url_args,
            open = function(self, ...)
                opened_with = {...}
            end,
        }, { __index = turbo.websocket.WebSocketHandler })
        return handler, function() return opened_with end
    end

    -- Regression: route captures (e.g. {"^/ws/(%d+)$", MyHandler}) were
    -- stored in self._url_args by RequestHandler.initialize like every
    -- other handler, but _continue_ws called self:open() with no
    -- arguments, so WebSocketHandler:open() never received them.
    it("WebSocketHandler:open should receive the URL capture arguments",
        function()
        local handler, opened_with = make_handler({"42", "extra"})

        handler:_continue_ws()

        assert.same({"42", "extra"}, opened_with())
    end)

    -- web.Application:_get_request_handlers does {path:match(pattern)},
    -- and Lua's string.match returns the whole match when the pattern has
    -- no captures, so a capture-less route never actually produces an
    -- empty _url_args through real dispatch, it's {path}.
    it("WebSocketHandler:open should receive the whole match for a \
        capture-less route", function()
        local handler, opened_with = make_handler({"/ws"})

        handler:_continue_ws()

        assert.same({"/ws"}, opened_with())
    end)

    -- Defensive: _url_args is nil for any WebSocketHandler not constructed
    -- via normal Application dispatch (e.g. a hand-built instance). Must
    -- not throw "bad argument #1 to 'unpack' (table expected, got nil)".
    it("WebSocketHandler:open should not error when _url_args is nil",
        function()
        local handler, opened_with = make_handler(nil)

        assert.has_no.errors(function()
            handler:_continue_ws()
        end)
        assert.same({}, opened_with())
    end)

end)
