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

local inotify = {}

-- inotify call is available through ffi.C.inotify via cdef.lua.

-- Supported events suitable for MASK parameter of INOTIFY_ADD_WATCH.
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

return inotify
