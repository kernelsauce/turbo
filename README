-- == Nonsence Asynchronous event based Lua Web server == --

Nonsence Asynchronous event based Lua Web server. Currently being developed as a Lua alternative to 
NodeJS / Tornado and all the other event servers out there

Author: John Abrahamsen < JhnAbrhmsn@gmail.com >

Example usage:

	local nonsence = require('nonsence')

	--[[
		
			Lets make a site root that will show "Hello World!"
			First create new Handler with heritage from RequestHandler
			
	  ]]
	local ExampleHandler = class("ExampleHandler", nonsence.web.RequestHandler)

	--[[

			Then lets define a method for the GET request towards our new 
			request handler instance:
			
	  ]]
	function ExampleHandler:get()
		self:write("Hello world!")
	end

	--[[

			We could also define a method for POST request:
			
	  ]]
	function ExampleHandler:post()
		local posted_value = self:get_argument('somevalue')
		self:write('You posted: ' .. posted_value)
	end

	--[[
		
			Lets also make our application post some JSON.
			Create another new handler instance with heritage.
			Notice how Lua tables are automagically converted to JSON.
	  
	  ]]
	local MyJSONHandler = class("MyJSONHandler", nonsence.web.RequestHandler)

	function MyJSONHandler:get()
		local my_list = { "one", "two", "three" }
		self:write(my_list)
	end

	--[[
		
			Register your handlers with a new application instance.
			The key could be any pattern.
		
	  ]]
	local application = nonsence.web.Application:new({ 
		['/$'] = ExampleHandler,
		['/json'] = MyJSONHandler
	})

	application:listen(8888) -- Listen on port 8888

	nonsence.ioloop.instance():start() -- Start global IO loop.



WARNING: This software package is still under heavy development.


Supported poll implementations at this point:
epoll_ffi (if you are running LuaJIT)
epoll

Planned poll implementation support
kqueue (through LuaJIT FFI and a C module)
select (for Windows developers)

Required C modules when running with Lua or LuaJIT:
	Nixio (https://github.com/Neopallium/nixio)
	Used for socket handling and bit operations (LuaJIT bit operations are used).

Required C modules if you are running Lua (without the JIT):
	Lua Epoll. (https://github.com/Neopallium/lua-epoll)


Many of the modules in the software package are derivatives of the 
Tornado web server. Tornado is also licensed under Apache 2.0 license.
For more details on Tornado please see:

http://www.tornadoweb.org/

Some of the modules in this software package are licensed under
both the MIT and Apache 2.0 License. Modules that are dual licensed 
clearly states this.

Copyright 2011 John Abrahamsen

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.



