--- Turbo.lua SSL HTTP server example
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

TURBO_SSL = true -- Always set me when using SSL, before loading framework.
local turbo = require "turbo"

local SSL_Handler = class("SSL_Handler", turbo.web.RequestHandler)
function SSL_Handler:get()
    self:write("SSL is working!")
end

local application = turbo.web.Application:new({
    {"^/$", SSL_Handler}
})

application:listen(8888, nil, {
    ssl_options = {
        key_file = "./sslkeys/server.key",
        cert_file = "./sslkeys/server.crt"
    }
})
turbo.ioloop.instance():start()
