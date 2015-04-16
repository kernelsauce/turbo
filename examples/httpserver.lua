--- Turbo.lua Hello world using HTTPServer
--
-- Using the HTTPServer offers more control for the user, but less convenience.
-- In almost all cases you want to use turbo.web.RequestHandler.
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

local message = "Hello World!"
local header = turbo.httputil.HTTPHeaders()
header:add("Content-Length", tostring(message:len()))
header:add("Connection", "Keep-Alive")
header:set_status_code(200)
header:set_version("HTTP/1.1")

local hdr_msg = header:stringify_as_response()
local buf = hdr_msg .. "\r\n" ..  message

local function handle_request(request)
    -- This is the callback function for HTTPServer.
    -- It will be called with a HTTPRequest class instance for every request
    -- issued to the server.
    request:write(buf)
    request:finish()
end

-- Assign callback when creating HTTPServer.
local http_server = turbo.httpserver.HTTPServer(handle_request)
http_server:listen(8888)
turbo.ioloop.instance():start()