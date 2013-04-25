--[[ Nonsence IO Loop module

Copyright 2011, 2012, 2013 John Abrahamsen

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.		]]

local log = require "log"
require('middleclass')
require('ansicolors')

local ioloop = {} -- ioloop namespace

local _poll_implementation = nil
  
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


function ioloop.instance()
	if _G.io_loop_instance then
		return _G.io_loop_instance
	else
		_G.io_loop_instance = ioloop.IOLoop:new()
		return _G.io_loop_instance
	end
end

ioloop.IOLoop = class('IOLoop')
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

function ioloop.IOLoop:add_handler(file_descriptor, events, handler)
	self._handlers[file_descriptor] = handler
	self._poll:register(file_descriptor, events)
end

function ioloop.IOLoop:update_handler(file_descriptor, events)
	self._poll:modify(file_descriptor, events)
end

function ioloop.IOLoop:remove_handler(file_descriptor)	
	self._handlers[file_descriptor] = nil
	self._poll:unregister(file_descriptor)
end


function ioloop.IOLoop:_run_handler(file_descriptor, events)

    local function _run_handler_err_handler(err)
        log.error("[ioloop.lua] caught error: " .. err)
        self:remove_handler(file_descriptor)
    end
   
    local handler = self._handlers[file_descriptor]
    xpcall(handler, _run_handler_err_handler, file_descriptor, events)
end

function ioloop.IOLoop:running() return self._running end
function ioloop.IOLoop:add_callback(callback) self._callbacks[#self._callbacks + 1] = callback end
function ioloop.IOLoop:list_callbacks() return self._callbacks end

local function error_handler(err)
	log.error("[ioloop.lua] caught error: " .. err)
	log.stacktrace(debug.traceback())
end

function ioloop.IOLoop:_run_callback(callback)	xpcall(callback, error_handler) end


function ioloop.IOLoop:add_timeout(timestamp, callback)
	local identifier = Math.random(100000000)
	if not self._timeouts[identifier] then
		self._timeouts[identifier] = _Timeout:new(timestamp, callback)
	end
	return identifier
end

function ioloop.IOLoop:remove_timeout(identifier)	
	if self._timeouts[identifier] then
		self._timeouts[identifier] = nil
		return true
	else
		return false
	end
end

function ioloop.IOLoop:start()	
	self._running = true
	log.notice([[[ioloop.lua] IOLoop started running]])
	while true do
		local poll_timeout = 3600
		local callbacks = self._callbacks
		self._callbacks = {}
		

		for i=1, #callbacks, 1 do 
			self:_run_callback(callbacks[i])
		end
		
		if #self._callbacks > 0 then
			poll_timeout = 0
		end

		if #self._timeouts > 0 then
			for _, timeout in ipairs(self._timeouts) do
				if timeout:timed_out() then
					self:_run_callback( timeout:return_callback() )
				end
			end
		end
		
		if self._stopped then 
			self.running = false
			self.stopped = false
			break
		end
		
		local events = self._poll:poll(poll_timeout)
		for i=1, #events do
			self:_run_handler(events[i][1], events[i][2])
		end
		
	end
end

function ioloop.IOLoop:close()
	self._running = false
	self._stopped = true
	self._callbacks = {}
	self._handlers = {}
end



_Timeout = class('_Timeout')
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
	self._epoll_fd = epoll_ffi.epoll_create() -- New epoll, store its fd.
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

