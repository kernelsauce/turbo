--[[
	
	Nonsence Asynchronous event based Lua Web server.
	Author: John Abrahamsen < JhnAbrhmsn@gmail.com >
	
	This module "ioloop" is a part of the Nonsence Web server.
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

-------------------------------------------------------------------------
--
-- Load modules
--
local log = assert(require('log'), 
	[[Missing log module]])
local nixio = assert(require('nixio'),
	[[Missing required module: Nixio (https://github.com/Neopallium/nixio)]])
assert(require('middleclass'), 
	[[Missing required module: MiddleClass 
	https://github.com/kikito/middleclass]])
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- Table to return on require.
local ioloop = {}
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- Check for usable poll modules.
local _poll_implementation = nil
if pcall(require, 'epoll_ffi') then
	-- Epoll FFI module found and loaded.
	log.notice([[ioloop module => Picked epoll_ffi module as poll module.]])
	_poll_implementation = 'epoll_ffi'
	epoll_ffi = require('epoll_ffi')
	-- Populate global with Epoll module constants
	ioloop.READ = epoll_ffi.EPOLL_EVENTS.EPOLLIN
	ioloop.WRITE = epoll_ffi.EPOLL_EVENTS.EPOLLOUT
	ioloop.PRI = epoll_ffi.EPOLL_EVENTS.EPOLLPRI
	ioloop.ERROR = epoll_ffi.EPOLL_EVENTS.EPOLLERR
	
elseif pcall(require, 'epoll') then
	-- Epoll module found.
	log.notice([[ioloop module => Picked epoll module as poll module.]])
	_poll_implementation = 'epoll'
	-- Populate global with Epoll module constants
	Epoll = require('epoll')
	ioloop.READ = Epoll.EPOLLIN
	ioloop.WRITE = Epoll.EPOLLOUT
	ioloop.PRI = Epoll.EPOLLPRI
	ioloop.ERROR = Epoll.EPOLLERR
else
	-- No poll modules found. Break execution and give error.
	error([[No poll modules found. Either use LuaJIT, which supports the
	Epoll FFI module that is bundled or get Lua Epoll from (https://github.com/Neopallium/lua-epoll)]])
end
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- Speeding up globals access with locals :>
--
local xpcall, pcall, random, class, pairs, ipairs, os, epoll_ffi, Epoll = xpcall, 
pcall, math.random, class, pairs, ipairs, os, epoll_ffi, Epoll
-------------------------------------------------------------------------

function ioloop.instance()
	-- Return a global instance of IOLoop.
	-- Creates one if not existing, otherwise returning the old one.
	
	if _G.io_loop_instance then
		return _G.io_loop_instance
	else
		_G.io_loop_instance = ioloop.IOLoop:new()
		return _G.io_loop_instance
	end
end

-------------------------------------------------------------------------

ioloop.IOLoop = class('IOLoop')
--[[
	
	IOLoop is a class responsible for managing I/O events through file descriptors 
	with epoll. Heavily influenced by ioloop.py in the Tornado web server.
	
	Add file descriptors with :add_handler(fd, listen_to_this, handler).
	Handler will be called when event is triggered. Handlers can also be removed from
	the I/O Loop with :remove_handler(fd). This will also remove the event from epoll.
	You can change the event listened for with :update_handler(fd, listen_to_this).
	
	Example of very simple TCP server using a IOLoop object:

		--
		-- Load modules
		--
		local ioloop = require('nonsence_ioloop')
		nixio = require('nixio')
		
		local exampleloop = ioloop.IOLoop:new()

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
			exampleloop:add_handler(fd, ioloop.READ, some_handler_that_reads) -- Callback/handler passed.
		end

		exampleloop:add_handler(fd, ioloop.READ, some_handler_that_accepts)
		exampleloop:start()

  ]]

function ioloop.IOLoop:init()	

	self._handlers = {}
	self._timeouts = {}
	self._callbacks = {}
	self._callback_lock = false
	self._running = false
	self._stopped = false
	if _poll_implementation == 'epoll' then
		self._poll = _EPoll:new() 
	elseif _poll_implementation == 'epoll_ffi' then
		self._poll = _EPoll_FFI:new()
	end
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
	
	self._handlers[file_descriptor] = nil
	return self._poll:unregister(file_descriptor)
end

function ioloop.IOLoop:_run_handler(file_descriptor, events)
	-- Runs the handler for the file descriptor.
	
	local handler = self._handlers[file_descriptor]
	handler(file_descriptor, events)
end

function ioloop.IOLoop:add_callback(callback)
	-- Calls the given callback on the next IOLoop iteration.
	
	self._callbacks[#self._callbacks + 1] = callback
end

function ioloop.IOLoop:list_callbacks()
	return self._callbacks
end

local function error_handler(err)
	-- Handles errors in _run_callback.
	-- Verbose printing of error to console.
	log.error([[_callback_error_handler caught error: ]] .. err)
	log.error(debug.traceback())
end

function ioloop.IOLoop:_run_callback(callback)
	-- Calls the given callback safe...
	-- Should not crash anything.
	
	-- callback()
	xpcall(callback, error_handler)
end

function ioloop.IOLoop:add_timeout(timestamp, callback)
	-- Schedule a callback to be called at given timestamp.
	-- Timestamp is e.g os.time(now)
	
	local identifier = random(100000000)
	if not self._timeouts[identifier] then
		self._timeouts[identifier] = _Timeout:new(timestamp, callback)
	end
	return identifier
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
	log.notice([[ioloop module => IOLoop started running]])
	while true do
		--log.warning("Callbacks in queue: " .. #self._callbacks)
		--log.warning("Started new I/O loop iteration.\r\n\r\n")

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
		local events = self._poll:poll(poll_timeout)
		-- Do not use ipairs for improved speed.
		for i=1, #events do
			
			-- Run the handler registered for the file descriptor.
			self:_run_handler(events[i][1], events[i][2])
		end
		
	end
end

function ioloop.IOLoop:close()
	-- Close the I/O loop.
	-- Closes the loop after this iteration is done. Any callbacks
	-- in the stack will be run before closing.

	self._running = false
	self._stopped = true
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
_Timeout = class('_Timeout')
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
_EPoll_FFI = class('_EPoll_FFI')
-- Epoll-based event loop using the epoll_ffi module.

function _EPoll_FFI:init()
	-- Create a new object from EPoll module.
	
	self._epoll_fd = epoll_ffi.epoll_create() -- New epoll, store its fd.
	log.notice([[ioloop module => epoll_create returned file descriptor ]] .. self._epoll_fd)
end

function _EPoll_FFI:fileno()
	return self._epoll_fd
end

function _EPoll_FFI:register(file_descriptor, events)
	epoll_ffi.epoll_ctl(self._epoll_fd, epoll_ffi.EPOLL_CTL_ADD, 
		file_descriptor, events)
end

function _EPoll_FFI:modify(file_descriptor, events)
	epoll_ffi.epoll_ctl(self._epoll_fd, epoll_ffi.EPOLL_CTL_MOD, 
		file_descriptor, events)
end

function _EPoll_FFI:unregister(file_descriptor)
	epoll_ffi.epoll_ctl(self._epoll_fd, epoll_ffi.EPOLL_CTL_DEL, 
		file_descriptor, 0)	
end

function _EPoll_FFI:poll(timeout)
	return epoll_ffi.epoll_wait(self._epoll_fd, timeout)
end

-------------------------------------------------------------------------
_EPoll = class('_EPoll')
-- Epoll-based event loop using the lua-epoll module.

function _EPoll:init()
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
	local events_t = {}
	self._epoller:wait(events, timeout)
	for i = 1, #events, 2 do 
		events_t[#events_t + 1] = {events[i], events[i+1]}
		events[i] = nil
		events[i+1] = nil
	end
	return events_t
end
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- Return ioloop table to requires.
return ioloop
-------------------------------------------------------------------------
