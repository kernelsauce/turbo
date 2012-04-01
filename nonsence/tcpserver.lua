--[[
	
		Nonsence Asynchronous event based Lua Web server.
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
		limitations under the License.

  ]]
  
--[[

		Load modules
		
  ]]

local log,nixio,iostream,ioloop = require('log'),require('nixio'),
require('iostream'),require('ioloop') require('middleclass')

--[[

		Localize frequently used functions and constants :>
		
  ]]
  
local IOStream, dump, nixsocket, assert, class, ipairs, pairs = 
iostream.IOStream, log.dump, nixio.socket, assert, class, ipairs, 
pairs

--[[ 

		Declare module table to return on requires.
		
  ]]

local tcpserver = {}

local function bind_sockets(port, address, backlog)
	-- Binds sockets to port and address.
	-- If not address is defined then * will be used.
	-- If no backlog size is given in bytes then 128 bytes will
	-- be used.
	
	local backlog = backlog or 128
	local address = address or nil
	if address == '' then address = nil end
	local sockets = {}
	local socket = nixsocket('inet', 'stream')
	assert(socket:setsockopt('socket', 'reuseaddr', 1))
	socket:setblocking(false)
	socket:bind(address, port)
	socket:listen(backlog)
	sockets[#sockets + 1] = socket
	return sockets
end

local function add_accept_handler(socket, callback, io_loop)
	-- Add accept handler for socket with given callback.
	-- Either supply a IOLoop object, or the global instance
	-- will be used...
	
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
	-- Init method for TCPServer class.
	
	self.io_loop = io_loop or ioloop.instance()
	--self.ssl_options = ssl_options
	self._sockets = {}
	self._pending_sockets = {}
	self._started = false
end

function tcpserver.TCPServer:listen(port, address)
	-- Start listening on port and address.
	-- If no address is supplied, * will be used.

	assert(port, [[Please specify port for listen() method]])
	local sockets = bind_sockets(port, address)
	log.notice("tcpserver module => TCPServer listening on port: " .. port)
	self:add_sockets(sockets)
end

function tcpserver.TCPServer:add_sockets(sockets)
	-- Add multiple sockets in a table.
	
	if not self.io_loop then
		self.io_loop = ioloop.instance()
	end
	
	local function wrapper(connection, address)
		self:_handle_connection(connection, address)
	end
	
	for _, sock in ipairs(sockets) do
		self._sockets[sock:fileno()] = sock
		add_accept_handler(sock, wrapper, self.io_loop)
	end
end

function tcpserver.TCPServer:add_socket(socket)
	-- Add a single socket.
	
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

function tcpserver.TCPServer:start(num_processes)
	-- Start the TCPServer.
	-- TODO: forking?
	-- Do we really want forking. This might work.
	
	assert(( not self._started ), 
		[[Running started on a already started TCPServer]])
	self._started = true
	if num_processes ~= 1 then
		nixio.fork()
	end
	local sockets = self._pending_sockets
	self._pending_sockets = {}
	self:add_sockets(sockets)
end

function tcpserver.TCPServer:stop()
	-- Stop the TCPServer and clean up its mess.

	for file_descriptor, socket in pairs(self._sockets) do
		self.io_loop:remove_handler(file_descriptor)
		socket:close()
	end
end

function tcpserver.TCPServer:handle_stream(stream, address)
	-- What to do with a new stream/connection.
	-- This method should be redefined when inheriting from
	-- the TCPServer class.
	
	error('handle_stream method not implemented in this object')
end

function tcpserver.TCPServer:_handle_connection(connection, address)
	-- Handle new connection.
	
	local stream = IOStream:new(connection, self.io_loop)
	self:handle_stream(stream, address)
end

return tcpserver
