--- Turbo.lua Static file server example
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

local app = turbo.web.Application:new({
    -- Serve single index.html file on root requests.
    {"^/$", turbo.web.StaticFileHandler, "/var/www/index.html"},
    -- Serve contents of directory.
    {"^/(.*)$", turbo.web.StaticFileHandler, "/var/www/"}
})

local srv = turbo.httpserver.HTTPServer(app)
srv:bind(8888)
srv:start(1) -- Adjust amount of processes to fork.

turbo.ioloop.instance():start()
