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
assert(require('deque'), 
[[Missing required module: deque]])
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- Speeding up globals access with locals :>
--
local xpcall, pcall, random, newclass, pairs, ipairs, os, bitor, 
bitand, dump, min, max, newclass, assert, deque, concat = xpcall, 
pcall, math.random, newclass, pairs, ipairs, os, nixio.bit.bor, 
nixio.bit.band, log.dump, math.min, math.max, newclass, assert, deque
, table.concat
-------------------------------------------------------------------------
-- Table to return on require.
local iostream = {}
-------------------------------------------------------------------------

iostream.IOStream = newclass('IOStream')

function iostream.IOStream:init(socket, io_loop, max_buffer_size, read_chunk_size)

	self.socket = assert(socket, [[Please provide a socket for IOStream:new()]])
	self.socket:setblocking(false)
	self.io_loop = io_loop or ioloop.instance()
	self.max_buffer_size = max_buffer_size or 104857600
	self.read_chunk_size = read_chunk_size or 4096
	self._read_buffer = deque:new()
	self._write_buffer = deque:new()
	self._read_buffer_size = 0
	self._write_buffer_frozen = false
	self._read_delimiter = nil
	self._read_pattern = nil
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
	
	self.socket:connect(address, port)
	-- Set callback.
	self._connect_callback = callback
	self:_add_io_state(ioloop.WRITE)
end

function iostream.IOStream:read_until_pattern(pattern, callback)
	-- Call callback when the given pattern is read.
	
	assert(( not self._read_callback ), "Already reading.")
	self._read_pattern = pattern
	
	while true do
		if self:_read_from_buffer() then
			return
		end
		self:_check_closed()
		if self:_read_to_buffer() == 0 then
			-- Buffer exhausted. Break.
			break
		end
	end
	self:_add_io_state(ioloop.READ)
end

function iostream.IOStream:read_until(delimiter, callback)
	-- Call callback when the given delimiter is read.

	assert(( not self._read_callback ), "Already reading.")
	self._read_delimiter = delimiter
	self._read_callback = callback

	while true do 
		if self:_read_from_buffer() then
			return
		end
		self:_check_closed()
		if self:_read_to_buffer() == 0 then
			break
		end
	end
	print('add new handler')
	self:_add_io_state(ioloop.READ)
end

function iostream.IOStream:read_bytes(num_bytes, callback, streaming_callback)
	-- Call callback when we read the given number of bytes
	
	-- If a streaming_callback argument is given, it will be called with
	-- chunks of data as they become available, and the argument to the
	-- final call to callback will be empty.

	assert(( not self._read_callback ), "Already reading.")
	assert(type(num_bytes) == 'number', 'num_bytes argument must be a number')
	self._read_bytes = num_bytes
	self._read_callback = callback
	self._streaming_callback = streaming_callback
	
	while true do
		if self:_read_from_buffer() then
			return
		end
		self:_check_closed()
		if self:_read_to_buffer() == 0 then 
			break
		end
	end
	self:_add_io_state(ioloop.READ)
end

function iostream.IOStream:read_until_close(callback, streaming_callback)
	-- Reads all data from the socket until it is closed.
	
	-- If a streaming_callback argument is given, it will be called with
	-- chunks of data as they become available, and the argument to the
	-- final call to callback will be empty.
	
	-- This method respects the max_buffer_size set in the IOStream object.
	
	assert(( not self._read_callback ), "Already reading.")
	if self:closed() then
		self:_run_callback(callback, self:_consume(self._read_buffer_size))
		return
	end
	self._read_until_close = true
	self._read_callback = callback
	self._streaming_callback = streaming_callback
	self:_add_io_state(ioloop.READ)
end

function iostream.IOStream:write(data, callback)
	-- Write the given data to this stream.

	-- If callback is given, we call it when all of the buffered write
	-- data has been successfully written to the stream. If there was
	-- previously buffered write data and an old write callback, that
	-- callback is simply overwritten with this new callback.
	
	self:_check_closed()
	if data then
		self._write_buffer:append(data)
	end
	self._write_callback = callback
	self:_handle_write()
	
	if self._write_buffer:not_empty() then
		self:_add_io_state(ioloop.WRITE)
	end
	self:_maybe_add_error_listener()
end	

function iostream.IOStream:set_close_callback(callback)
	-- Call the given callback when the stream is closed.
	
	self._close_callback = callback
end

function iostream.IOStream:close()
	-- Close this stream
	
	if self.socket then
		if self._read_until_close then
			local callback = self._read_callback
			self._read_callback = nil
			self._read_until_close = false
			self:_run_callback(callback, self:_consume(self._read_buffer_size))
		end
		if self._state then
			self.io_loop:remove_handler(self.socket:fileno())
			self._state = nil
		end
		self.socket:close()
		self.socket = nil
		if self._close_callback and self._pending_callbacks == 0 then
			local callback = self._close_callback
			self._close_callback = nil
			self._run_callback(callback)
		end
	end
end

function iostream.IOStream:_handle_events(file_descriptor, events)
	-- Handle events
	print('got event: ' .. events)
	if not self.socket then 
		-- Connection has been closed. Can not handle events...
		log.warning([[_handle_events() got events for closed sockets.]])
		return
	end
	-- Handle different events.
	if events == ioloop.READ then
		self:_handle_read()
	end
	
	if not self.socket then 
		return
	end

	if events == ioloop.WRITE then
		if self._connecting then 
			self:_handle_connect()
		end
		self:_handle_write()	
	end
	
	if not self.socket then 
		return
	end

	if events == ioloop.ERROR then
		-- We may have queued up a user callback in _handle_read or
		-- _handle_write, so don't close the IOStream until those
		-- callbacks have had a chance to run.
		
		-- Wrap callback
		local function _close_wrapper()
			self.close(self)
		end
		
		self.io_loop:add_callback(_close_wrapper)
		return
	end
		
	local state = ioloop.ERROR
	
	if self:reading() then
		state = ioloop.READ
	end
	if self:writing() then
		state = ioloop.WRITE
	end
	if state == ioloop.ERROR then
		state = ioloop.READ
	end
	if state ~= self._state then
		self._state = state
		self.io_loop:update_handler(self.socket:fileno(), self._state)
	end
end

function iostream.IOStream:_run_callback(callback, ...)
	local function wrapper(...)
		self._pending_callbacks = self._pending_callbacks - 1
		callback(...)
	end
	self:_maybe_add_error_listener()
	self._pending_callbacks = self._pending_callbacks + 1
	self.io_loop:add_callback(wrapper)
end

function iostream.IOStream:_handle_read()

	while true do 
	
		-- Read from socket until we get EWOULDBLOCK or equivalient.
		local result = self:_read_to_buffer()
		if result == 0 then
			break
		else
			if self:_read_from_buffer() then
				return
			end
		end
	end
end

function iostream.IOStream:reading()
	return ( not not self._read_callback )
end

function iostream.IOStream:writing()
	return ( not not self._write_buffer )
end

function iostream.IOStream:closed()
	return ( not not self.socket )
end

function iostream.IOStream:_read_from_socket()
	-- Reads from the socket.
	-- Return the data chunk or nil if theres nothing to read.
	
	local chunk = self.socket:read(self.read_chunk_size)
	-- TODO: Fix this...
	-- Returns false when theres nothing to read... Should be 0
	--	if not chunk then 
	--		self:close()
	--		return nil
	--	end
	
	return chunk
end

function iostream.IOStream:_read_to_buffer()
	-- Read from the socket and append to the read buffer.
	
	local chunk = self:_read_from_socket()
	if not chunk then
		return 0
	end
	self._read_buffer:append(chunk)
	self._read_buffer_size = self._read_buffer_size + chunk:len()
	if self._read_buffer_size >= self.max_buffer_size then
		logging.error('Reached maximum read buffer size')
		self:close()
		return
	end
	return chunk:len()
end

function iostream.IOStream:_read_from_buffer()
	-- Attempts to complete the currently pending read from the buffer.
	-- Returns true if the read was completed.
	print('Reading from _read_buffer')
	if self._read_bytes then
		if self._streaming_callback ~= nil and self._read_buffer_size then
			local bytes_to_consume = min(self._ready_bytes, self._read_buffer_size)
			self._read_bytes = self._read_bytes - bytes_to_consume
			self:_run_callback(self._streaming_callback, 
				self:_consume(bytes_to_consume))
		end
		if self._read_buffer_size >= self._ready_bytes then
			local num_bytes = self._read_bytes
			local callback = self._read_callback
			self._read_callback = nil
			self._streaming_callback = nil
			self._read_bytes = nil
			self:_run_callback(callback, self:_consume(num_bytes))
			return true
		end
		
	elseif self._read_delimiter then
		-- TODO, this does not work at all...
		local loc = -1
		if self._read_buffer:not_empty() then
			loc = self._read_buffer:peekfirst():find(self._read_delimiter)
		end
		print(string.find(self._read_buffer:peekfirst(), self._read_delimiter))
		print('loc is: ' .. loc)
		while loc == -1 and self._read_buffer:size() > 1 do
			local new_len = max(self._read_buffer:getn(0):len() * 2,
				self._read_buffer:getn(0):len() +
				self._read_buffer:getn(1):len())
			_merge_prefix(self._read_buffer:getn(0):find(self._read_delimiter))
						
			if loc ~= -1 then
				local callback = self._read_callback
				local delimiter_len = self._read_delimiter:len()
				self._read_callback = nil
				self._streaming_callback = nil
				self._read_delimiter = nil
				self:_run_callback(callback, self:_consume(loc + delimiter_len))
				return true
			end
		end
	
	-- TODO: implement read_until_pattern
	
	elseif self._read_until_close then
			if self._streaming_callback ~= nil and self._read_buffer_size then
				self:_run_callback(self._streaming_callback, 
					self:_consume(self._read_buffer_size))
			end
	end
	
	return false
end

function iostream.IOStream:_handle_connect()

	local err = self.socket:getopt('socket', 'error')
	if not err == 0 then 
		log.warning(string.format("Connect error on fd %d: %s", 
			self.socket:fileno(), err ))
		self:close()
		return
	end
	if self._connect_callback then
		local callback = self._connect_callback
		self._connect_callback  = nil
		self:_run_callback(callback)
	end
	self._connecting = false
end

function iostream.IOStream:_handle_write()

	while self._write_buffer:not_empty() do

		if not self._write_buffer_frozen then
			_merge_prefix(self._write_buffer, 128 * 1024)
		end
		
		local num_bytes = self.socket:send(self._write_buffer:peekfirst())
		
		if num_bytes == 0 then
			self._write_buffer_frozen = true
			break
		end
		self._write_buffer_frozen = false
		_merge_prefix(self._write_buffer, num_bytes)
		self._write_buffer:popleft()
	end

	if self._write_buffer:not_empty() == false and self._write_callback then
		local callback = self._write_callback
		self._write_callback = nil
		self:_run_callback(callback)
	end
end

function iostream.IOStream:_add_io_state(state)
	-- Add IO state to IOLoop.
	if not self.socket then
		-- Connection has been closed, can not add state.
		return
	end
	
	if not self._state then
		self._state = state or ioloop.ERROR
		local function _handle_events_wrapper(file_descriptor, events)
			self:_handle_events(file_descriptor, events)
		end
		self.io_loop:add_handler(self.socket:fileno(), self._state, _handle_events_wrapper )
	elseif self._state and state then
		self._state = state or self._state
		self.io_loop:update_handler(self.socket:fileno(), self._state)
	end
	
end

function iostream.IOStream:_consume(loc)
	if loc == 0 then
		return ""
	end
	_merge_prefix(self._read_buffer, loc)
	self._read_buffer_size = self._read_buffer_size - loc
	return self._read_buffer:popleft()
end

function iostream.IOStream:_check_closed()
	if not self.socket then
		log.error("Stream is closed")
	end
end

function iostream.IOStream:_maybe_add_error_listener()
	if self._state == nil and self._pending_callbacks == 0 then
		if self.socket == nil then
			local callback = self._close_callback
				if callback ~= nil then
					self._close_callback = nil
					self._run_callback(callback)
				end
		else
			self._add_io_state(ioloop.READ)
		end
	end
end

function _merge_prefix(deque, size)
	-- Replace the first entries in a deque of strings with a
	-- single string of up to size bytes.
	
	if deque:size() == 1 and deque:peekfirst():len() <= size then
		return
	end
	local prefix = {}
	local remaining = size
	
	while deque:size() > 0 and remaining > 0 do
		local chunk = deque:popleft()
		if chunk:len() > remaining then
			deque:appendleft(chunk:sub(1, remaining))
			chunk = chunk(remaining, chunk:len())
		end
		prefix[#prefix + 1] = chunk
		remaining = remaining - chunk:len()
	end
	
	if #prefix > 0 then
		deque:appendleft(concat(prefix))
	end
	if deque:size() == 0 then
		deque:appendleft("")
	end
end

-------------------------------------------------------------------------
-- Return ioloop table to requires.
return iostream
-------------------------------------------------------------------------
