--- Turbo.lua Thread module
--
-- Copyright 2016 John Abrahamsen
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local ffi = require "ffi"
local ioloop = require "turbo.ioloop"
local util = require "turbo.util"
local log = require "turbo.log"
local socket = require "turbo.socket_ffi"
local sockutil = require "turbo.sockutil"
local iostream = require "turbo.iostream"
local coctx = require "turbo.coctx"
require "turbo.cdef"

local thread = {}

thread.Thread = class("Thread")

function thread.Thread:initialize(func, args)
    self.args = args or {}
    self.io_loop = io_loop or ioloop.instance()
    self.running = true
    self._child_func = func
    return self:_run_thread()
end

-- Stop thread and cleanup pipe.
function thread.Thread:stop()
    if self.main_thread then
        -- Send stop message over wire.
        self.pipe:write("STOP\r\n\r\n", function()
            ffi.C.wait(nil)
        end)
    else
        -- Stop thread as child.
        local _self = self
        self.pipe:write("STOP\r\n\r\n", function()
                _self.pipe:close()
                _self.io_loop:close()
                os.remove(self.com_port)
                os.exit(0)
            end
        )
    end
end

--- Called by either main or child thread to send data to each other.
function thread.Thread:send(data)
    self.pipe:write("DATA\r\n\r\n"..data:len().."\r\n\r\n"..data, callback, callback_arg)
end

--- Wait for data to become available from child thread. Takes either a
-- callback or can be yielded directly to IOLoop.
-- @param callback (Function) Optional callback function.
-- @param arg Optional argument for callback. If arg is given then it will
-- be the first argument for the callback and the data will be the second.
-- @return (CoroutineContext) Yieldable object if no callback is given
function thread.Thread:wait_for_data(callback, callback_arg)
    if not callback then
        -- Not using callbacks, return a CoroutineContext instance instead.
        self.ctx = coctx.CoroutineContext(self.io_loop)
        callback = coctx.CoroutineContext.finalize_context
        callback_arg = self.ctx
    end

    if self._waiting_data then
        -- Data is already available.
        local data = self._waiting_data
        self._waiting_data = nil
        self.io_loop:add_callback(function()
            -- Can not run callback directly. CoroutineContext not on
            -- stack if async.task is used.
            if callback_arg then
                if self.ctx then
                    self.ctx:set_arguments(data)
                end
                callback(callback_arg, data)
            else
                callback(data)
            end
        end)
    end
    -- No data available, add callback for later use.
    if self.main_thread then
        self.main_thread_data_cb = callback
        self.main_thread_data_arg = callback_arg
    else
        self.child_thread_data_cb = callback
        self.child_thread_data_arg = callback_arg
    end
    return self.ctx
end

--- Wait for thread to stop running. Takes either a
-- callback or can be yielded directly to IOLoop.
-- @param callback (Function) Optional callback function.
-- @param arg Optional argument for callback. If arg is given then it will
-- be the first argument for the callback and the data will be the second.
-- @return (CoroutineContext) Yieldable object if no callback is given
function thread.Thread:wait_for_finish(callback, callback_arg)
    if not callback then
        self.ctx = coctx.CoroutineContext(self.io_loop)
        callback = coctx.CoroutineContext.finalize_context
        callback_arg = self.ctx
    end
    if not self.running then
        self.io_loop:add_callback(function()
            callback(callback_arg)
        end)
        return
    end
    self.args.exit_callback = callback
    self.args.exit_callback_arg = callback_arg
    return self.ctx
end

--- Wait for thread pipe to be connected. Must be used by main thread
-- before attempting to send data to child. Takes either a
-- callback or can be yielded directly to IOLoop.
-- @param callback (Function) Optional callback function.
-- @param arg Optional argument for callback. If arg is given then it will
-- be the first argument for the callback and the data will be the second.
-- @return (CoroutineContext) Yieldable object if no callback is given
function thread.Thread:wait_for_pipe(callback, callback_arg)
    if not self.main_thread then
        error(
            "Child thread does not need to wait for pipe.")
    end
    if not callback then
        self.ctx = coctx.CoroutineContext(self.io_loop)
        callback = coctx.CoroutineContext.finalize_context
        callback_arg = self.ctx
    end
    if self.connected then
        self.io_loop:add_callback(function()
            callback(callback_arg)
        end)
        return
    end
    self.args.connect_callback = callback
    self.args.connect_callback_arg = callback_arg
    return self.ctx
end

function thread.Thread:_run_thread()
    self.com_port = "/tmp/turbo-com" .. tostring(math.random(1, 9999999))
    local pid = ffi.C.fork()
    if pid < 0 then
        error("Could not create child thread.")
    end
    if pid ~= 0 then
        -- Main thread continue.
        self.main_thread = true
        self.running = true
        self.running_pid = pid
        self:_create_unix_sock()
        return
    end
    -- New thread.
    self.io_loop = ioloop.IOLoop()
    _G.io_loop_instance = self.io_loop
    self.main_thread = false
    self:_connect_to_main_thread()
end

function thread.Thread:_execute_thread_func()
    xpcall(self._child_func, function(err) 
        -- Child thread encountered error.
        -- Cleanup everything and exit thread.
        local thread = tonumber(ffi.C.getpid())
        local trace = debug.traceback(coroutine.running(), err, 2)
        local _str_borders_down = string.rep("▼", 80)
        local _str_borders_up = string.rep("▲", 80)

        log.error(
            string.format(
            "[thread.lua] Error in thread. PID %s is dead.\n%s\n%s\n%s\n",
            thread,
            _str_borders_down,
            trace,
            _str_borders_up))

        self:stop()
    end,
    self)
end

function thread.Thread:_connect_to_main_thread()
    local errno, rc
    local client_address = ffi.new("struct sockaddr_un");

    client_address.sun_family = socket.AF_UNIX;
    ffi.copy(client_address.sun_path, 
        ffi.cast("const char*", self.com_port),
        math.min(self.com_port:len(), ffi.sizeof(client_address.sun_path)))
    self.client_sockfd = ffi.C.socket(socket.AF_UNIX, socket.SOCK_STREAM, 0);
    if self.client_sockfd < 0 then
        errno = ffi.errno()
        log.error(string.format(
            "[thread.lua ]Errno %d. Could not create Unix socket FD. %s",
            errno,
            socket.strerror(errno)))
        os.exit(1)
    end
    rc = ffi.C.connect(self.client_sockfd,
                       ffi.cast("const struct sockaddr *", client_address),
                       ffi.sizeof(client_address))
    if rc ~= 0 then
        -- Main thread probably has not created socket yet. Wait.
        -- Should be done more elegantly...
        ffi.C.sleep(1)
        rc = ffi.C.connect(self.client_sockfd,
                           ffi.cast("const struct sockaddr *", client_address),
                           ffi.sizeof(client_address))
    end
    if rc ~= 0 then
        errno = ffi.errno()
        log.error(string.format(
            "[thread.lua] Errno %d. Could not connect to main thread pipe. %s",
            errno,
            socket.strerror(errno)))
        ffi.C.close(self.client_sockfd)
        os.exit(1)
    end
    self.pipe = iostream.IOStream(self.client_sockfd, self.io_loop)
    self.pipe:read_until("\r\n\r\n",
                                 thread.Thread._main_command_sent,
                                 self)
    self.ready_to_send = true
    self.io_loop:add_callback(thread.Thread._execute_thread_func, self)
    -- Child thread will block here and prevent it from using the other
    -- IOLoop that is in shared memory.
    self.io_loop:start()
end

function thread.Thread:_create_unix_sock()
    local errno, rc, msg

    if not self.main_thread then
        error("Can not open Unix socket on child.")
    end
    local server_address = ffi.new("struct sockaddr_un");
    server_address.sun_family = socket.AF_UNIX;
    ffi.copy(server_address.sun_path, 
        ffi.cast("const char*", self.com_port),
        math.min(self.com_port:len(), ffi.sizeof(server_address.sun_path)))
    self.server_sockfd = ffi.C.socket(socket.AF_UNIX, socket.SOCK_STREAM, 0);
    if self.server_sockfd < 0 then
        error("Could not create Unix socket FD")
    end
    rc, msg = socket.set_nonblock_flag(self.server_sockfd)
    if rc ~= 0 then
       error(msg)
    end

    if ffi.C.bind(self.server_sockfd,
               ffi.cast("struct sockaddr*", server_address),
               ffi.sizeof(server_address)) ~= 0 then
        errno = ffi.errno()
        error(string.format(
            "Errno %d. Could not bind to address. %s",
            errno,
            socket.strerror(errno)))
    end
    if ffi.C.listen(self.server_sockfd, 1) ~= 0 then
        errno = ffi.errno()
        error(string.format(
            "Errno %d. Could not listen to socket fd %d. %s",
            errno,
            fd,
            socket.strerror(errno)))
    end
    sockutil.add_accept_handler(self.server_sockfd,
                                 thread.Thread._child_connects,
                                 self.io_loop,
                                 self)
    self.ready_to_send = true
end

--- Called when child thread connects to main thread.
function thread.Thread:_child_connects(fd)
    local pipe = iostream.IOStream(fd, self.io_loop)
    self.connected = true
    if self.args.connect_callback then
        local callback = self.args.connect_callback
        local arg = self.args.connect_callback_arg
        self.args.connect_callback = nil
        self.args.connect_callback_arg = nil
        self.io_loop:add_callback(function()
            callback(arg)
        end)
    end
    self.pipe = pipe
    pipe:read_until("\r\n\r\n",
                    thread.Thread._child_command_sent,
                    self)
end

--- Called when child thread is sending data over pipe.
function thread.Thread:_child_data_sent(data)
    -- Continue listening for next command.
    self.pipe:read_until("\r\n\r\n",
                         thread.Thread._child_command_sent,
                         self)
    if self.main_thread_data_cb then
        local cb = self.main_thread_data_cb
        local arg = self.main_thread_data_arg
        self.main_thread_data_cb = nil
        self.main_thread_data_arg = nil
        if arg then
            if self.ctx then
                self.ctx:set_arguments(data)
            end
            cb(arg, data)
        else
            cb(data)
        end
    else
        -- No one is waiting for data... Store recieved data until
        -- it can be consumed or discarded.
        self._waiting_data = data
    end
end

--- Called when child thread is sending data over pipe.
function thread.Thread:_child_command_sent(cmd)
    local _self = self
    cmd = cmd:sub(1,4) -- Shave off CRLF
    if cmd == "DATA" then
        self.pipe:read_until("\r\n\r\n", function(num_bytes)
            _self.pipe:read_bytes(tonumber(num_bytes),
                                  thread.Thread._child_data_sent,
                                  _self)
        end)
    elseif cmd == "STOP" then
        if _self.args.exit_callback then
            local cb = _self.args.exit_callback
            local arg = _self.args.exit_callback_arg
            _self.io_loop:add_callback(function()
                if arg then
                    cb(arg, _self)
                else
                    cb(_self)
                end
            end)
            _self.pipe:close()
            ffi.C.close(_self.server_sockfd)
            self.running = false
        end
        -- Collect thread.
        ffi.C.wait(nil)
    end
end

--- Called when main thread is sending data over pipe.
function thread.Thread:_main_data_sent(data)
    local cb = self.child_thread_data_cb
    local arg = self.child_thread_data_arg
    self.child_thread_data_cb = nil
    self.child_thread_data_arg = nil
    if arg then
        if self.ctx then
            self.ctx:set_arguments(data)
        end
        cb(arg, data)
    else
        cb(data)
    end
end

--- Called when main thread is sending data over pipe.
function thread.Thread:_main_command_sent(cmd)
    local _self = self
    cmd = cmd:sub(1,4) -- Shave off CRLF
    if cmd == "DATA" then
        self.pipe:read_until("\r\n\r\n", function(num_bytes)
            _self.pipe:read_bytes(tonumber(num_bytes),
                                  thread.Thread._main_data_sent,
                                  _self)
        end)
    elseif cmd == "STOP" then
        self.pipe:close()
        self.io_loop:close()
        os.exit(0)
    end
end

return thread
