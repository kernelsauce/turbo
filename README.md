.. image:: https://raw.github.com/kernelsauce/turbo/master/doc/design/turbo.png

Turbo.lua is a Lua module / toolkit (whatever) for developing web applications in Lua. It is different from all the other Lua HTTP servers out there in that it's modern, fresh, object oriented and easy to modify.
It is written in pure Lua, there are no Lua C modules instead it uses the LuaJIT FFI to do socket and event handling. Users of the Tornado web server will recognize the API offered pretty quick.
If you do not know Lua then do not fear as its probably one of the easiest languages to learn if you know C, Python or Javascript from before.

Turbo.lua is non-blocking and a features a extremely fast light weight web server. The framework is good for REST APIs, traditional HTTP requests and open connections like Websockets requires because of its combination of the raw
power of LuaJIT and its event driven nature.

What sets Turbo.lua apart from the other evented driven servers out there, is that it is the fastest, most scalable and has the smallest footprint of them all. This is thanks to the excellent work done on LuaJIT.

Its main features and design principles are:

- Simple and intuitive API (much like Tornado)

- Good documentation

- No dependencies, except for the Lua interpreter.

- Event driven, asynchronous and threadless design

- Extremely fast with LuaJIT

- Written completely in pure Lua

- Linux Epoll support

- Small footprint

- SSL Support

Installation
------------
Linux distro's are the only OS supported at this point (although adding support for other Unix's is trivial).
Make sure that the latest LuaJIT is installed. Version 2.0 is required, http://luajit.org/. Most package managers have LuaJIT 2.0 available by now.

Installing Turbo.lua is easy. Simply download and run make install (requires root priv). It is installed in the Lua 5.1 and LuaHIT 2.0 module directory. You can specify your own prefix by using make install PREFIX=<prefix>, and you can specify LuaJIT version with LUAJIT_VERSION=2.0.0 parameters. To verify installation you can try running the applications in the examples folder.

Object oriented Lua
-------------------
Turbo.lua are programmed in a object oriented fashion. There are many ways to do 
object orientation in Lua, this library uses the Middleclass module. Which is documented
at https://github.com/kikito/middleclass/wiki. Middleclass is being used internally in 
Turbo Web, but is also exposed to the user when inheriting from classes such as the
``turbo.web.RequestHandler`` class. Middleclass is a very lightweight, fast and very
easy to learn if you are used to Python, Java or C++. 

Contributions (important read!)
-----------------------------------------------
Making a event-driven server is hard work! I would really like to get some people working together with me on this project. All contributions are greatly appreciated. Not only in developing the server, but also in documentation, howto's, a official web site and any other field you think YOU can help. The plan is to take on node.js, Tornado and others! If you have any questions then please send them to jhnabrhmsn @ gmail.com .

Dependencies
------------
Turbo Web has dropped support for vanilla Lua because of the decision to drop C modules all together and write all these as LuaJIT FFI modules,
which gives a much better performance. Latest version of LuaJIT can be downloaded here: http://luajit.org/
At

All of the modules of Turbo Web are made with the class implementation that Middleclass provides <https://github.com/kikito/middleclass>. 

The HTTP parser by Ryan Dahl is used for HTTP parsing. This is built and installed as part of the package.

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

