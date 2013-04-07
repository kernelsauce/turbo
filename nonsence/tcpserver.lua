--[[ Nonsence Asynchronous event based Lua Web server.
Author: John Abrahamsen < JhnAbrhmsn@gmail.com >

This module "tcpserver" is a part of the Nonsence Web server.
For the complete stack hereby called "software package" please see:

https://github.com/JohnAbrahamsen/nonsence-ng/

Many of the modules in the software package are derivatives of the 
Tornado web server. Tornado is also licensed under Apache 2.0 license.
For more details on Tornado please see:

http://www.tornadoweb.org/


Copyright 2011 John Abrahamsen

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.		]]
  
local log,nixio,iostream,ioloop = require('log'),require('nixio'),
require('iostream'),require('ioloop') 

require('middleclass')

local tcpserver = {}  -- tcpserver namespace


--[[ Binds sockets to port and address.
If not address is defined then * will be used.
If no backlog size is given in bytes then 128 bytes will be used.      ]]
local function bind_sockets(port, address, backlog)	
	local backlog = backlog or 128
	local address = address or nil
	local errno

	if address == '' then address = nil end
	local sockets = {}
	local socket = nixio.socket('inet', 'stream')

	assert(socket:setsockopt('socket', 'reuseaddr', 1))
	assert(socket:setblocking(false))

	if not socket:bind(address, port) then
		errno = nixio.errno()
		error(string.format("[Errno %d] Could not bind to address. %s", errno, nixio.strerror(errno)))		
	end

	if not socket:listen(backlog) then 
		errno = nixio.errno()
		error(string.format("[Errno %d] Could not listen to socket fd %d. %s", errno, socket:fileno(), nixio.strerror(errno)))
	end

	local errno = nixio.errno()
	sockets[#sockets + 1] = socket
	return sockets
end


--[[ Add accept handler for socket with given callback.
Either supply a IOLoop object, or the global instance
will be used...   ]]
local function add_accept_handler(socket, callback, io_loop)	
	local io_loop = io_loop or ioloop.instance()
	local function accept_handler(file_descriptor, events)
		while true do 
			local connection, address, port = socket:accept()
			if not connection then
				break
			end
			callback(connection, address)
		end
	end
	io_loop:add_handler(socket:fileno(), ioloop.READ, accept_handler)
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
	local sockets = bind_sockets(port, address, 1024)
	log.notice("[tcpserver.lua] TCPServer listening on port: " .. port)
	self:add_sockets(sockets)
end


--[[ Add multiple sockets in a table.        ]]
function tcpserver.TCPServer:add_sockets(sockets)	
	if not self.io_loop then
		self.io_loop = ioloop.instance()
	end
	
	for _, sock in ipairs(sockets) do
		self._sockets[sock:fileno()] = sock
		add_accept_handler(sock, function(connection,address) 
		self:_handle_connection(connection, address) end, self.io_loop)
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
		socket:close()
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
