
.. image:: _static/turbo.png

This is the documentation for Turbo.lua version 1.0.0.

Introduction
------------
Turbo.lua is a Lua module / toolkit (whatever) for developing web applications in Lua. It is different from all the other Lua HTTP servers out there in that it's modern, fresh, object oriented and easy to modify. No pun intended!
It is written in pure Lua, there are no Lua C modules instead it uses the LuaJIT FFI to do socket and event handling. Users of the Tornado web server will recognize the API offered pretty quick.
If you do not know Lua then do not fear as its probably one of the easiest languages to learn if you know C, Python or Javascript from before.

Turbo.lua is non-blocking and a features a extremely fast light weight web server. The framework is good for REST APIs, traditional HTTP requests and open connections like Websockets because of its event driven nature.

What sets Turbo.lua apart from the other evented driven servers out there, is that it is the fastest, most scalable and has the smallest footprint of them all. This is thanks to the excellent work done on LuaJIT.

Its main features and design principles are:

- Simple and intuitive API (much like Tornado)

- Good documentation

- No dependencies, except for LuaJIT the Just-In-Time compiler for Lua.

- Event driven, asynchronous and threadless design

- Extremely fast with LuaJIT

- Written completely in pure Lua

- Linux Epoll support

- Small footprint


Installation
------------
Linux distro's are the only OS supported at this point (although adding support for other Unix's is trivial).
Make sure that the latest LuaJIT is installed. Version 2.0 is required, http://luajit.org/. Most package managers have LuaJIT 2.0 available by now.

Installing Turbo.lua is easy. Simply download and run ``make install`` (requires root priv). It is installed in the default Lua 5.1 and LuaJIT 2.0 module directory.

You can specify your own prefix by using ``make install PREFIX=<prefix>``, and you can specify LuaJIT version with a ``LUAJIT_VERSION=2.0.0`` style parameter.

To compile without support for OpenSSL (and SSL connections) use ``make install SSL=none``.

In essence the toolkit can run from anywere, but is must be able to load the libtffi_wrap.so at run time.
To verify a installation you can try running the applications in the examples folder.


Object oriented Lua
-------------------
Turbo.lua are programmed in a object oriented fashion. There are many ways to do 
object orientation in Lua, this library uses the Middleclass module. Which is documented
at https://github.com/kikito/middleclass/wiki. Middleclass is being used internally in 
Turbo Web, but is also exposed to the user when inheriting from classes such as the
``turbo.web.RequestHandler`` class. Middleclass is a very lightweight, fast and very
easy to learn if you are used to Python, Java or C++. 

Turbo.lua is licensed under the Apache License, version 2.0. See LICENSE in the source code for more details.


Tutorials
---------

.. toctree::
    :maxdepth: 3

    get_started


API documentation
-----------------

.. toctree::
   :maxdepth: 3

   apiref
   web
   async
   ioloop
   iostream
   httputil
   httpserver
   tcpserver
   structs
   hash
   util
   sockutil
   escape
   log
