--[[ Turbo TCP Server module

Copyright 2011, 2012, 2013 John Abrahamsen

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.		]]
  
local log =         require "turbo.log"
local util =        require "turbo.util"
local iostream =    require "turbo.iostream"
local ioloop =      require "turbo.ioloop"
local socket =      require "turbo.socket_ffi"
local sockutil =    require "turbo.sockutil"
local ngc =         require "turbo.nwglobals"
local ffi =         require "ffi"
local bit =         require "bit"
require "turbo.3rdparty.middleclass"

local SOL_SOCKET =  socket.SOL_SOCKET
local SO_RESUSEADDR = socket.SO_REUSEADDR
local O_NONBLOCK =  socket.O_NONBLOCK
local F_SETFL =     socket.F_SETFL
local F_GETFL =     socket.F_GETFL
local SOCK_STREAM = socket.SOCK_STREAM
local INADDRY_ANY = socket.INADDR_ANY
local AF_INET =     socket.AF_INET
local EWOULDBLOCK = socket.EWOULDBLOCK
local EAGAIN =      socket.EAGAIN

local tcpserver = {}  -- tcpserver namespace

tcpserver.TCPServer = class('TCPServer')

function tcpserver.TCPServer:initialize(io_loop, ssl_options)	
    self.io_loop = io_loop or ioloop.instance()
    self.ssl_options = ssl_options
    self._sockets = {}
    self._pending_sockets = {}
    self._started = false
end

--[[ Start listening on port and address.
If no address is supplied, * will be used.     ]]
function tcpserver.TCPServer:listen(port, address)
    assert(port, [[Please specify port for listen() method]])
    local sock = sockutil.bind_sockets(port, address, 1024)
    log.notice("[tcpserver.lua] TCPServer listening on port: " .. port)
    self:add_sockets({sock})
end


--[[ Add multiple sockets in a table.        ]]
function tcpserver.TCPServer:add_sockets(sockets)	
    if not self.io_loop then
	    self.io_loop = ioloop.instance()
    end
    
    for _, sock in ipairs(sockets) do
	    self._sockets[sock] = sock
	    sockutil.add_accept_handler(sock,
			       function(connection, address) self:_handle_connection(connection, address) end,
			       self.io_loop)
    end
end

--[[ Add a single socket.     ]]
function tcpserver.TCPServer:add_socket(socket)	self:add_sockets({ socket }) end

function tcpserver.TCPServer:bind(port, address, backlog)
    local backlog = backlog or 128
    local sockets = sockutil.bind_sockets(port, address, backlog)
    if self._started then
	self:add_sockets(sockets)
    else
        self._pending_sockets[#self._pending_sockets + 1] = sockets
    end
end

--[[ Start the TCPServer.		]]
function tcpserver.TCPServer:start()	
	assert(( not self._started ), [[Running started on a already started TCPServer]])
	self._started = true
	local sockets = self._pending_sockets
	self._pending_sockets = {}
	self:add_sockets(sockets)
end

--[[ Stop the TCPServer.		]]
function tcpserver.TCPServer:stop()
    for fd, sock in pairs(self._sockets) do
	self.io_loop:remove_handler(fd)
	assert(socket.close(sock) == 0)
	ngc.dec("tcp_open_sockets", 1)
    end
end

--[[ What to do with a new stream/connection.
-- This method should be redefined when inheriting from the TCPServer class.  ]]
function tcpserver.TCPServer:handle_stream(stream, address)	
	error('handle_stream method not implemented in this object')
end

--[[ Handle new connection.    ]]
function tcpserver.TCPServer:_handle_connection(connection, address)
    if (self.ssl_options ~= nil) then
	--FIXME ssl.
    else
	local stream = iostream.IOStream:new(connection, self.io_loop)
	self:handle_stream(stream, address)
    end
end

return tcpserver
