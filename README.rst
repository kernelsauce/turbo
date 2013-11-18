
.. image:: https://raw.github.com/kernelsauce/turbo/master/doc/design/turbo.png
.. image:: https://api.travis-ci.org/kernelsauce/turbo.png
   :target: http://travis-ci.org/kernelsauce/turbo


Turbo.lua is a toolkit for developing web and networking applications in Lua. It's web functionality is different from all the other Lua HTTP servers out there in that it's modern, fresh, object oriented and easy to modify. Users of the Tornado web server will recognize the API offered pretty quick.
If you do not know Lua then do not fear as its probably one of the easiest languages to learn if you know C, Python or Javascript from before.

Turbo.lua is non-blocking and features a fast web server and a HTTP client. The toolkit is good for REST APIs, traditional HTTP requests and open connections like Websockets and offers a high degree of freedom to do whatever you want, your way.

API Documentation is available at http://turbolua.org/doc/

It's main features and design principles are:

- Simple and intuitive API (much like Tornado).

- Low-level operations is possible if the users wishes that.

- Implemented in pure Lua, so the user can study and modify inner workings without too much effort.

- Being the fastest event driven server.

- Good documentation

- No dependencies, except for LuaJIT the Just-In-Time compiler for Lua.

- Event driven, asynchronous and threadless design

- Small footprint

- SSL support


Installation
------------
Linux distro's are the only OS supported at this point (although adding support for other Unix's is trivial).
Make sure that the latest LuaJIT is installed. Version 2.0 is required, http://luajit.org/. Most package managers have LuaJIT 2.0 available by now.

Installing Turbo.lua is easy. Simply download and run ``make install`` (requires root priv). It is installed in the default Lua 5.1 and LuaJIT 2.0 module directory.

You can specify your own prefix by using ``make install PREFIX=<prefix>``, and you can specify LuaJIT version with a ``LUAJIT_VERSION=2.0.0`` style parameter.

To compile without support for OpenSSL (and SSL connections) use the make option SSL=none.

In essence the toolkit can run from anywere, but is must be able to load the libtffi_wrap.so at run time.
To verify a installation you can try running the applications in the examples folder.

Object oriented Lua
-------------------
Turbo.lua are programmed in a object oriented fashion. There are many ways to do 
object orientation in Lua, this library uses the Middleclass module. Which is documented
at https://github.com/kikito/middleclass/wiki. Middleclass is being used internally in 
Turbo.lua, but is also exposed to the user when inheriting from classes such as the
``turbo.web.RequestHandler`` class. Middleclass is a very lightweight, fast and very
easy to learn if you are used to Python, Java or C++. 

Contributions (important read!)
-----------------------------------------------
Making a event-driven server is hard work! I would really like to get some people working together with me on this project. All contributions are greatly appreciated. Not only in developing the server, but also in documentation, howto's, a official web site and any other field you think YOU can help. The plan is to take on node.js, Tornado and others! If you have any questions then please send them to jhnabrhmsn @ gmail.com .

Dependencies
------------
Turbo Web has dropped support for vanilla Lua because of the decision to drop C modules all together and write all these as LuaJIT FFI modules,
which gives a much better performance. Latest version of LuaJIT can be downloaded here: 
http://luajit.org/

All of the modules of Turbo.lua are made with the class implementation that Middleclass provides.
https://github.com/kikito/middleclass. 

The HTTP parser by Ryan Dahl is used for HTTP parsing. This is built and installed as part of the package.

OpenSSL is required for SSL support. It is possible to run without this feature, and thus not need OpenSSL.

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

http://www.tornadoweb.org/

