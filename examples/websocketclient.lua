--- Turbo.lua WebSocketClient example.
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

_G.TURBO_SSL = true -- SSL must be enabled for WebSocket support!
local turbo = require "turbo"

turbo.ioloop.instance():add_callback(function()
    turbo.websocket.WebSocketClient("ws://127.0.0.1:8888/ws", {
        on_headers = function(self, headers)
            -- Review headers received from the WebSocket server.
            -- You can e.g drop the request if the response headers
            -- are not satisfactory with self:close().
        end,
        modify_headers = function(self, headers)
            -- Modify outgoing headers before they are sent.
            -- headers parameter are a instance of httputil.HTTPHeader.
        end,
        on_connect = function(self)
            -- Called when the client has successfully opened a WebSocket
            -- connection to the server.
            -- When the connection is established you can write a message:
            self:write_message("Hello World!")
        end,
        on_message = function(self, msg)
            -- Print the incoming message.
            print(msg)
            self:close()
        end,
        on_close = function(self)
            -- I am called when connection is closed. Both gracefully and
            -- not gracefully.
            os.exit(0)
        end,
        on_error = function(self, code, reason)
            -- I am called whenever there is a error with the WebSocket.
            -- code are defined in turbo.websocket.errors. reason are
            -- a string representation of the same error.
        end
    })
end):start()
