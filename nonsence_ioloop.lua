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

--[[
	
	IOLoop is a class responsible for managing I/O events through file descriptors 
	with epoll. 
	
	Add file descriptors with :add_handler(fd, listen_to_this, handler).
	Handler will be called when event is triggered. Handlers can also be removed from
	the I/O Loop with :remove_handler(fd). This will also remove the event from epoll.
	You can change the event listened for with :update_handler(fd, listen_to_this).
	
	You can not have more than one edge-triggered IOLoop as this will block the Lua thread
	when no events are triggered. Unless you add a timeout to the loop, which is not recommended.
	
	Example of very simple TCP server using a IOLoop object:

	--
	-- Load modules
	--
	require('nonsence_ioloop')
	nixio = require('nixio')
	
	local exampleloop = IOLoop:new()

	local sock = nixio.socket('inet', 'stream')
	local fd = sock:fileno()
	sock:setblocking(false)
	assert(sock:setsockopt('socket', 'reuseaddr', 1))

	sock:bind(nil, 8080)
	assert(sock:listen(1024))

	--
	-- Handler to run when READ event is fired on 
	-- file descriptor
	--
	function some_handler_that_accepts()
		-- Accept socket connection.
		local new_connection = sock:accept()
		local fd = new_connection:fileno()
		--
		-- Handler function when client is ready to read again.
		--
		function some_handler_that_reads()
			new_connection:recv(1024)
			new_connection:write('IOLoop works!')
			new_connection:close()
			--
			-- Trying out a callback.
			--
			exampleloop:add_callback(function() print "This is a callback" end)
		end	
		exampleloop:add_handler(fd, READ, some_handler_that_reads) -- Callback/handler passed.
	end

	exampleloop:add_handler(fd, READ, some_handler_that_accepts)
	exampleloop:start()
	
  ]]

-------------------------------------------------------------------------
--
-- Load modules
--
local log = assert(require('nonsence_log'), 
	[[Missing nonsence_log module]])
local Epoll = assert(require('epoll'), 
	[[Missing required module: Lua Epoll. (https://github.com/Neopallium/lua-epoll)]])
assert(require('stack'), 
	[[Missing stack module]])
assert(require('yacicode'), 
	[[Missing required module: Yet Another class Implementation http://lua-users.org/wiki/YetAnotherClassImplementation]])
-------------------------------------------------------------------------

-------------------------------------------------------------------------
--
-- Epoll module constants
--
-------------------------------------------------------------------------
READ = Epoll.EPOLLIN
WRITE = Epoll.EPOLLOUT
PRI = Epoll.EPOLLPRI
ERR = Epoll.EPOLLERR
-------------------------------------------------------------------------

-------------------------------------------------------------------------
IOLoop = newclass('IOLoop')

function IOLoop:init()	
	self._events = {}
	self._handlers = {}
	self._timeouts = {}
	self._callbacks = Stack:new() -- New Stack object.
	self._callback_lock = false
	self._running = false
	self._stopped = false
	self._epoller = Epoll.new() -- New Epoll object.
end

function IOLoop:add_handler(file_descriptor, events, handler)
	-- Register the callback to recieve events for given file descriptor.
	self._handlers[file_descriptor] = handler
	return self._epoller:add(file_descriptor, events, file_descriptor)
end

function IOLoop:update_handler(file_descriptor, events)
	-- Change the event we listen for on file descriptor.
	return self._epoller:mod(file_descriptor, events, file_descriptor)
end

function IOLoop:remove_handler(file_descriptor)
	-- Stops listening for events on file descriptor.
	self._handler[file_descriptor] = nil
	return self._epoller:del(file_descriptor)
end

function IOLoop:_run_handler(file_descriptor)
	-- Stops listening for events on file descriptor.
	local handler = self._handlers[file_descriptor]
	handler()
end

function IOLoop:add_callback(callback)
	-- Calls the given callback on the next IOLoop iteration.
	self._callbacks:push(callback)
end

function IOLoop:list_callbacks()
	return self._callbacks:list()
end

function IOLoop:_run_callback(callback)
	-- Calls the given callback safe...
	-- Should not crash anything.
	-- TODO: add pcall/xpcall
	callback()
end

function IOLoop:start()	
	-- Starts the I/O loop.
	--
	-- The loop will run until self:stop() is called.
	self._running = true
	
	local events = {}
	
	while true do
		local poll_timeout = 3600
		-- log.dump('I/O loop Iteration started')
		-- log.dump(self._handlers, self._handlers)

		-- Run callbacks from the self._callbacks stack
		while self._callbacks:getn() > 0 do
			self:_run_callback(self._callbacks:pop())
		end
		
		-- If callback did a callback... Then set I/O loop timeout to 0
		-- to avoid waiting to long.
		if self._callbacks:getn() > 0 then
			timeout = 0
		end

		-- Stop the I/Oloop if flag is set.
		-- BUT, finish callbacks
		if self._stopped then 
			self.running = false
			self.stopped = false
			break
		end
		
		-- Wait for I/O
		assert(self._epoller:wait(self._events, poll_timeout))

		-- Do not use ipairs for improved speed.
		for i=1, #self._events, 2 do
			local file_descriptor = self._events[i]
			local event = self._events[i+1]
			
			-- Remove event from table.
			self._events[i] = nil
			self._events[i+1] = nil
			
			-- Run the handler registered for the file descriptor.
			self:_run_handler(file_descriptor)
		end
		
	end
end

function IOLoop:close()
	-- Close the I/O loop.
	-- Closes the loop after this iteration is done. Any callbacks
	-- in the stack will be run before closing.

	self._running = false
	self._stopped = true
	self._events = {}
	self._callbacks = {}
	self._handlers = {}
end

function IOLoop:running()
	-- Returns true if the IOLoop is running
	-- else it will return false.
	return self._running
end
-------------------------------------------------------------------------
