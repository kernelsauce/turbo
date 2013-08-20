--- Turbo.lua Socket Utils
--
-- Copyright 2011, 2012, 2013 John Abrahamsen
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
  
local socket =      require "turbo.socket_ffi"
local ioloop =      require "turbo.ioloop"
local log =         require "turbo.log"
local ffi =         require "ffi"
local bit =         require "bit"
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

local sockutils = {} -- sockutils namespace

--- Binds sockets to port and address.
-- If not address is defined then * will be used.
-- If no backlog size is given then 128 connections will be used.
-- @param port (Number) The port number to bind to.
-- @param address (Number or String) The address to bind to in unsigned integer hostlong or \
--  a string like "127.0.0.1".
-- format. If not address is given, INADDR_ANY will be used, binding to all
-- addresses.
-- @param backlog (Number) Maximum backlogged client connects to allow. If not
-- defined then 128 is used as default.
-- @param family (Number) Optional socket family. Defined in Socket module. If 
-- not defined AF_INET is used as default.
function sockutils.bind_sockets(port, address, backlog, family)
    local serv_addr = ffi.new("struct sockaddr_in") 
    local errno
    local rc, msg

    family = family or AF_INET
    address = address or INADDRY_ANY

    if family ~= AF_INET then
        error("[sockutil.lua] Anything other than ipv4 (AF_INET) is currently \
            not supported")
    end

    if type(address) == "string" then
        rc = ffi.C.inet_pton(AF_INET, address, serv_addr.sin_addr)
        if rc == 0 then
            error(string.format("[sockutil.lua] Invalid address %s",
                address))
        elseif r == -1 then
            errno = ffi.errno()
            error(string.format(
                "[sockutil.lua Errno %d] Could not parse address. %s",
                errno,
                socket.strerror(errno)))
        end
    else
        serv_addr.sin_addr.s_addr = socket.htonl(address);
    end

    backlog = backlog or 128
    serv_addr.sin_family = family;
    serv_addr.sin_port = socket.htons(port);
    
    local fd = socket.socket(family, SOCK_STREAM, 0)
    if fd == -1 then
    	errno = ffi.errno()
    	error(string.format("[tcpserver.lua Errno %d] Could not create socket. %s", 
            errno, 
            socket.strerror(errno)))		
    end    
    rc, msg = socket.set_nonblock_flag(fd)
    if rc ~= 0 then
	   error("[iostream.lua] " .. msg)
    end    
    rc, msg = socket.set_reuseaddr_opt(fd)
    if rc ~= 0 then
	   error("[tcpserver.lua] " .. msg)
    end
    if socket.bind(fd, ffi.cast("struct sockaddr *", serv_addr), 
        ffi.sizeof(serv_addr)) ~= 0 then
	    errno = ffi.errno()
	    error(string.format(
            "[tcpserver.lua Errno %d] Could not bind to address. %s", 
            errno, 
            socket.strerror(errno)))		
    end
    if socket.listen(fd, backlog) ~= 0 then 
	    errno = ffi.errno()
	    error(string.format(
            "[tcpserver.lua Errno %d] Could not listen to socket fd %d. %s", 
            errno, 
            fd, 
            socket.strerror(errno)))
    end    
    --log.devel(string.format("[tcpserver.lua] Listening to socket fd %d", fd))
    return fd
end

local client_addr = ffi.new("struct sockaddr")
local client_addr_sz = ffi.new("int32_t[1]", ffi.sizeof(client_addr))
local function _add_accept_hander_cb(arg, fd, events)
    while true do 
        local errno
        --log.devel(string.format(
            --"[tcpserver.lua] Accepting connection on socket fd %d", fd))
        local client_fd = socket.accept(fd, client_addr, client_addr_sz)        
        if client_fd == -1 then
            errno = ffi.errno()
            if (errno == EWOULDBLOCK or errno == EAGAIN) then
                break
            else
                log.error(string.format(
                    "[tcpserver.lua Errno %d] Could not accept connection. %s", 
                    errno, 
                    socket.strerror(errno)))
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
        if arg[2] then
            arg[1](arg[2], client_fd, address)
        else
            arg[1](client_fd, address)
        end
    end
end

--- Add accept handler for socket with given callback. 
-- Either supply a IOLoop object, or the global instance will be used... 
-- @param sock (Number) Socket file descriptor to add handler for.
-- @param callback (Function) Callback to handle connects. Function recieves
-- socket fd (Number) and address (String) of client as parameters.
-- @param io_loop (IOLoop instance) If not set the global is used.
-- @param arg Optional argument for callback.
function sockutils.add_accept_handler(sock, callback, io_loop, arg)	
    local io_loop = io_loop or ioloop.instance()
    io_loop:add_handler(
        sock, 
        ioloop.READ, 
        _add_accept_hander_cb, 
        {callback, arg})
end

return sockutils
