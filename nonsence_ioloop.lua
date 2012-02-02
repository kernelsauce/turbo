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
	
	IOLoop is a class responsible for managing I/O events through epoll.
	
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
EPOLLET = Epoll.EPOLLET
-------------------------------------------------------------------------

-------------------------------------------------------------------------
IOLoop = newclass('IOLoop')

function IOLoop:init()	
	self._events = {}
	self._handlers = {}
	self._callbacks = Stack:new() -- New Stack object.
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
		-- log.dump('I/O loop Iteration started')
		-- log.dump(self._handlers, self._handlers)
		-- Stop the I/Oloop if flag is set.
		-- BUT, finish callbacks
		if self._stopped then 
			self.running = false
			self.stopped = false
			break
		end
		
		-- Run callbacks from the self._callbacks stack
		while self._callbacks:getn() > 0 do
			self:_run_callback(self._callbacks:pop())
		end
		
		-- Wait for I/O
		assert(self._epoller:wait(self._events, -1))

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
end

function IOLoop:running()
	-- Returns true if the IOLoop is running
	-- else it will return false.
	return self._running
end
-------------------------------------------------------------------------
