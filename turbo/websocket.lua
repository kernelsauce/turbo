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
local strf = string.format

-- *** Public API ***

local websocket = {}
websocket.MAGIC = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

websocket.WebSocketHandler = class("WebSocketHandler", web.RequestHandler)

function websocket.WebSocketHandler:initialize(application, 
                                               request,
                                               url_args,
                                               options)
    web.RequestHandler.initialize(self, application, request, url_args, options)
    self.stream = request.connection.stream
end

--- Called when a new websocket request is opened.
function websocket.WebSocketHandler:open() end

--- Called when a message the client is recieved.
-- @param msg (String) The recieved message.
function websocket.WebSocketHandler:on_message(msg) end

--- Called when the connection is closed.
function websocket.WebSocketHandler:on_close() end

--- Send a message to the client of the active Websocket.
-- @param msg The message to send. This may be either a JSON-serializable table
-- or a string.
-- @param binary (Boolean) Treat the message as binary data.
-- If the connection has been closed a error is raised.
function websocket.WebSocketHandler:write_message(msg, 
                                                  binary, 
                                                  callback, 
                                                  callback_arg)
    
end

--- Send a ping to the connected client.
function websocket.WebSocketHandler:ping(callback, callback_arg)

--- Close the connection.
function websocket.WebSocketHandler:close()

-- *** Private API ***

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
    self.sec_websocket_key = self.request.headers:get("Sec-WebSocket-Key")
    if not self.sec_websocket_key then
        error("Client did not send a Sec-WebSocket-Key field. \
               Probably not a Websocket requets, can not upgrade.")
    end
    self.sec_websocket_version = 
        self.request.headers:get("Sec-WebSocket-Version")
    if not self.sec_websocket_version then
        error("Client did not send a Sec-WebSocket-Version field. \
               Probably not a Websocket requets, can not upgrade.")
    end
    if not self.websocket_version == "13" then
        error(strf("Client wants to use not implemented Websocket Version %s.\
                    Can not upgrade.", self.websocket_version))
    end
    self.sec_websocket_protocol = 
        self.request.headers:get("Sec-WebSocket-Protocol")
    self:prepare()
end

function websocket.WebSocketHandler:_calculate_ws_accept()
    local hash = hash.SHA1(self.sec_websocket_key..websocket.MAGIC)
    self.handshake_digest = escape.base64_encode(hash:finalize())
end

return websocket
