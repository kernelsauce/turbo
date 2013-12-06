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
        else arg_shift = false end
    end
    -- Deal with default parameters
    if arg_tbl.watch == nil then arg_tbl.watch = {'.'} end
    return arg_tbl;
end

--- Read out file metadata with a given path
local function stat(path, buf)
    local stat_t = ffi.typeof("struct stat")
    if not buf then buf = stat_t() end
    local ret = ffi.C.syscall(SYS_stat, path, buf)
    if ret == -1 then return error(ffi.string(ffi.C.strerror(ffi.errno()))) end
    return buf
end

--- Check whether a given path is directory
local function is_dir(path)
    buf = stat(path, nil)
    if bit.band(buf.st_mode, S_IFDIR) == S_IFDIR then return true
    else return false end
end


--- The turbovisor class is a turbo supervisor for detecting file changes
-- and restart supervised application.
-- TODO:
--   Monitor multiple application instances
--   Load balancer
--   More control parameters
local turbovisor = class("turbovisor", turbo.ioloop.IOLoop)

-- Watch given directory as well as all its sub-directory
function turbovisor:watch_all(dir)
    local wd = ffi.C.inotify_add_watch(self.fd, dir, IN_MODIFY)
    if wd == -1 then error(ffi.string(ffi.C.strerror(ffi.errno()))) end
    for filename in io.popen('ls "' .. dir .. '"'):lines() do
        local full_path = dir .. '/' .. filename
        if is_dir(full_path) then self:watch_all(full_path) end
    end
end

--- Start supervising applications
function turbovisor:supervise()
    -- Get command line parameters
    local arg_tbl = get_param(arg)
    self.targets = arg_tbl.watch
    -- Create inotify descriptor, only one descriptor for now
    self.fd = ffi.C.inotify_init()
    if self.fd == -1 then error(ffi.string(ffi.C.strerror(ffi.errno()))) end
    -- Create a buffer for reading event in callback handler
    -- hardcode size to 1024, a resonable guess for path length
    self.buf = ffi.gc(ffi.C.malloc(1024), ffi.C.free)
    -- Initialize ioloop, add inotify handler and watched target
    self:initialize()
    self:add_handler(self.fd, turbo.ioloop.READ, self.restart, self)
    for i, target in pairs(self.targets) do
        if is_dir(target) then
            self:watch_all(target)
        else
            local wd = ffi.C.inotify_add_watch(self.fd, target, IN_MODIFY)
            if wd == -1 then error(ffi.string(ffi.C.strerror(ffi.errno()))) end
        end
    end
    -- Parameters for starting application
    local para = ffi.new("const char *[?]", 3)
    para[0] = "luajit"
    para[1] = arg[1]
    para[2] = nil               -- need to pad with NULL
    self.para = ffi.cast("char *const*", para)
    -- Run application and supervisor
    self.cpid = ffi.C.fork()
    if self.cpid == 0 then
        ffi.C.close(self.fd)
        ffi.C.execvp("luajit", self.para)
        error(ffi.string(ffi.C.strerror(ffi.errno())))
    else
        self:start()
    end
end

--- Callback handler when files changed
-- For now, just restart the only one application
function turbovisor.restart(self, fd, events)
    print("Application restarted!")
    -- Read out event
    ffi.C.read(fd, self.buf, 128);
    -- Restart application
    ffi.C.kill(self.cpid, 9)
    ffi.C.wait(nil)             -- clean child process
    self.cpid = ffi.C.fork()
    if self.cpid == 0 then
        ffi.C.close(self.fd)
        ffi.C.execvp("luajit", self.para)
        error(ffi.string(ffi.C.strerror(ffi.errno())))
    end
end

return turbovisor
