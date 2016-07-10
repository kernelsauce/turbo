--- Turbo.lua Hello world example
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

local turbo = require "turbo"

-- Tables instead of a DB :)
local sessions = {}
local users = {["john@turbolua.org"] = "Secretz123"}


local LoginHandler = class("LoginHandler", turbo.web.RequestHandler)

function LoginHandler:post()
	local email = self:get_argument("email")
	local password = self:get_argument("password")
	if users[email] and users[email] == password then
		local session_id = turbo.util.rand_str(16)
		sessions[session_id] = {
			email = email,
			time = turbo.util.gettimeofday(),
			ip = self.request.host
		}
		self:set_cookie("turbo-session", session_id)
		self:write({status = "ok"})
		return
	end
	error(turbo.web.HTTPError(404, "invalid login attempt"))
end


local ExampleHandler = class("ExampleHandler", turbo.web.RequestHandler)

function CheckAuthentication(req)
	req.session_id = req:get_cookie("turbo-session")
	if not req.session_id or not sessions[req.session_id] then
		error(turbo.web.HTTPError(403, "no valid session found"))
	end
	req.session = sessions[req.session_id]
end

ExampleHandler.get = {
	pre = {CheckAuthentication},
    main = function(self)
    	self:write("Welcome " .. self.session.email ..
    		" you logged in from " .. self.session.ip)
    end
}

turbo.web.Application({
	{"^/$", ExampleHandler},
	{"^/login$", LoginHandler},
}):listen(8888)
turbo.ioloop.instance():start()
