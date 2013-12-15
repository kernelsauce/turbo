--- Turbo.lua Turbovisor, auto-reload of application on file changes.
--
-- Copyright 2013 John Abrahamsen
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
local bit = require "bit"
local turbo = require "turbo"

--- Parsing arguments for turbovisor
-- @param arg All command line input. Note arg[0] is 'turbovisor', arg[1] is
--    application name; so user-defined argument starts from arg[2]
-- @return a table containing option/value pair, e.g.
--    1. {"watch" = {".", "turbo/examples"}, ......}
local function get_param(arg)
    local arg_tbl = {}
    local arg_shift = false
    for i = 2, #arg, 1 do
        if arg_shift == false then
            if arg[i] == '--watch' or arg[i] == '-w' then
                arg_tbl.watch = arg[i+1]:split(',', nil, nil) -- util.lua
                arg_shift = true
            end
        else
            arg_shift = false
        end
    end
    -- Deal with default parameters
    if arg_tbl.watch == nil then arg_tbl.watch = {'.'} end
    return arg_tbl;
end


--- The turbovisor class is a supervisor for detecting file changes
-- and restart supervised application.
local turbovisor = class("turbovisor", turbo.ioloop.IOLoop)

--- Start supervising.
function turbovisor:supervise()
    -- Get command line parameters
    local arg_tbl = get_param(arg)
    -- Create a new inotify
    local i_fd = turbo.inotify:new()
    -- Create a buffer for reading event in callback handler
    self.buf = ffi.gc(ffi.C.malloc(turbo.fs.PATH_MAX), ffi.C.free)
    -- Initialize ioloop, add inotify handler and watched target
    self:initialize()
    self:add_handler(i_fd, turbo.ioloop.READ, self.restart, self)
    for i, target in pairs(arg_tbl.watch) do
        if turbo.fs.is_dir(target) then
            turbo.inotify:watch_all(target)
        else
            turbo.inotify:watch_file(target)
        end
    end
    -- Parameters for starting application
    local para = ffi.new("const char *[?]", 3)
    para[0] = "luajit"
    para[1] = arg[1]
    para[2] = nil
    self.para = ffi.cast("char *const*", para)
    -- Run application and supervisor
    self.cpid = ffi.C.fork()
    if self.cpid == 0 then
        turbo.inotify:close()
        ffi.C.execvp("luajit", self.para)
        error(ffi.string(ffi.C.strerror(ffi.errno())))
    else
        self:start()
    end
end

--- Callback handler when files changed
-- For now, just restart the only one application
function turbovisor.restart(self, fd, events)
    turbo.log.notice("[turbovisor.lua] Application restarted!")
    local status = ffi.new("int[1]")
    -- Read out event
    ffi.C.read(fd, self.buf, 128);
    -- Restart application
    ffi.C.kill(self.cpid, 9)
    ffi.C.waitpid(self.cpid, status, 0)
    assert(status[0] == 9 or status[0] == 256, "Child process not killed.")
    self.cpid = ffi.C.fork()
    if self.cpid == 0 then
        turbo.inotify:close()
        ffi.C.execvp("luajit", self.para)
        error(ffi.string(ffi.C.strerror(ffi.errno())))
    end
end

return turbovisor
