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

local math =            require "math"
local bit =             require "bit"
local ffi =             require "ffi"
local log =             require "turbo.log"
local httputil =        require "turbo.httputil"
local httpserver =      require "turbo.httpserver"
local buffer =          require "turbo.structs.buffer"
local escape =          require "turbo.escape"
local util =            require "turbo.util"
local hash =            require "turbo.hash"
local web =             require "turbo.web"
local async =           require "turbo.async"
local buffer =          require "turbo.structs.buffer"
require('turbo.3rdparty.middleclass')
local ltp_loaded, libturbo_parser = pcall(ffi.load, "tffi_wrap")
if not ltp_loaded then
    -- Check /usr/local/lib explicitly also.
    ltp_loaded, libturbo_parser = 
        pcall(ffi.load, "/usr/local/lib/libtffi_wrap.so")
    if not ltp_loaded then 
        error("Could not load libtffi_wrap.so. \
            Please run makefile and ensure that installation is done correct.")
    end
end
local le = ffi.abi("le")
local strf = string.format
math.randomseed(util.gettimeofday())

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

--- Called when a error is raised.
function websocket.WebSocketHandler:on_error(msg) end

--- Called when the headers has been parsed and the server is about to initiate
-- the WebSocket specific handshake. Use this to e.g check if the headers
-- Origin field matches what you expect.
function websocket.WebSocketHandler:prepare() end

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
function websocket.WebSocketHandler:write_message(msg, binary)
    if self._closed == true then
        error("WebSocket connection has been closed. Can not write message.")
    end
    self:_send_frame(true, 
                     binary and 
                        websocket.opcode.BINARY or websocket.opcode.TEXT, 
                     msg)
end

--- Send a ping to the connected client.
function websocket.WebSocketHandler:ping(data, callback, callback_arg) 
    self._ping_callback = callback
    self._ping_callback_arg = callback_arg
    self:_send_frame(true, websocket.opcode.PING, data)
end

--- Close the connection.
function websocket.WebSocketHandler:close() 
    self._closed = true
    self:_send_frame(true, websocket.opcode.CLOSE, "")
    self.stream:close()
end

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
    if self.sec_websocket_version ~= "13" then
        log.error(strf("Client wants to use not implemented Websocket Version %s.\
                       Can not upgrade.", self.sec_websocket_version))
        -- Propose a specific version for the client...
        self:add_header("Sec-WebSocket-Version", "13")
        self:set_status_code(426)
        self:finish()
        return
    end
    local prot = self.request.headers:get("Sec-WebSocket-Protocol")
    if prot then
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
    end
    -- Origin can be used by client applications to either accept or deny
    -- a request. This responsibility is left up to each developer to handle
    -- in e.g the prepare() method.
    self.origin = self.request.headers:get("Origin")
    self:prepare()
    local response_header = self:_create_response_header()
    self.stream:write(response_header.."\r\n")
    -- HTTP headers read, change to WebSocket protocol. 
    -- Set max buffer size to 64MB as it is 16KB at this point...
    self.stream:set_max_buffer_size(1024*1024*64) 
    log.success(string.format([[[websocket.lua] WebSocket opened %s (%s)]], 
        self.request.headers:get_url(),
        self.request.remote_ip))
    self:_continue_ws()
end

function websocket.WebSocketHandler:_calculate_ws_accept()
    --- FIXME: Decode key and ensure that it is 16 bytes in length.
    assert(escape.base64_decode(self.sec_websocket_key):len() == 16, 
           "Sec-WebSocket-Key is of invalid size.")
    local hash = hash.SHA1(self.sec_websocket_key..websocket.MAGIC)
    return escape.base64_encode(hash:finalize(), 20)
end

function websocket.WebSocketHandler:_create_response_header()
    local header = httputil.HTTPHeaders()
    header:set_status_code(101)
    header:set_version("HTTP/1.1")
    header:add("Server", "Turbo v1.1")
    header:add("Upgrade", "websocket")
    header:add("Connection", "Upgrade")
    header:add("Sec-WebSocket-Accept", self:_calculate_ws_accept())
    if type(self.subprotocol) == "string"  then
        -- Set user selected subprotocol string.
        header:add("Sec-WebSocket-Protocol", self.subprotocol)
    end
    return header:stringify_as_response()
end

--- Websocket opcodes.
websocket.opcode = {
    CONTINUE =  0x0,
    TEXT =      0x1,
    BINARY =    0x2,
    -- 0x3-7 Reserved
    CLOSE =     0x8,
    PING =      0x9,
    PONG =      0xA,
    -- 0xB-F Reserved
}

ffi.cdef [[
    struct ws_header {
        uint8_t flags;
        uint8_t len;
        union {
            uint16_t sh;
            uint64_t ll;
        } ext_len;
    } __attribute__ ((__packed__));
]]

--- Error handler.
function websocket.WebSocketHandler:_error(msg)
    log.error("[websocket.lua] "..msg)
    if not self._closed == true and not self.stream:closed() then
        self:close()
    end
    self:on_error(msg)
end

function websocket.WebSocketHandler:_socket_closed()
    log.success(string.format([[[websocket.lua] WebSocket closed %s (%s) %dms]], 
        self.request.headers:get_url(),
        self.request.remote_ip,
        self.request:request_time()))
    self:on_close()
end

--- Called after HTTP handshake has passed and connection has been upgraded
-- to WebSocket.
function websocket.WebSocketHandler:_continue_ws()
    self.stream:set_close_callback(self._socket_closed, self)
    self.stream:read_bytes(2, self._accept_frame, self)
    self:open()
end

--- Accept a new WebSocket frame.
function websocket.WebSocketHandler:_accept_frame(header)
    local ws_header = ffi.cast("struct ws_header *", header)
    self._fragmented_message_buffer = buffer(1024)
    self._final_bit = bit.band(ws_header.flags, 0x80) ~= 0
    self._rsv1_bit = bit.band(ws_header.flags, 0x40) ~= 0
    self._rsv2_bit = bit.band(ws_header.flags, 0x20) ~= 0
    self._rsv3_bit = bit.band(ws_header.flags, 0x10) ~= 0
    self._opcode = bit.band(ws_header.flags, 0xf)
    self._mask_bit = bit.band(ws_header.len, 0x80) ~= 0
    local payload_len = bit.band(ws_header.len, 0x7f)
    if self._opcode == websocket.opcode.CLOSE and payload_len >= 126 then
        self:_error(
            "WebSocket protocol error: \
            Recieved CLOSE opcode with greater than 126 payload.")
        return
    end
    if payload_len < 126 then
        self._payload_len = payload_len
        if self._mask_bit then
            self.stream:read_bytes(4, self._frame_mask_key, self)
        else
            self.stream:read_bytes(self._payload_len, 
                                   self._frame_payload, 
                                   self)
        end
    elseif payload_len == 126 then
        -- 16 bit length.
        self.stream:read_bytes(2, self._frame_len_16, self)
    elseif payload_len == 127 then
        -- 64 bit length.
        self.stream:read_bytes(8, self._frame_len_64, self)
    end
end

if le then
    function websocket.WebSocketHandler:_frame_len_16(data)
        -- Network byte order for multi-byte length values.
        -- What were they thinking!
        self._payload_len = tonumber(
            ffi.C.htons(ffi.cast("uint16_t", data)))
        if self._mask_bit then
            self.stream:read_bytes(4, self._frame_mask_key, self)
        else
            self.stream:read_bytes(self._payload_len, 
                                   self._frame_payload, 
                                   self)
        end
    end

    function websocket.WebSocketHandler:_frame_len_64(data)
        self._payload_len = tonumber(
            libturbo_parser.turbo_bswap_u64(ffi.cast("uint64_t", data)))
        if self._mask_bit then
            self.stream:read_bytes(4, self._frame_mask_key, self)
        else
            self.stream:read_bytes(self._payload_len, 
                                   self._frame_payload, 
                                   self)
        end
    end
end

function websocket.WebSocketHandler:_frame_mask_key(data)
    self._frame_mask = data
    self.stream:read_bytes(self._payload_len, self._masked_frame_payload, self)
end

function websocket.WebSocketHandler:_frame_payload(data)
    local opcode
    if self._opcode == websocket.opcode.CLOSE then
        if not self._final_bit then
            self:_error(
                "WebSocket protocol error: \
                CLOSE opcode was fragmented.")
            return
        end
        opcode = self._opcode
    elseif self._opcode == websocket.opcode.CONTINUE then
        if self._fragmented_message_buffer:len() == 0 then
            self:_error(
                "WebSocket protocol error: \
                CONTINUE opcode, but theres nothing to continue.")
            return
        end
        self._fragmented_message_buffer:append_luastr_right(data)
        if self._final_bit == true then
            opcode = self._fragmented_message_opcode
            data = self._fragmented_message_buffer:__tostring()
            self._fragmented_message_buffer:clear()
            self._fragmented_message_opcode = nil
        end
    else 
        if self._fragmented_message_buffer:len() ~= 0 then
            self:_error(
                "WebSocket protocol error: \
                previous CONTINUE opcode not finished.")
            return
        end
        if self._final_bit == true then
            opcode = self._opcode
        else
            self._fragmented_message_opcode = self._opcode
            self._fragmented_message_buffer:append_luastr_right(data)
            if data:len() == 0 then
                log.debug("Zero length data on WebSocket.")
            end
        end
    end
    if self._final_bit == true then
        self:_handle_opcode(opcode, data)
    end
    if self._closed ~= true then
        self.stream:read_bytes(2, self._accept_frame, self)
    end
end

function websocket.WebSocketHandler:_handle_opcode(opcode, data)
    if self._closed == true then
        return
    end
    if opcode == websocket.opcode.TEXT or 
            opcode == websocket.opcode.BINARY then
        self:on_message(data)
    elseif opcode == websocket.opcode.CLOSE then
        self:close()
    elseif opcode == websocket.opcode.PING then
        self:_send_frame(true, websocket.opcode.PONG, data)
    elseif opcode == websocket.opcode.PONG then
        if self._ping_callback then
            local callback = self._ping_callback
            local arg = self._ping_callback_arg
            self._ping_callback = nil
            self._ping_callback_arg = nil
            if arg then
                callback(arg, data)
            else
                callback(data)
            end
        end
    else
        self:_error(
            "WebSocket protocol error: \
            invalid opcode ".. tostring(opcode))
        return
    end
end

local function _unmask_payload(mask, data)
    local ptr = libturbo_parser.turbo_websocket_mask(mask, data, data:len())
    if ptr ~= nil then
        local str = ffi.string(ptr, data:len())
        ffi.C.free(ptr)
        return str
    else
        error("Could not allocate memory for WebSocket frame masking.\
              Catastrophic failure.")
    end

end

function websocket.WebSocketHandler:_masked_frame_payload(data)
    self:_frame_payload(_unmask_payload(self._frame_mask, data))
end

local _ws_header = ffi.new("struct ws_header")
local _ws_mask = ffi.new("int32_t[1]")
if le then
    -- Multi-byte lengths must be sent in network byte order, e.g
    -- big-endian. Ugh...
    function websocket.WebSocketHandler:_send_frame(finflag, opcode, data)
        local data_sz = data:len()
        _ws_header.flags = bit.bor(finflag and 0x80 or 0x0, opcode)
        if data_sz < 0x7e then
            _ws_header.len = bit.bor(data_sz, 
                                     self.mask_outgoing and 0x80 or 0x0)
            self.stream:write(ffi.string(_ws_header, 2))
        elseif data_sz <= 0xffff then
            _ws_header.len = bit.bor(126, self.mask_outgoing and 0x80 or 0x0)
            _ws_header.ext_len.sh = data_sz
            _ws_header.ext_len.sh = ffi.C.htons(data_sz)
            self.stream:write(ffi.string(_ws_header, 4))
        else
            _ws_header.len = bit.bor(127, self.mask_outgoing and 0x80 or 0x0)
            _ws_header.ext_len.ll = data_sz
            -- bit.bswap supports only 32-bit bit swap, so instead of a 64-bit
            -- split to two ints a native C function is used.
            _ws_header.ext_len.ll = libturbo_parser.turbo_bswap_u64(
                _ws_header.ext_len.ll)
            self.stream:write(ffi.string(_ws_header, 10))
        end
        if self.mask_outgoing == true then
            _ws_mask = math.random(0x00000001, 0x7FFFFFFF)
            self.stream:write(ffi.string(ffi.cast("uint8_t*", _ws_mask[0]), 4))
            self.stream:write(_unmask_payload(_ws_mask, data))
            return
        end
        self.stream:write(data)
    end
end

return websocket
