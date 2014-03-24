--- Turbo.lua Hello WebSocket example
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
local turbo = require "turbo"

turbo.ioloop.instance():add_callback(function() 
	turbo.websocket.WebSocketClient("ws://127.0.0.1:8888/ws", {
		on_message = function(self, msg)
			print(msg)
		end,
		on_headers = function(self, headers)
			print("on_headers called! :)")
		end,
		modify_headers = function(self, headers)
			print("modify_headers called! :D")
		end,
		on_connect = function(self)
			self:write_message("Hello World!")
		end
	})
end):start()
