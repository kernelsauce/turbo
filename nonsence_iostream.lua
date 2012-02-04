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
local log = assert(require('nonsence_log'), 
	[[Missing nonsence_log module]])
local nixio = assert(require('nixio'),
	[[Missing required module: Nixio (https://github.com/Neopallium/nixio)]])
local ioloop = assert(require('nonsence_ioloop'), 
	[[Missing nonsence_ioloop module]])
assert(require('yacicode'), 
[[Missing required module: Yet Another class Implementation http://lua-users.org/wiki/YetAnotherClassImplementation]])
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- Table to return on require.
local iostream = {}
-------------------------------------------------------------------------


iostream.IOStream = newclass('IOStream')

function iostream.IOStream:init(socket, io_loop, max_buffer_size, read_chunk_size)
	self.socket = assert(socket, [[Please provide a socket for IOStream:new()]])
	self.socket:setblocking(false)
	self.io_loop = io_loop or ioloop.IOLoop:new()
	self.max_buffer_size = max_buffer_size or 104857600
	self.read_chunk_size = read_chunk_size or 4096
	self._read_buffer = {}
	self._write_buffer = {}
	self._read_buffer_size = 0
	self._write_buffer_frozen = false
	self._read_delimiter = nil
	self._read_regex = nil
	self._read_bytes = nil
	self._read_until_close = false
	self._read_callback = nil
	self._streaming_callback = nil
	self._write_callback = nil
	self._close_callback = nil
	self._connect_callback = nil
	self._connecting = false
	self._state = nil
	self._pending_callbacks = 0
end

function iostream.IOStream:connect(address, port, callback)
	-- Connect to a address without blocking.
	-- Address can be a IP or DNS domain.
	self._connecting = true
	self.socket:connect()
	self._connect_callback = callback
end

function iostream.IOStream:_add_io_state(state)
	-- Add io state to IOLoop.
	--
	if not self._socket then
		-- Connection has been closed, can not add state.
		return
	end
	if not self._state then
		self._state = ioloop.ERROR or state
	end
end

-------------------------------------------------------------------------
-- Return ioloop table to requires.
return iostream
-------------------------------------------------------------------------
