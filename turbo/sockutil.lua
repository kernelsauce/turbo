--[[ Turbo Socket Utils

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
  
local ffi = require "ffi"
local bit = require "bit"
local socket = require "socket_ffi"
local ioloop = require "ioloop"
local ngc = require "nwglobals"
local SOL_SOCKET = socket.SOL_SOCKET
local SO_RESUSEADDR = socket.SO_REUSEADDR
local O_NONBLOCK = socket.O_NONBLOCK
local F_SETFL = socket.F_SETFL
local F_GETFL = socket.F_GETFL
local SOCK_STREAM = socket.SOCK_STREAM
local INADDRY_ANY = socket.INADDR_ANY
local AF_INET = socket.AF_INET
local EWOULDBLOCK = socket.EWOULDBLOCK
local EAGAIN = socket.EAGAIN

local sockutils = {} -- sockutils namespace


--[[ Binds sockets to port and address.
If not address is defined then * will be used.
If no backlog size is given then 128 connections will be used.      ]]
function sockutils.bind_sockets(port, address, backlog)
    local backlog = backlog or 128
    local address = address or INADDRY_ANY
    local serv_addr = ffi.new("struct sockaddr_in") 
    local errno
    local rc, msg
    
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_addr.s_addr = socket.htonl(address);
    serv_addr.sin_port = socket.htons(port);
    
    local fd = socket.socket(AF_INET, SOCK_STREAM, 0)
    if (fd == -1) then
	errno = ffi.errno()
	error(string.format("[tcpserver.lua Errno %d] Could not create socket. %s", errno, socket.strerror(errno)))		
    end
    ngc.inc("tcp_open_sockets", 1)
    
    rc, msg = socket.set_nonblock_flag(fd)
    if (rc ~= 0) then
	error("[iostream.lua] " .. msg)
    end
    
    rc, msg = socket.set_reuseaddr_opt(fd)
    if (rc ~= 0) then
	error("[tcpserver.lua] " .. msg)
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
function sockutils.add_accept_handler(sock, callback, io_loop)	
    local io_loop = io_loop or ioloop.instance()
    io_loop:add_handler(sock, ioloop.READ, function(fd, events)
	while true do
	    local errno
	    local client_addr = ffi.new("struct sockaddr")
	    local client_addr_sz = ffi.new("int32_t[1]", ffi.sizeof(client_addr))
	    --log.devel(string.format("[tcpserver.lua] Accepting connection on socket fd %d", fd))
	    local client_fd = socket.accept(fd, client_addr, client_addr_sz)

	    if (client_fd == -1) then
		errno = ffi.errno()
		if (errno == EWOULDBLOCK or errno == EAGAIN) then
		    break
		else
		    log.error(string.format("[tcpserver.lua Errno %d] Could not accept connection. %s", errno, socket.strerror(errno)))
		    break
		end
	    end
	    
	    local sockaddr_in = ffi.cast("struct sockaddr_in *", client_addr)
	    local s_addr_ptr = ffi.cast("unsigned char *", sockaddr_in.sin_addr)
	    
	    local address = string.format("%d.%d.%d.%d",
					  s_addr_ptr[0],
					  s_addr_ptr[1],
					  s_addr_ptr[2],
					  s_addr_ptr[3])
	    
	    ngc.inc("tcp_open_sockets", 1)
	    
	    callback(client_fd, address)
	end
    end)
end

return sockutils