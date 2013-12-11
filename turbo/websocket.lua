--- Turbo.lua Websocket module.
--
-- Websockets according to the RFC 6455. http://tools.ietf.org/html/rfc6455
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

local log =             require "turbo.log"
local httputil =        require "turbo.httputil"
local httpserver =      require "turbo.httpserver"
local buffer =          require "turbo.structs.buffer"
local escape =          require "turbo.escape"
local util =            require "turbo.util"
local hash =            require "turbo.hash"
local web =             require "turbo.web"
require('turbo.3rdparty.middleclass')

local websocket = {}

websocket.WebSocketHandler = class("WebSocketHandler", web.RequestHandler)

function websocket.WebSocketHandler:initialize(application, 
                                               request, 
                                               url_args, 
                                               options)
    web.RequestHandler.initialize(self, application, request, url_args, options)
    self.stream = request.connection.stream
end

--- Main entry point for the Application class.
function websocket.WebSocketHandler:_execute()
    if self.request.method ~= "GET" then
        error(web.HTTPError(
            405, 
            "Method not allowed. Websocket supports GET only."))
    end
    local upgrade = self.request.headers:get("Upgrade")
    if not upgrade or upgrade:lower() ~= "websocket" then
        error(web.HTTPError(
            400, 
            "Expected a valid \"Upgrade\" HTTP header."))
    end

    self:prepare()

end

return websocket
