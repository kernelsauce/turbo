--- Turbo.lua Chat app using WebSockets.
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

local ChatRoom = class("ChatRoom")

function ChatRoom:initialize()
	self.persons = {}
	self.subscribers = {}
end

function ChatRoom:broadcast(nick, msg)
	local time = turbo.util.gettimeofday()
	for i = 1, #self.subscribers do
		local sub = self.subscribers[i]
		sub.socket:write_message(turbo.escape.json_encode {
			nick=nick,
			msg=msg,
			time=time
		})
	end
end

function ChatRoom:add(nick)
	for i=1, #self.persons do
		if self.persons[i].nick == nick then
			return false
		end
	end
	self.persons[#self.persons+1] = {nick=nick}
	return true
end

function ChatRoom:is_registered(nick)
	for i=1, #self.persons do
		if self.persons[i].nick == nick then
			return true
		end
	end
end

function ChatRoom:subscribe(nick, socket)
	table.insert(self.subscribers, {nick=nick, socket=socket})
end

function ChatRoom:unsubscribe(nick, socket)
	-- NYI
end


--- Chat Communication with WebSockets.
local ChatCom = class("ChatCom", turbo.websocket.WebSocketHandler)

function ChatCom:prepare()
	-- Prepare method is run before you enter WebSocket protocol land.
	-- You can then discard requests based on e.g cookies.
	self.nick = self:get_secure_cookie("nick")
	if not self.nick then
		-- User has not signed in.
		error(turbo.web.HTTPError(400))
	end
	if not self.options.chatroom:is_registered(self.nick) then
		error(turbo.web.HTTPError(400))
	end
end

function ChatCom:open()
	self.options.chatroom:subscribe(self.nick, self)
end

function ChatCom:on_message(msg)
    self.options.chatroom:broadcast(self.nick, msg)
end

local SignInHandler = class("SignInHandler", turbo.web.RequestHandler)

--- Handler to register nickname etc.
function SignInHandler:post()
	local nick = self:get_argument("nick")
	if not self.options.chatroom:add(nick) then
		self:write({ok=false})
		return
	end
	self:set_secure_cookie("nick", nick)
	self:write({ok=true})
end


local function main()
	local chatroom = ChatRoom()
	local app = turbo.web.Application(
	{
		{"^/chatcom$", ChatCom, {chatroom = chatroom}},
		{"^/signin$", SignInHandler, {chatroom = chatroom}},
		{"^/$", turbo.web.StaticFileHandler, "assets/index.html"},
		{"^/assets/(.*)$", turbo.web.StaticFileHandler, "assets/"}
	}, 
	{
		cookie_secret = "akofdkapokfposakfdsafasdåpfkadåpf"
	})

	app:listen(8888)
	turbo.ioloop.instance():start()
end

main()