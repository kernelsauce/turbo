--- Turbo.lua Secure Cookie example
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

TURBO_SSL = true
local turbo = require "turbo"

local CookieHandler = class("CookieHandler", turbo.web.RequestHandler)

function CookieHandler:get()
    local counter = self:get_secure_cookie("counter")
    local new_count = counter and tonumber(counter) + 1 or 0
    self:set_secure_cookie("id", "supersecretrandomid!")
    self:write("Cookie counter is at: " .. new_count)
    self:set_secure_cookie("counter", new_count)
end

turbo.web.Application({{"^/$", CookieHandler}}, {
	cookie_secret = "kasoidkfsadfsai12#¤1234123'å421å4l1åplåpk<ok<lkcmlk<cxp"
	}):listen(8888)
turbo.ioloop.instance():start()