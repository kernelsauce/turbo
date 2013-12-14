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
local async =           require "turbo.async"
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

--- Called if the client have included a Sec-WebSocket-Protocol field
-- in header. This method will then recieve a table of protocols that
-- the clients wants to use. If this field is not set, this method will
-- never be called. The return value of this method should be a string
-- which matches one of the suggested protcols in its parameter.
-- If all of the suggested protocols are unacceptable then dismissing of
-- the request is done by either raising error or returning nil.
function websocket.WebSocketHandler:subprotocol(protocols) end

--- Send a message to the client of the active Websocket.
-- @param msg The message to send. This may be either a JSON-serializable table
-- or a string.
-- @param binary (Boolean) Treat the message as binary data.
-- If the connection has been closed a error is raised.
function websocket.WebSocketHandler:write_message(msg, 
                                                  binary, 
                                                  callback, 
                                                  callback_arg)
    -- NYI
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
        log.error("Client did not send a Sec-WebSocket-Key field. \
               Probably not a Websocket requets, can not upgrade.")
        error(web.HTTPError(400, "Invalid protocol."))
    end
    self.sec_websocket_version = 
        self.request.headers:get("Sec-WebSocket-Version")
    if not self.sec_websocket_version then
        log.error("Client did not send a Sec-WebSocket-Version field. \
               Probably not a Websocket requets, can not upgrade.")
        error(web.HTTPError(400,"Invalid protocol."))
    end
    if not self.websocket_version == "13" then
        log.error(strf("Client wants to use not implemented Websocket Version %s.\
                    Can not upgrade.", self.websocket_version))
        error(web.HTTPError(400, "Invalid protocol."))
    end
    local prot = self.request.headers:get("Sec-WebSocket-Protocol")
    prot = prot:split(",")
    for i=0, #prot do
        prot[i] = escape.trim(prot[i])
    end
    if #prot ~= 0 then
        local selected_protocol = self:subprotocol(prot)
        if not selected_protocol then
            log.warning("No acceptable subprotocols for WebSocket were found.")
            error(web.HTTPError(400, "Invalid subprotocol."))
        end
        self.subprotocol = selected_protocol
    end
    self.origin = self.request.headers:get("Origin")
    local response_header = self:_create_response_header()
    -- According to RFC 6455 there must be no more than one socket
    -- in connecting state from the same host IP at the same time.
    if self.application._connecting_ws[self.request.remote_ip] then
        -- Another socket in connecting state exists.
        -- Wait for this to finish before continuing.
        table.insert(self.application._connecting_ws[self.request.remote_ip],
                     self)
    else
        self.application._connecting_ws[self.request.remote_ip] = {self}
        self._connecting_ws_state = true
        self:_do_ws_handshake()
    end
end

function websocket.WebSocketHandler:_calculate_ws_accept()
    local hash = hash.SHA1(self.sec_websocket_key..websocket.MAGIC)
    return escape.base64_encode(hash:finalize())
end

function websocket.WebSocketHandler:_create_response_header()
    local header = httputil.HTTPHeaders()
    header:set_status_code(101)
    header:set_version("HTTP/1.1")
    header:add("Upgrade", "websocket")
    header:add("Connection", "Upgrade")
    header:add("Sec-WebSocket-Accept", self:_calculate_ws_accept())
    if self.subprotocol then
        -- Set user selected subprotocol string.
        header:add("Sec-WebSocket-Protocol", self.subprotocol)
    end
    return header
end

local function _waiting_handshake_cb()

end

function websocket.WebSocketHandler:_do_ws_handshake()
    -- NYI

    self._connecting_ws_state = false
    -- Continue any sockets that may be connecting from the same IP.
    local connecting = self.application._connecting_ws[self.request.remote_ip]
    -- Remove self from queue.
    table.remove(connecting, #connecting)
    if #connecting ~= 0 then    
        -- Add IOLoop callback for continouing waiting socket.
        self.io_loop:add_callback(_waiting_handshake_cb, 
                                  connecting[#connecting])
    else
        -- No more waiting remove key.
        self.application._connecting_ws[self.request.remote_ip] = nil
    end
end

return websocket
