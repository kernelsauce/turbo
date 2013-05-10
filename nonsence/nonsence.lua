--[[ Nonsence Asynchronous event based Lua Web server.

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

local nonsence = {}  -- nonsence namespace.

nonsence.MAJOR_VERSION = 1
nonsence.MINOR_VERSION = 0
nonsence.MICRO_VERSION = 0
nonsence.VERSION_HEX = 0x010000

if nonsence.MICRO_VERSION then
	nonsence.VERSION = string.format("%d.%d.%d", nonsence.MAJOR_VERSION, nonsence.MINOR_VERSION, nonsence.MICRO_VERSION)
else
	nonsence.VERSION = string.format("%d.%d", nonsence.MAJOR_VERSION, nonsence.MINOR_VERSION)
end

nonsence.log = require "log"
nonsence.ioloop = require "ioloop"
nonsence.escape = require "escape"
nonsence.httputil = require "httputil"
nonsence.httpserver = require "httpserver"
nonsence.iostream = require "iostream"
nonsence.deque = require "deque"
nonsence.web = require "web"
nonsence.util = require "util"
nonsence.signal = require "signal"
nonsence.socket = require "socket_ffi"
_G.dump = nonsence.log.dump
_G.join = nonsence.util.join

return nonsence
