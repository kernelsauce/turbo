Nonsence Web 
============

<b>Asynchronous event based Lua Web server with inspiration from the Tornado web server.</b>

<b>Making a Hello World server:</b>

        local nonsence = require('nonsence')


        -- Create class with RequestHandler heritage.
        local ExampleHandler = class("ExampleHandler", nonsence.web.RequestHandler)
        function ExampleHandler:get()
                -- Echo hello world on HTTP GET!
                self:write("Hello world!")
        end
        
        function ExampleHandler:post()
                -- Echo post value example on HTTP POST. Or give a bad request if the argument is not set.
                local posted_value = self:get_argument('somevalue')
                self:write('You posted: ' .. posted_value)
        end
        
        
        local MyJSONHandler = class("MyJSONHandler", nonsence.web.RequestHandler)
        function MyJSONHandler:get()
                -- Pass table to JSON stringify it.  
                local my_list = { "one", "two", "three" }
                self:write(my_list)
        end
        
         
        local application = nonsence.web.Application:new({
                -- Nonsence serves static files as well!
                {"/static/(.*)$", nonsence.web.StaticFileHandler, "/var/www/"},
                -- Register handlers
                {"/$", ExampleHandler},
                {"/json", MyJSONHandler},
        })
        
        application:listen(8888)
        nonsence.ioloop.instance():start()

Introduction
------------
Nonsence Web is a Lua module / toolkit (whatever) for developing web apps in Lua. It is different from all the other
Lua HTTP servers out there in that it's modern, fresh, object oriented and easy to modify, and probably the fastest scriptable Web server
available.

Its main features and design principles are:

- Simple and intuitive API

- Good documentation

- Few dependencies

- Event driven, asynchronous and threadless design

- Extremely fast with LuaJIT

- Written completely in pure Lua with some LuaJIT FFI modules.

- Linux Epoll support

- Small footprint

Nonsence Web is licensed under the Apache License, version 2.0. See LICENSE in the source code for more details. Some modules 
are dual licensed with both MIT and Apache 2.0 licenses.

Dependencies
------------
Nonsence Web has dropped support for vanilla Lua because of the decision to drop C modules all together and write all these as LuaJIT FFI modules,
which gives a much better performance. Latest version of LuaJIT can be downloaded here: http://luajit.org/

All of the modules of Nonsence Web are made with the class implementation that Middleclass provides <https://github.com/kikito/middleclass>. 


Performance
-----------
So all this bragging, but nothing to back it up?!
Running:

	ab -n 100000 -c 500 127.0.0.1:8888/

on my Lenovo Thinkpad W510 yields these numbers:

* Nonsence w/ LuaJIT (with hello world app): 8158 requests/sec
* Nonsence w/ Lua (with hello world app): 5848 requests/sec
* Tornado (with demo hello world app): 1939 requests/sec

Don't believe me? Try it yourself and see :).



License
-------
Copyright 2011, 2012 and 2013 John Abrahamsen

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Many of the modules in the software package are derivatives of the 
Tornado web server. Tornado is also licensed under Apache 2.0 license.
For more details on Tornado please see:

<http://www.tornadoweb.org/>

Some of the modules in this software package are licensed under
both the MIT and Apache 2.0 License. Modules that are dual licensed 
clearly states this in the file header.

