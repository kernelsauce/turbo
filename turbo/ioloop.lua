-- Turbo.lua IOLoop module
--
-- Copyright John Abrahamsen 2011, 2012, 2013 < JhnAbrhmsn@gmail.com >
--
-- "Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE."

local log = require "turbo.log"
local util = require "turbo.util"
local signal = require "turbo.signal"
local socket = require "turbo.socket_ffi"
local coctx = require "turbo.coctx"
require "turbo.3rdparty.middleclass"

local unpack = util.funpack
local ioloop = {} -- ioloop namespace

local _poll_implementation = nil
  
if pcall(require, 'turbo.epoll_ffi') then
    -- Epoll FFI module found and loaded.
    log.success([[[ioloop.lua] Picked epoll_ffi module as poll module.]])
    _poll_implementation = 'epoll_ffi'
    epoll_ffi = require 'turbo.epoll_ffi'
    -- Populate global with Epoll module constants
    ioloop.READ = epoll_ffi.EPOLL_EVENTS.EPOLLIN
    ioloop.WRITE = epoll_ffi.EPOLL_EVENTS.EPOLLOUT
    ioloop.PRI = epoll_ffi.EPOLL_EVENTS.EPOLLPRI
    ioloop.ERROR = bit.bor(epoll_ffi.EPOLL_EVENTS.EPOLLERR, epoll_ffi.EPOLL_EVENTS.EPOLLHUP)
else
    -- No poll modules found. Break execution and give error.
    error([[Could not load a poll module. Make sure you are running this with LuaJIT. Standard Lua is not supported.]])
end

--- Create or get the global IOLoop instance.
-- Multiple calls to this function returns the same IOLoop.
-- @return IOLoop class instance.
function ioloop.instance()
    if _G.io_loop_instance then
        return _G.io_loop_instance
    else
        _G.io_loop_instance = ioloop.IOLoop:new()
        return _G.io_loop_instance
    end
end

ioloop.IOLoop = class('IOLoop')
function ioloop.IOLoop:initialize()
    self._co_cbs = {}
    self._co_ctxs = {}
    self._handlers = {}
    self._timeouts = {}
    self._intervals = {}
    self._callbacks = {}
    self._running = false
    self._stopped = false
    if _poll_implementation == 'epoll_ffi' then
            self._poll = _EPoll_FFI:new()
    end
    
    signal.signal(signal.SIGPIPE, signal.SIG_IGN)
end

--- Add handler function for given event mask on fd.
-- @param file_descriptor File descriptor to bind handler for.
-- @param events Events bit mask.
-- @param handler Function handler.
-- @param arg Argument for function handler. Handler is called with this as first argument.
-- @return true if successfull else false.
function ioloop.IOLoop:add_handler(file_descriptor, events, handler, arg)
    local rc, errno = self._poll:register(file_descriptor, bit.bor(events, ioloop.ERROR))
    if (rc ~= 0) then
        log.notice(string.format("[ioloop.lua] register() in add_handler() failed: %s", socket.strerror(errno)))
        return false
    end
    self._handlers[file_descriptor] = {handler, arg}
    return true
end

--- Update existing handler function.
-- @param file_descriptor File descriptor to bind handler for.
-- @param events Events bit mask.
-- @return true if successfull else false.
function ioloop.IOLoop:update_handler(file_descriptor, events)
    local rc, errno = self._poll:modify(file_descriptor, bit.bor(events, ioloop.ERROR))
    if (rc ~= 0) then
        log.notice(string.format("[ioloop.lua] register() in update_handler() failed: %s", socket.strerror(errno)))
        return false
    end
    return true
end

--- Remove existing handler function.
-- @param file_descriptor File descriptor to bind handler for.
-- @return true if successfull else false.
function ioloop.IOLoop:remove_handler(file_descriptor)	
    if not self._handlers[file_descriptor] then
        return
    end
    local rc, errno = self._poll:unregister(file_descriptor)
    if (rc ~= 0) then
        log.notice(string.format("[ioloop.lua] register() in remove_handler() failed: %s", socket.strerror(errno)))
        return false
    end
    self._handlers[file_descriptor] = nil
    return true
end

local function _run_handler_error_handler(err)
    log.debug("[ioloop.lua] Uncaught error in handler. " .. err)
    log.stacktrace(debug.traceback())
end

local function _run_handler_protected(ioloop_fd_callback, arg, fd, events)
    ioloop_fd_callback(arg, fd, events)
end

function ioloop.IOLoop:_run_handler(fd, events)
    local ok
    local handler = self._handlers[fd]
    -- handler index 1 = function
    -- handler index 2 = arg
    if handler[2] then
        ok = xpcall(_run_handler_protected, _run_handler_error_handler, handler[1], handler[2], fd, events)
    else
        ok = xpcall(_run_handler_protected, _run_handler_error_handler, handler[1], fd, events)
    end
    if ok == false then
        -- Error in handler caught by _run_handler_error_handler.
        -- Remove the handler for the fd as its most likely broken.
        self:remove_handler(fd) 
    end
end

--- Check if IOLoop is currently in a running state.
-- @return true or false.
function ioloop.IOLoop:running() return self._running end

--- Add a callback to the IOLoop.
-- @param callback Function to run on next iteration.
-- @param arg Optional argument to call callback with as first argument.
function ioloop.IOLoop:add_callback(callback, arg)
    self._callbacks[#self._callbacks + 1] = {callback, arg}
end

--- List all callbacks scheduled.
-- @return table with all callbacks.
function ioloop.IOLoop:list_callbacks() return self._callbacks end

local function _run_callback_error_handler(err)
    log.error("[ioloop.lua] Uncaught error in callback: " .. err)
    log.stacktrace(debug.traceback())
end

local function _run_callback_protected(func, arg)
    xpcall(func, _run_callback_error_handler, arg)
end

function ioloop.IOLoop:_run_callback(callback)
    local co = coroutine.create(_run_callback_protected)
    -- callback index 1 = function
    -- callback index 2 = arg
    local rc = self:_resume_coroutine(co, {callback[1], callback[2]})
    return rc
end

function ioloop.IOLoop:_resume_coroutine(co, arg)
    local err, yielded, st
    local arg_t = type(arg)
    if arg_t == "function" then
        -- Function as argument. Call.
        err, yielded = coroutine.resume(co, arg())
    elseif arg_t == "table" then
        -- Callback table.
        err, yielded = coroutine.resume(co, arg[1], arg[2])
    else
        -- Plain resume.
        err, yielded = coroutine.resume(co, arg)
    end
    st = coroutine.status(co)
    if (st == "suspended") then
	local yield_t = type(yielded)
	if instanceOf(coctx.CoroutineContext, yielded) then
            -- Advanced yield scenario.
            -- Use CouroutineContext as key in Coroutine map.
            self._co_ctxs[yielded] = co
            return 1
	elseif (yield_t == "function") then
            -- Schedule coroutine to be run on next iteration with function as result of yield.
	    self._co_cbs[#self._co_cbs + 1] = {co, yielded}
            return 2
        elseif (yield_t == "nil") then
            -- Empty yield. Schedule resume on next iteration.
            self._co_cbs[#self._co_cbs + 1] = {co, 0}
            return 3
	else
            -- Invalid yielded value. Schedule resume of courotine on next iteration with
            -- -1 as result of yield (to represent error).
	    self._co_cbs[#self._co_cbs + 1] = {co, function() return -1 end}
	    log.warning(string.format("[ioloop.lua] Callback yielded with unsupported value, %s.", yield_t))
            return 3
	end	
    end
    return 0
end

--- Finalize a coroutine context.
-- @param coctx A CourtineContext instance.
-- @return True if suscessfull else false.
function ioloop.IOLoop:finalize_coroutine_context(coctx)
    local coroutine = self._co_ctxs[coctx]
    if not coroutine then
        log.warning("[ioloop.lua] Trying to finalize a coroutine context that there are no reference to.")
        return false
    end
    self._co_ctxs[coctx] = nil 
    self:_resume_coroutine(coroutine, coctx:get_coroutine_arguments())
    return true
end

function ioloop.IOLoop:add_timeout(timestamp, callback)
    local i = 1
    while (true) do
        if (self._timeouts[i] == nil) then
            break
        else
            i = i + 1
        end
    end

    self._timeouts[i] = _Timeout:new(timestamp, callback)
    return i
end

function ioloop.IOLoop:remove_timeout(ref)	
    if self._timeouts[ref] then
        self._timeouts[ref] = nil
        return true        
    else
        return false
    end
end

function ioloop.IOLoop:set_interval(msec, callback)
    local i = 1
    while (self._intervals[i] ~= nil) do
        i = i + 1
    end

    self._intervals[i] = _Interval:new(msec, callback)
    return i   
end

function ioloop.IOLoop:clear_interval(ref)
    if (self._intervals[ref]) then
        self._intervals[ref] = nil
        return true
    else
        return false
    end
end

function ioloop.IOLoop:start()
    self._running = true
    while true do
        local poll_timeout = 3600        
        local co_cbs_sz = #self._co_cbs
        if (co_cbs_sz > 0) then
            local co_cbs = self._co_cbs
            self._co_cbs = {}
	    for i = 1, co_cbs_sz do
                if (co_cbs[i] ~= nil) then
                    -- index 1 = coroutine.
                    -- index 2 = yielded function.
                    if (self:_resume_coroutine(co_cbs[i][1], co_cbs[i][2]) ~= 0) then
                        -- Resumed courotine yielded. Adjust timeout.
                        poll_timeout = 0
                    end
                end
	    end
	end
        local callbacks = self._callbacks
        self._callbacks = {}
        for i = 1, #callbacks, 1 do 
            if (self:_run_callback(callbacks[i]) ~= 0) then
                -- Function yielded and has been scheduled for next iteration. Drop timeout.
                poll_timeout = 0
            end
        end
        local timeout_sz = #self._timeouts
        if timeout_sz ~= 0 then
            for i = 1, timeout_sz do
                if (self._timeouts[i] ~= nil) then
                    local time_until_timeout = self._timeouts[i]:timed_out()
                    if (time_until_timeout == 0) then
                        self:_run_callback({self._timeouts[i]:callback()})
                        self._timeouts[i] = nil
                    else
                        if (poll_timeout > time_until_timeout) then
                           poll_timeout = time_until_timeout 
                        end
                    end
                end
	    end
        end
        local intervals_sz = #self._intervals
        if (intervals_sz ~= 0) then
            local time_now = util.gettimeofday()
            for i = 1, intervals_sz do
                if (self._intervals[i] ~= nil) then
                    local timed_out = self._intervals[i]:timed_out(time_now)
                    if (timed_out == 0) then
                        self:_run_callback({self._intervals[i].callback})
                        -- Get current time to protect against building diminishing interval time
                        -- on heavy functions.
                        time_now = util.gettimeofday() 
                        local next_call = self._intervals[i]:set_last_call(time_now)
                        if (next_call < poll_timeout) then
                            poll_timeout = next_call
                        end
                    else
                        if (timed_out < poll_timeout) then
                            -- Adjust timeout to not miss time out.
                            poll_timeout = timed_out
                        end
                    end
                end
            end
        end
        if self._stopped then 
            self.running = false
            self.stopped = false
            break
        end
        if #self._callbacks > 0 then
            -- Callback has been scheduled for next iteration. Drop timeout.
            poll_timeout = 0
        end
        local rc, num, events = self._poll:poll(poll_timeout)
        if rc == 0  then
            num = num - 1 -- Base 0 loop
            for i = 0, num do
                self:_run_handler(events[i].data.fd, events[i].events)
            end
        elseif (rc == -1) then
            log.notice(string.format("[ioloop.lua] poll() returned errno %d", ffi.errno()))
        end
    end
end

function ioloop.IOLoop:close()
    self._running = false
    self._stopped = true
    self._callbacks = {}
    self._handlers = {}
end

_Interval = class("_Interval")
function _Interval:initialize(msec, callback)
    self.interval_msec = msec
    self.callback = callback
    self.next_call = util.gettimeofday() + self.interval_msec
end

function _Interval:timed_out(time_now)
    if (time_now >= self.next_call) then
        return 0
    else
        return self.next_call - time_now
    end
end

function _Interval:set_last_call(time_now)
    self.last_interval = time_now
    self.next_call = time_now + self.interval_msec
    return self.next_call - time_now
end


_Timeout = class('_Timeout')
function _Timeout:initialize(timestamp, callback)
    self._timestamp = timestamp or error('No timestamp given to _Timeout class')
    self._callback = callback or error('No callback given to _Timeout class')
end

function _Timeout:timed_out()
    local current_time = util.gettimeofday()
    if (self._timestamp - current_time <= 0) then
        return 0
    else 
        return self._timestamp - current_time
    end
end

function _Timeout:callback()
    return self._callback
end




_EPoll_FFI = class('_EPoll_FFI')

-- Internal class for epoll-based event loop using the epoll_ffi module.
function _EPoll_FFI:initialize()
    self._epoll_fd = epoll_ffi.epoll_create() -- New epoll, store its fd.
end

function _EPoll_FFI:fileno()
    return self._epoll_fd
end

function _EPoll_FFI:register(file_descriptor, events)
    return epoll_ffi.epoll_ctl(self._epoll_fd, epoll_ffi.EPOLL_CTL_ADD, 
        file_descriptor, events)
end

function _EPoll_FFI:modify(file_descriptor, events)
    return epoll_ffi.epoll_ctl(self._epoll_fd, epoll_ffi.EPOLL_CTL_MOD, 
        file_descriptor, events)
end

function _EPoll_FFI:unregister(file_descriptor)
    return epoll_ffi.epoll_ctl(self._epoll_fd, epoll_ffi.EPOLL_CTL_DEL, 
        file_descriptor, 0)	
end

function _EPoll_FFI:poll(timeout)
    return epoll_ffi.epoll_wait(self._epoll_fd, timeout)
end

return ioloop

