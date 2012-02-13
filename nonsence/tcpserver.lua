--[[
	
	Nonsence Asynchronous event based Lua Web server.
	Author: John Abrahamsen < JhnAbrhmsn@gmail.com >
	
	This module "IOLoop" is a part of the Nonsence Web server.
	< https://github.com/JohnAbrahamsen/nonsence-ng/ >
	
	Nonsence is licensed under the MIT license < http://www.opensource.org/licenses/mit-license.php >:

	"Permission is hereby granted, free of charge, to any person obtaining a copy of
	this software and associated documentation files (the "Software"), to deal in
	the Software without restriction, including without limitation the rights to
	use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
	of the Software, and to permit persons to whom the Software is furnished to do
	so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE."

  ]]
  
-------------------------------------------------------------------------
--
-- Load modules
--
local log = assert(require('log'), 
	[[Missing log module]])
local nixio = assert(require('nixio'),
	[[Missing required module: Nixio (https://github.com/Neopallium/nixio)]])
local iostream = assert(require('iostream'), 
	[[Missing iostream module]])
local ioloop = assert(require('ioloop'), 
	[[Missing ioloop module]])
-------------------------------------------------------------------------
-------------------------------------------------------------------------
-- Speeding up globals access with locals :>
-- 
local IOStream, dump, nixsocket, assert, newclass, ipairs, pairs = 
iostream.IOStream, log.dump, nixio.socket, assert, newclass, ipairs, 
pairs
-------------------------------------------------------------------------
-------------------------------------------------------------------------
-- Table to return on require.
local tcpserver = {}
-------------------------------------------------------------------------

local function bind_sockets(port, address, backlog)
	
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

tcpserver.TCPServer = newclass('TCPServer')

function tcpserver.TCPServer:init(io_loop, ssl_options)

	self.io_loop = io_loop or ioloop.instance()
	self.ssl_options = ssl_options
	self._sockets = {}
	self._pending_sockets = {}
	self._started = false
end

function tcpserver.TCPServer:listen(port, address)
	assert(port, [[Please specify port for listen() method]])
	local sockets = bind_sockets(port, address)
	log.notice("TCPServer listening on port: " .. port)
	self:add_sockets(sockets)
end

function tcpserver.TCPServer:add_sockets(sockets)
	
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
	-- TODO: forking?
	
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

	for file_descriptor, socket in pairs(self._sockets) do
		self.io_loop:remove_handler(file_descriptor)
		socket:close()
	end
end

function tcpserver.TCPServer:handle_stream(stream, address)

	error('handle_stream method not implemented in this object')
end

function tcpserver.TCPServer:_handle_connection(connection, address)
	-- TODO implement SSL
	local stream = IOStream:new(connection, self.io_loop)
	self:handle_stream(stream, address)
end

-------------------------------------------------------------------------
-- Return iostream table to requires.
return tcpserver
-------------------------------------------------------------------------
