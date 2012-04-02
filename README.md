Nonsence
========

<b>Asynchronous event based Lua Web server</b>

Currently being developed as a Lua alternative to NodeJS / Tornado and all the other event servers out there. 

Author: John Abrahamsen <JhnAbrhmsn@gmail.com> with inspiration from the Tornado web server.

<b>Making a Hello World server:</b>

	local nonsence = require('nonsence')

	local ExampleHandler = class("ExampleHandler", nonsence.web.RequestHandler)

	function ExampleHandler:get()
		self:write("Hello world!")
	end

	function ExampleHandler:post()
		local posted_value = self:get_argument('somevalue')
		self:write('You posted: ' .. posted_value)
	end

	local application = nonsence.web.Application:new({ 
		['/$'] = ExampleHandler
	})

	application:listen(8888) -- Listen on port 8888

	nonsence.ioloop.instance():start() -- Start global IO loop.

Why did I do this?
---
Because Lua is a under rated, compact, easy to learn, FAST, easy to extend and easy to embed language. Lua deserves a proper scalable non-blocking Web server.

With LuaJIT we have a jitted Lua interpreter that makes Lua the fastest dynamic language out there. Why not reap the benefits of this amazing interpreter for the Web?

Performance
-----------
So all this bragging, but nothing to back it up?!
Running:

	ab -n 100000 -c 500 127.0.0.1:8888/

on my Lenovo Thinkpad W510 yields these numbers:

* Nonsence w/ LuaJIT (with hello world app): 8158 requests/sec
* Nonsence w/ Lua (with hello world app): 5848 requests/sec
* Tornado (with demo hello world app): 1939 requests/sec

Usage
-----

<big>WARNING: This software package is still under heavy development. Basic functionality is in place, there is no documentation for web.lua yet!</big>

All of the modules of Nonsence are made with the class implementation that Middleclass provides <https://github.com/kikito/middleclass>. 

<u>Supported poll implementations at this point:</u>

* epoll_ffi (if you are running LuaJIT)
* epoll

<u>Planned poll implementation support</u>

* kqueue (through LuaJIT FFI and a C module)
* select (for Windows developers)

<u>Required C modules when running with Lua or LuaJIT:</u>

* Nixio <https://github.com/Neopallium/nixio>: Used for socket handling and bit operations (LuaJIT bit operations are used).

<u>Required C modules if you are running Lua (without the JIT):</u>

* Lua Epoll. <https://github.com/Neopallium/lua-epoll>

License
-------

Many of the modules in the software package are derivatives of the 
Tornado web server. Tornado is also licensed under Apache 2.0 license.
For more details on Tornado please see:

<http://www.tornadoweb.org/>

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



