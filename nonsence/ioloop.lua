--[[ Nonsence Asynchronous event based Lua Web server.
Author: John Abrahamsen < JhnAbrhmsn@gmail.com >

This module "ioloop" is a part of the Nonsence Web server.
For the complete stack hereby called "software package" please see:

https://github.com/JohnAbrahamsen/nonsence-ng/

Many of the modules in the software package are derivatives of the 
Tornado web server. Tornado is also licensed under Apache 2.0 license.
For more details on Tornado please see:

http://www.tornadoweb.org/


Copyright 2011, 2012 and 2013 John Abrahamsen

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.



Example of very simple TCP server using a IOLoop instance:

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
	exampleloop:start()        ]]

local log, nixio = require('log'), require('nixio')
require('middleclass')
require('ansicolors')

local ioloop = {} -- ioloop namespace

local _poll_implementation = nil

--[[ If you are running LuaJIT and Linux then we will use the included Epoll FFI. Else we will fallback to the lua-epoll module.          ]]
  
if pcall(require, 'epoll_ffi') then
	-- Epoll FFI module found and loaded.
	log.success([[[ioloop.lua] Picked epoll_ffi module as poll module.]])
	_poll_implementation = 'epoll_ffi'
	epoll_ffi = require('epoll_ffi')
	-- Populate global with Epoll module constants
	ioloop.READ = epoll_ffi.EPOLL_EVENTS.EPOLLIN
	ioloop.WRITE = epoll_ffi.EPOLL_EVENTS.EPOLLOUT
	ioloop.PRI = epoll_ffi.EPOLL_EVENTS.EPOLLPRI
	ioloop.ERROR = epoll_ffi.EPOLL_EVENTS.EPOLLERR
else
	-- No poll modules found. Break execution and give error.
	error([[Could not load a poll module. Make sure you are running this with LuaJIT. Standard Lua is not supported.]])
end


--[[ Return the global IOLoop instance. If no global IOLoop instance exists, a new one will be created and set in global.
@return IOLoop class instance
@see ioloop.IOLoop ]]
function ioloop.instance()
	if _G.io_loop_instance then
		return _G.io_loop_instance
	else
		_G.io_loop_instance = ioloop.IOLoop:new()
		return _G.io_loop_instance
	end
end

ioloop.IOLoop = class('IOLoop')

--[[ Create a new instance of IOLoop.

IOLoop is a class responsible for managing I/O events through file descriptors 
with epoll. Heavily influenced by ioloop.py in the Tornado web server.
Add file descriptors with :add_handler(fd, listen_to_this, handler).
Handler will be called when event is triggered. Handlers can also be removed from
the I/O Loop with :remove_handler(fd). This will also remove the event from epoll.
You can change the event listened for with :update_handler(fd, listen_to_this).

Warning: Only one instance of IOLoop can ever run at the same time!

@name ioloop.IOLoop:new
@usage local ioloop = ioloop.IOLoop:new()
@return IOLoop class instance.  ]]
function ioloop.IOLoop:init()	
	self._handlers = {}
	self._timeouts = {}
	self._callbacks = {}
	self._callback_lock = false
	self._running = false
	self._stopped = false
	if _poll_implementation == 'epoll_ffi' then
		self._poll = _EPoll_FFI:new()
	end
end

--[[ Add event handler (function) to IOLoop instance
@param file_descriptor File descriptor [2] to add handler for.
@param events Events [ioloop.READ or ioloop.WRITE...] that will trigger handler function.
@param handler Function to be called when events happen on file_descriptor.
@see ioloop.IOLoop:update_handler()
@see ioloop.IOLoop:remove_handler()   	]]
function ioloop.IOLoop:add_handler(file_descriptor, events, handler)
	self._handlers[file_descriptor] = handler
	self._poll:register(file_descriptor, events)
end

--[[ Change the event we listen for on file descriptor.
@param file_descriptor File descriptor [2] to change events on.
@param events Events [ioloop.READ or ioloop.WRITE...] that will trigger handler function.  ]]
function ioloop.IOLoop:update_handler(file_descriptor, events)
	self._poll:modify(file_descriptor, events)
end

--[[ Stops listening for events on file descriptor.
@param file_descriptor File descriptor [2] to stop listening for events on.   ]]
function ioloop.IOLoop:remove_handler(file_descriptor)	
	self._handlers[file_descriptor] = nil
	return self._poll:unregister(file_descriptor)
end


--[[ Internal method that runs the handler for the file descriptor.
@param file_descriptor File descriptor that triggered the handler.
@param events Events that triggered the handler.    ]]
function ioloop.IOLoop:_run_handler(file_descriptor, events)

    local function _run_handler_err_handler(err)
        log.error("[ioloop.lua] caught error: " .. err)
        self:remove_handler(file_descriptor)
    end
   
    local handler = self._handlers[file_descriptor]
    xpcall(handler, _run_handler_err_handler, file_descriptor, events)
end

--[[ Calls the given callback on the next IOLoop iteration.
@param callback Function to be called.   ]]
function ioloop.IOLoop:add_callback(callback) self._callbacks[#self._callbacks + 1] = callback end

--[[ Lists pending callbacks that will be called on next IOLoop iteration.
@return List with callbacks.   ]]
function ioloop.IOLoop:list_callbacks() return self._callbacks end

--[[ Internal function to handle errors in callbacks, logs everything.
@param err Error message  	]]
local function error_handler(err)
	log.error("[ioloop.lua] caught error: " .. err)
	log.stacktrace(debug.traceback())
end

--[[ Internal method to do protected call for the given callback.   ]]
function ioloop.IOLoop:_run_callback(callback)	
	xpcall(callback, error_handler)
end

--[[ Schedule a callback to be called at after given timestamp.
@param timestamp A Lua timestamp. E.g os.time().
@param callback A function to be called after timestamp is reached.
@return Unique identifier for the scheduled callback.
@see ioloop.IOLoop:remove_timeout()    ]]
function ioloop.IOLoop:add_timeout(timestamp, callback)
	local identifier = Math.random(100000000)
	if not self._timeouts[identifier] then
		self._timeouts[identifier] = _Timeout:new(timestamp, callback)
	end
	return identifier
end

--[[ Remove scheduled callback.
@param identifier Unique identifier for the scheduled callback.
@return true on success else false.	]]
function ioloop.IOLoop:remove_timeout(identifier)	
	if self._timeouts[identifier] then
		self._timeouts[identifier] = nil
		return true
	else
		return false
	end
end

--[[ Starts the I/O loop.
The loop will run until self:stop() is called.
@see ioloop.IOLoop:stop()     ]]
function ioloop.IOLoop:start()	
	self._running = true
	log.notice([[[ioloop.lua] IOLoop started running]])
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
		for i=1, #callbacks, 1 do 
			self:_run_callback(callbacks[i])
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

--[[ Close the I/O loop.
Closes the loop after current iteration is done. Any callbacks
in the stack will be run before closing.   ]]
function ioloop.IOLoop:close()
	self._running = false
	self._stopped = true
	self._callbacks = {}
	self._handlers = {}
end

--[[ Is the IOLoop running?
@return Returns true if the IOLoop is running else it will return false.    ]]
function ioloop.IOLoop:running()
	return self._running
end




_Timeout = class('_Timeout')

--[[ Internal timeout class.
Very simplified way of doing timeout callbacks.     ]]
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




_EPoll_FFI = class('_EPoll_FFI')

-- Internal class for epoll-based event loop using the epoll_ffi module.
function _EPoll_FFI:init()
	-- Create a new epoll and store its fd to self.
	self._epoll_fd = epoll_ffi.epoll_create() -- New epoll, store its fd.
	--log.notice([[ioloop module => epoll_create returned file descriptor ]] .. self._epoll_fd)
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

return ioloop

