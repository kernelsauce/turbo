--- Turbo.lua inotify Module
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
local fs  = require "turbo.fs"
local log = require "turbo.log"
local util = require "turbo.util"
local ioloop  = require "turbo.ioloop"
--local syscall = require "turbo.syscall"

local inotify = {}

-- inotify call is available through ffi.C.inotify via cdef.lua.

--- Supported events suitable for MASK parameter of INOTIFY_ADD_WATCH.
inotify.IN_ACCESS        = 0x00000001     -- File was accessed.
inotify.IN_MODIFY        = 0x00000002     -- File was modified.
inotify.IN_ATTRIB        = 0x00000004     -- Metadata changed.
inotify.IN_CLOSE_WRITE   = 0x00000008     -- Writtable file was closed.
inotify.IN_CLOSE_NOWRITE = 0x00000010     -- Unwrittable file closed.
inotify.IN_CLOSE         = bit.bor (inotify.IN_CLOSE_WRITE,
									inotify.IN_CLOSE_NOWRITE) -- Close.
inotify.IN_OPEN          = 0x00000020     -- File was opened.
inotify.IN_MOVED_FROM    = 0x00000040     -- File was moved from X.
inotify.IN_MOVED_TO      = 0x00000080     -- File was moved to Y.
inotify.IN_MOVE          = bit.bor (inotify.IN_MOVED_FROM,
									inotify.IN_MOVED_TO) -- Moves.
inotify.IN_CREATE        = 0x00000100     -- Subfile was created.
inotify.IN_DELETE        = 0x00000200     -- Subfile was deleted.
inotify.IN_DELETE_SELF   = 0x00000400     -- Self was deleted.
inotify.IN_MOVE_SELF     = 0x00000800     -- Self was moved.

--- Create a new inotify instance
function inotify:new()
    self.fd = ffi.C.inotify_init()
    self.wd2name = {}
    if self.fd == -1 then
        error(ffi.string(ffi.C.strerror(ffi.errno())))
    end
    return self.fd
end

--- Watch on a given file
-- @param file_path must be a valid relative path or absolute path
-- @return true if watch successfully, false otherwise
function inotify:watch_file(file_path)
    if fs.is_file(file_path) then
        local wd = ffi.C.inotify_add_watch(self.fd, file_path, self.IN_MODIFY)
        if wd == -1 then error(ffi.string(ffi.C.strerror(ffi.errno()))) end
        self.wd2name[wd] = file_path
        return true
    else
        return false
    end
end

--- Watch on a given directory, not its sub-directories
-- @param dir_path must be a valid relative path or absolute path
-- @return true if watch successfully, false otherwise
function inotify:watch_dir(dir_path)
    if fs.is_dir(dir_path) then
        local wd = ffi.C.inotify_add_watch(self.fd, file_path, self.IN_MODIFY)
        if wd == -1 then error(ffi.string(ffi.C.strerror(ffi.errno()))) end
        self.wd2name[wd] = dir_path
        return true
    else
        return false
    end
end

--- Watch given directory as well as all its sub-directories.
-- @param path must be a valid relative path or absolute path
-- @param ignore an optional table of directories to ignore
function inotify:watch_all(path, ignore)
    -- Take care of ignored files
    if not ignore or not util.is_in(path, ignore) then
        if fs.is_dir(path) then
            local wd = ffi.C.inotify_add_watch(self.fd, path, self.IN_MODIFY)
            if wd == -1 then error(ffi.string(ffi.C.strerror(ffi.errno()))) end
            self.wd2name[wd] = path
        end
        local ls = io.popen('ls "' .. path .. '"')
        for filename in ls:lines() do
            local full_path = path .. '/' .. filename
            if path == '.' then full_path = filename end -- pass './'
            if fs.is_dir(full_path) then
                self:watch_all(full_path, ignore)
            end
        end
        ls:close()
    end
end

--- Return file name from corresponding file descriptor, for
-- currently watched file
-- @param wd file descriptor
function inotify:get_watched_file(wd)
    return self.wd2name[wd]
end

--- Return all file names of currently watched files
function inotify:get_watched_files()
    return self.wd2name
end

--- Close inotify
function inotify:close()
    ffi.C.close(self.fd)
end

return inotify
