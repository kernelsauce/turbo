--- Turbo.lua IO Stream module.
-- High-level wrappers for asynchronous socket communication.
--
-- Copyright 2011 - 2015 John Abrahamsen
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


local log =         require "turbo.log"
local ioloop =      require "turbo.ioloop"
local deque =       require "turbo.structs.deque"
local buffer =      require "turbo.structs.buffer"
local socket =      require "turbo.socket_ffi"
local sockutils =   require "turbo.sockutil"
local util =        require "turbo.util"
local iostream =	require "turbo.iostream"
local platform =    require "turbo.platform"
local async =		require "turbo.async"
local bit =         jit and require "bit" or require "bit32"
local ffi =         require "ffi"

local iosimple = {} -- iosimple namespace

function iosimple.dial(address, io)
	assert(type(address) == "string", "No address in call to dial.")
	local protocol, host, port = address:match("^(%a+)://(.+)")

	assert(
		protocol and host,
		"Invalid address. Use e.g \"tcp://turbolua.org:8080\".")

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
    local stream = iostream.IOStream(host)
    local ctx = coctx.CoroutineContext(io)
    
    stream:connect(host, port, address_family, 
    	function()
    		ctx:set_argument({1})
    		ctx:finalize_context()
		end,
		function(err)
			ctx:set_argument({0, sockerr, strerr})
			ctx:finalize_context()
    	end
    )
    local rc, sockerr, strerr = coroutine.yield(ctx)
    if rc ~= 0 then
    	error(string.format("Could not connect to %s, %s", address, strerr))
    end
    return iosimple.IOSimple(stream)
end

iosimple.IOSimple = class("IOSimple")

function iosimple.IOSimple:initialize(stream, io)
	self.stream = stream
	self.io = io
end

function iosimple.IOSimple:_wake_yield(...)
	local ctx = self.coctx
	self.coctx = nil
	ctx:set_argument({...})
	ctx:finalize_context()
end

function iosimple.IOSimple:write(str)
	assert(not self.coctx, "IOSimple is already working.")
	self.coctx = coctx.CoroutineContext(self.io)
	self.iostream:write(str, self._wake_yield, self)
	return coroutine.yield(self.coctx)
end

function iosimple.IOSimple:read_until(delimiter)
	assert(not self.coctx, "IOSimple is already working.")
	self.coctx = coctx.CoroutineContext(self.io)
	self.iostream:read_until(delimiter, self._wake_yield, self)
	return coroutine.yield(self.coctx)
end

function iosimple.IOSimple:read_until_pattern(pattern)
	assert(not self.coctx, "IOSimple is already working.")
	self.coctx = coctx.CoroutineContext(self.io)
	self.iostream:read_until_pattern(pattern, self._wake_yield, self)
	return coroutine.yield(self.coctx)
end

function iosimple.IOSimple:read_until_close(pattern)
	assert(not self.coctx, "IOSimple is already working.")
	self.coctx = coctx.CoroutineContext(self.io)
	self.iostream:read_until_close(self._wake_yield, self)
	return coroutine.yield(self.coctx)
end

return iosimple