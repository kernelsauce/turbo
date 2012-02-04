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
	with epoll. Heavily influenced by ioloop.py in the Tornado web server.
	
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
assert(require('stack'), 
	[[Missing stack module]])
assert(require('yacicode'), 
	[[Missing required module: Yet Another class Implementation http://lua-users.org/wiki/YetAnotherClassImplementation]])
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- Speeding up globals access with locals :>
--
local xpcall, pcall, random, newclass, pairs, ipairs, os = xpcall, 
pcall, math.random, newclass, pairs, ipairs, os
-------------------------------------------------------------------------
-- Globals
-- 
local _poll_implementation = nil
-------------------------------------------------------------------------
-- Table to return on require.
local ioloop = {}
-------------------------------------------------------------------------

-------------------------------------------------------------------------
ioloop.IOLoop = newclass('IOLoop')

function ioloop.IOLoop:init()	
	self._events = {}
	self._handlers = {}
	self._timeouts = {}
	self._callbacks = {}
	self._callback_lock = false
	self._running = false
	self._stopped = false
	self._poll = _poll_implementation == 'epoll' and _EPoll:new() 
end

function ioloop.IOLoop:add_handler(file_descriptor, events, handler)
	-- Register the callback to recieve events for given file descriptor.
	self._handlers[file_descriptor] = handler
	self._poll:register(file_descriptor, events)
end

function ioloop.IOLoop:update_handler(file_descriptor, events)
	-- Change the event we listen for on file descriptor.
	self._poll:modify(file_descriptor, events)
end

function ioloop.IOLoop:remove_handler(file_descriptor)
	-- Stops listening for events on file descriptor.
	self._handler[file_descriptor] = nil
	return self._poll:unregister(file_descriptor)
end

function ioloop.IOLoop:_run_handler(file_descriptor)
	-- Stops listening for events on file descriptor.
	local handler = self._handlers[file_descriptor]
	handler()
end

function ioloop.IOLoop:add_callback(callback)
	-- Calls the given callback on the next IOLoop iteration.
	self._callbacks[#self._callbacks + 1] = callback
end

function ioloop.IOLoop:list_callbacks()
	return self._callbacks
end

function ioloop.IOLoop:_run_callback(callback)
	-- Calls the given callback safe...
	-- Should not crash anything.
	xpcall(callback, self._callback_error_handler)
end

function ioloop.IOLoop:_callback_error_handler(err)
	-- Handles errors in _run_callback.
	-- Verbose printing of error to console.
	print([[_callback_error_handler caught error: ]], self)
	return nil
end

function ioloop.IOLoop:add_timeout(timestamp, callback)
	-- Schedule a callback to be called at given timestamp.
	-- Timestamp is e.g os.time(now)
	local identifer = random(100000000)
	if not self._timeouts[identifier] then
		self._timeouts[identifer] = _Timeout:new(timestamp, callback)
	end
	return indentifer
end

function ioloop.IOLoop:remove_timeout(identifier)
	-- Remove timeout.
	-- Use the identifier returned by add_timeout() as arg.
	if self._timeouts[identifier] then
		self._timeouts[identifier] = nil
		return true
	else
		return false
	end
end

function ioloop.IOLoop:start()	
	-- Starts the I/O loop.
	--
	-- The loop will run until self:stop() is called.
	self._running = true
	
	while true do
		local poll_timeout = 3600
		-- log.dump('I/O loop Iteration started')
		-- log.dump(self._handlers, self._handlers)

		-- Run callbacks from self._callback
		-- But, assign it to a local and run off that so we don't
		-- run callbacks from callbacks this iteration.
		local callbacks = self._callbacks
		
		 -- Reset self._callbacks.
		self._callbacks = {}
		
		-- Iterate over callbacks.
		for _, callback in ipairs(callbacks) do
			self:_run_callback(callback)
		end
		
		-- If callback did a callback... Then set I/O loop timeout to 0
		-- to avoid waiting to long.
		if #self._callbacks > 0 then
			poll_timeout = 0
		end

		-- Check for pending timeouts that has, well, timed out.
		if #self._timeouts > 0 then
			for _, timeout in ipairs(self._timeouts) do
				if timeout:timed_out() then
					self:_run_callback( timeout:return_callback() )
				end
			end
		end
		
		-- Stop the I/Oloop if flag is set.
		-- After the callbacks are now finished.
		if self._stopped then 
			self.running = false
			self.stopped = false
			break
		end
		
		-- Wait for I/O, get events since last iteration.
		self._events = self._poll:poll(poll_timeout)

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

function ioloop.IOLoop:close()
	-- Close the I/O loop.
	-- Closes the loop after this iteration is done. Any callbacks
	-- in the stack will be run before closing.

	self._running = false
	self._stopped = true
	self._events = {}
	self._callbacks = {}
	self._handlers = {}
end

function ioloop.IOLoop:running()
	-- Returns true if the IOLoop is running
	-- else it will return false.
	return self._running
end
-------------------------------------------------------------------------

-------------------------------------------------------------------------
_Timeout = newclass('_Timeout')
-- Timeout class.
-- Very simplified way of doing timeout callbacks.
-- Lua's smallest time unit is seconds unfortunately, so this is not
-- very accurate...

function _Timeout:init(timestamp, callback)
	self._timestamp = timestamp or error('No timestamp given to _Timeout class')
	self._callback = callback or error('No callback given to _Timeout class')
end

function _Timeout:timed_out()
	return ( time.now() - timestamp < 0 )
end

function _Timeout:return_callback()
	return self._callback
end
-------------------------------------------------------------------------

-------------------------------------------------------------------------
_EPoll = newclass('_EPoll')
-- Epoll-based event loop using the lua-epoll module.

function _EPoll:init()
	local Epoll = require('epoll')

	-- Populate global with Epoll module constants
	ioloop.READ = Epoll.EPOLLIN
	ioloop.WRITE = Epoll.EPOLLOUT
	ioloop.PRI = Epoll.EPOLLPRI
	ioloop.ERR = Epoll.EPOLLERR

	-- Create a new object from EPoll module.
	self._epoller = Epoll.new() -- New Epoll object.
end

function _EPoll:fileno()
	return self._epoller:fileno()
end

function _EPoll:register(file_descriptor, events)
	self._epoller:add(file_descriptor, events, file_descriptor)
end

function _EPoll:modify(file_descriptor, events)
	self._epoller:mod(file_descriptor, events, file_descriptor)
end

function _EPoll:unregister(file_descriptor)
	self._epoller:del(file_descriptor)
end

function _EPoll:poll(timeout)
	local events = {}
	self._epoller:wait(events, timeout)
	return events
end
-------------------------------------------------------------------------


-------------------------------------------------------------------------
-- Check for usable poll modules.
if pcall(require, 'epoll') then
	-- Epoll module found.
	_poll_implementation = 'epoll'
else
	-- No poll modules found. Break execution and give error.
	error([[No poll modules found. Install Lua Epoll. (https://github.com/Neopallium/lua-epoll)]])
end
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- Return ioloop table to requires.
return ioloop
-------------------------------------------------------------------------
