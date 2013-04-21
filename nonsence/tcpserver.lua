--[[ Nonsence Asynchronous event based Lua Web server.
Author: John Abrahamsen < JhnAbrhmsn@gmail.com >

This module "tcpserver" is a part of the Nonsence Web server.
For the complete stack hereby called "software package" please see:

https://github.com/JohnAbrahamsen/nonsence-ng/

Many of the modules in the software package are derivatives of the 
Tornado web server. Tornado is also licensed under Apache 2.0 license.
For more details on Tornado please see:

http://www.tornadoweb.org/

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
  
local log = require "log"
local iostream = require "iostream"
local ioloop = require "ioloop"
local socket = require "socket_ffi"
local ffi = require "ffi"
local bit = require "bit"
require 'middleclass'
local SOL_SOCKET = socket.SOL.SOL_SOCKET
local SO_RESUSEADDR = socket.SO.SO_REUSEADDR
local O_NONBLOCK = socket.O.O_NONBLOCK
local F_SETFL = socket.F.F_SETFL
local F_GETFL = socket.F.F_GETFL
local SOCK_STREAM = socket.SOCK.SOCK_STREAM
local INADDRY_ANY = socket.INADDR_ANY
local AF_INET = socket.AF.AF_INET
local EWOULDBLOCK = socket.EWOULDBLOCK
local EAGAIN = socket.EAGAIN

local tcpserver = {}  -- tcpserver namespace


--[[ Binds sockets to port and address.
If not address is defined then * will be used.
If no backlog size is given in bytes then 128 connections will be used.      ]]
local function bind_sockets(port, address, backlog)
	local backlog = backlog or 128
	local address = address or INADDRY_ANY
	local serv_addr = ffi.new("struct sockaddr_in") 
        local errno
        local rc
        
        ffi.fill(serv_addr, ffi.sizeof(serv_addr), 0)
        serv_addr.sin_family = AF_INET;
	serv_addr.sin_addr.s_addr = socket.htonl(address);
	serv_addr.sin_port = socket.htons(port);
        
        local fd = socket.socket(AF_INET, SOCK_STREAM, 0)
        if (fd == -1) then
            errno = ffi.errno()
	    error(string.format("[tcpserver.lua Errno %d] Could not create socket. %s", errno, socket.strerror(errno)))		
        end
        
        local flags = socket.fcntl(fd, F_GETFL, 0);
        if (flags == -1) then
            error("[iostream.lua] fcntl GETFL failed.")
        end
        flags = bit.bor(flags, O_NONBLOCK)
        rc = socket.fcntl(fd, F_SETFL, flags)
        if (rc == -1) then
            error("[iostream.lua] fcntl set O_NONBLOCK failed.")
        end      

        local setopt = ffi.new("int32_t[1]", 1)
        rc = socket.setsockopt(fd,
                                 SOL_SOCKET,
                                 SO_RESUSEADDR,
                                 setopt,
                                 ffi.sizeof("int32_t"))
        if (rc > 0) then
            error("[tcpserver.lua] setsockopt SO_REUSEADDR failed.")
        end

	if (socket.bind(fd, ffi.cast("struct sockaddr *", serv_addr), ffi.sizeof(serv_addr)) ~= 0) then
		errno = ffi.errno()
		error(string.format("[tcpserver.lua Errno %d] Could not bind to address. %s", errno, socket.strerror(errno)))		
	end

	if (socket.listen(fd, backlog) ~= 0) then 
		errno = ffi.errno()
		error(string.format("[tcpserver.lua Errno %d] Could not listen to socket fd %d. %s", errno, fd, socket.strerror(errno)))
	end
        
        --log.devel(string.format("[tcpserver.lua] Listening to socket fd %d", fd))
	return fd
end


--[[ Add accept handler for socket with given callback. Either supply a IOLoop object, or the global instance will be used...   ]]
local function add_accept_handler(sock, callback, io_loop)	
	local io_loop = io_loop or ioloop.instance()
	io_loop:add_handler(sock, ioloop.READ, function(fd, events)
            while true do
                    local errno
                    local client_addr = ffi.new("struct sockaddr_in")
                    ffi.fill(client_addr, ffi.sizeof(client_addr), 0)
                    local client_addr_sz = ffi.new("socklen_t[1]", ffi.sizeof(client_addr))
                    --log.devel(string.format("[tcpserver.lua] Accepting connection on socket fd %d", fd))
                    
                    local client_fd = socket.accept(fd, ffi.cast("struct sockaddr *", client_addr), client_addr_sz)
                                
                    if (client_fd == -1) then
                        errno = ffi.errno()
                        if (errno == EWOULDBLOCK or errno == EAGAIN) then
                            break
                        else
                            log.error(string.format("[tcpserver.lua Errno %d] Could not accept connection. %s", errno, socket.strerror(errno)))
                            break
                        end
                    end
                    
                    local buf = ffi.new("char[46]")
                    local address_cstr = socket.inet_ntop(AF_INET, client_addr.sin_addr, buf, 46);
                    if (address_cstr == 0) then
                        log.error("[tcpserver.lua] Could not get address string new connection.")
                        break
                    end
                    local address = ffi.string(address_cstr)
                    
                    callback(client_fd, address)
            end
        end)
end



tcpserver.TCPServer = class('TCPServer')

function tcpserver.TCPServer:init(io_loop, ssl_options)	
	self.io_loop = io_loop or ioloop.instance()
	--self.ssl_options = ssl_options
	self._sockets = {}
	self._pending_sockets = {}
	self._started = false
end

--[[ Start listening on port and address.
If no address is supplied, * will be used.     ]]
function tcpserver.TCPServer:listen(port, address)
	assert(port, [[Please specify port for listen() method]])
	local sock = bind_sockets(port, address, 1024)
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
		add_accept_handler(sock,
                                   function(connection, address) self:_handle_connection(connection, address) end,
                                   self.io_loop)
	end
end

--[[ Add a single socket.     ]]
function tcpserver.TCPServer:add_socket(socket)	
	self:add_sockets({ socket })
end

function tcpserver.TCPServer:bind(port, address, backlog)
	
	local backlog = backlog or 128
	local sockets = bind_sockets(port, address, backlog)
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
	for file_descriptor, socket in pairs(self._sockets) do
		self.io_loop:remove_handler(file_descriptor)
                assert(socket.close(socket) == 0)
	end
end

--[[ What to do with a new stream/connection.
-- This method should be redefined when inheriting from the TCPServer class.  ]]
function tcpserver.TCPServer:handle_stream(stream, address)	
	error('handle_stream method not implemented in this object')
end

--[[ Handle new connection.    ]]
function tcpserver.TCPServer:_handle_connection(connection, address)	
	local stream = iostream.IOStream:new(connection, self.io_loop)
	self:handle_stream(stream, address)
end

return tcpserver
