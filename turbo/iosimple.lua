--- Turbo.lua IO Stream module.
-- Very High-level wrappers for asynchronous socket communication.
--
-- Copyright 2015 John Abrahamsen
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
--
--
-- A interface for turbo.iostream without the callback spaghetti, but still
-- the async backend (the yield is done internally):
-- turbo.ioloop.instance():add_callback(function()
--     local stream = turbo.iosimple.dial("tcp://turbolua.org:80")
--     stream:write("GET / HTTP/1.0\r\n\r\n")
--
--     local data = stream:read_until_close()
--     print(data)
--
--     turbo.ioloop.instance():close() 
-- end):start()
--
--

local log =         require "turbo.log"
local ioloop =      require "turbo.ioloop"
local coctx =       require "turbo.coctx"
local socket =      require "turbo.socket_ffi"
local sockutils =   require "turbo.sockutil"
local util =        require "turbo.util"
local iostream =    require "turbo.iostream"

local iosimple = {} -- iosimple namespace

--- Connect to a host using a simple URI pattern.
-- @param address (String) E.g tcp://turbolua.org:8887
-- @param io (IOLoop object) IOLoop class instance to use for event
-- processing. If none is set then the global instance is used, see the
-- ioloop.instance() function.
-- @return (IOSimple class instance) or raise error.
function iosimple.dial(address, io)
    assert(type(address) == "string", "No address in call to dial.")
    local protocol, host, port = address:match("^(%a+)://(.+):(%d+)")
    port = tonumber(port)
    assert(
        protocol and host,
        "Invalid address. Use e.g \"tcp://turbolua.org:8080\".")

    io = io or ioloop.instance()
    local sock_t
    local address_family
    if protocol == "tcp" then
        sock_t = socket.SOCK_STREAM
        address_family = socket.AF_INET
    elseif protocol == "udp" then
        sock_t = socket.SOCK_DGRAM
        address_family = socket.AF_INET
    elseif protocol == "unix" then
        sock_t = socket.SOCK_STREAM
        address_family = socket.AF_UNIX
    else
        error("Unknown schema: " .. protocol)
    end

    local sock, msg = socket.new_nonblock_socket(
         address_family,
         sock_t,
         0)
    if sock == -1 then
        error("Could not create socket.")
    end
    local stream = iostream.IOStream(sock)
    local ctx = coctx.CoroutineContext(io)
    
    stream:connect(host, port, address_family, 
        function()
            ctx:set_arguments({true})
            ctx:finalize_context()
        end,
        function(err)
            ctx:set_arguments({false, sockerr, strerr})
            ctx:finalize_context()
        end
    )
    local rc, sockerr, strerr = coroutine.yield(ctx)
    if rc ~= true then
        error(string.format("Could not connect to %s, %s", address, strerr))
    end
    return iosimple.IOSimple(stream, io)
end

iosimple.IOSimple = class("IOSimple")


function iosimple.IOSimple:initialize(stream, io)
    self.stream = stream
    self.io = io
    self.stream:set_close_callback(self._wake_yield_close, self)
end

--- Close this stream and clean up.
function iosimple.IOSimple:close(str)
    self.stream:close()
end

function iosimple.IOSimple:write(str)
    assert(not self.coctx, "IOSimple is already working.")
    self.coctx = coctx.CoroutineContext(self.io)
    self.stream:write(str, self._wake_yield, self)
    local res, err = coroutine.yield(self.coctx)
    if not res and err then
        error(err)
    end
end

function iosimple.IOSimple:read_until(delimiter)
    assert(not self.coctx, "IOSimple is already working.")
    self.coctx = coctx.CoroutineContext(self.io)
    self.stream:read_until(delimiter, self._wake_yield, self)
    local res, err = coroutine.yield(self.coctx)
    if not res and err then
        error(err)
    end
end

function iosimple.IOSimple:read_bytes(bytes)
    assert(not self.coctx, "IOSimple is already working.")
    self.coctx = coctx.CoroutineContext(self.io)
    self.stream:read_bytes(bytes, self._wake_yield, self)
    local res, err = coroutine.yield(self.coctx)
    if not res and err then
        error(err)
    end
end

function iosimple.IOSimple:read_until_pattern(pattern)
    assert(not self.coctx, "IOSimple is already working.")
    self.coctx = coctx.CoroutineContext(self.io)
    self.stream:read_until_pattern(pattern, self._wake_yield, self)
    local res, err = coroutine.yield(self.coctx)
    if not res and err then
        error(err)
    end
end

function iosimple.IOSimple:read_until_close()
    assert(not self.coctx, "IOSimple is already working.")
    self.coctx = coctx.CoroutineContext(self.io)
    self.stream:read_until_close(self._wake_yield, self)
    local res, err = coroutine.yield(self.coctx)
    if not res and err then
        error(err)
    end
end

function iosimple.IOSimple:_wake_yield_close(...)
    if self.coctx then
        self.coctx:set_arguments({nil, "disconnected"})
        self.coctx:finalize_context()
        self.coctx = nil
    end
end

function iosimple.IOSimple:_wake_yield(...)
    local ctx = self.coctx
    self.coctx = nil
    ctx:set_arguments({...})
    ctx:finalize_context()
end

return iosimple
