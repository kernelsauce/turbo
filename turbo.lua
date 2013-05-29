--[[ Turbo Asynchronous event based Lua Web server.

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

local turbo = {}  -- turbo namespace.

turbo.MAJOR_VERSION = 1
turbo.MINOR_VERSION = 0
turbo.MICRO_VERSION = 0
turbo.VERSION_HEX = 0x010000

if turbo.MICRO_VERSION then
	turbo.VERSION = string.format("%d.%d.%d", turbo.MAJOR_VERSION, turbo.MINOR_VERSION, turbo.MICRO_VERSION)
else
	turbo.VERSION = string.format("%d.%d", turbo.MAJOR_VERSION, turbo.MINOR_VERSION)
end

turbo.log =             require "turbo.log"
turbo.ioloop =          require "turbo.ioloop"
turbo.escape =          require "turbo.escape"
turbo.httputil =        require "turbo.httputil"
turbo.httpserver =      require "turbo.httpserver"
turbo.iostream =        require "turbo.iostream"
turbo.async =           require "turbo.async"
turbo.web =             require "turbo.web"
turbo.util =            require "turbo.util"
turbo.signal =          require "turbo.signal"
turbo.socket =          require "turbo.socket_ffi"
turbo.structs =         {}
turbo.structs.deque =   require "turbo.structs.deque"


return turbo
