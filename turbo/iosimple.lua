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
local bit =         jit and require "bit" or require "bit32"
local ffi =         require "ffi"

local iosimple = {} -- iosimple namespace

function iosimple.dial(address)
	assert(type(address) == "string", "No address in call to dial.")
	local protocol, host, port = address:match("^(%a+)://(.+)")
	print(protocol,host,port)
	assert(protocol and host, "Invalid address. Use e.g \"tcp://turbolua.org:8080\".")

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
end

return iosimple