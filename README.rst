.. image:: https://raw.github.com/kernelsauce/turbo/master/doc/design/turbo.png
   :target: http://turbolua.org

Turbo is a framework built for LuaJIT 2 to simplify the task of building fast and scalable network applications. It uses a event-driven, non-blocking, no thread design to deliver excellent performance and minimal footprint to high-load applications while also providing excellent support for embedded uses. The toolkit can be used for HTTP REST API's, traditional dynamic web pages through templating, open connections like WebSockets, or just as high level building blocks for native speed network applications.

First and foremost the framework is aimed at the HTTP(S) protocol. This means web developers and HTTP API developers are the first class citizens. But the framework contains generic nuts and bolts such as; a I/O loop, IO Stream classes, customizeable TCP (with SSL) server classes giving it value for everyone doing any kind of high performance network application. It will also speak directly to your exising C libraries, and happily also create native C struct's for the ultimate memory and CPU performance.

Keep in mind that running this with LuaJIT provides you with roughly the speed of compiled C code with only a fraction of the development time. Perfect for small devices running cheap CPU's on battery power as well as your pay per use Amazon cluster.

LuaJIT 2 is REQUIRED, PUC-RIO Lua is unsupported.

API Documentation is available at http://turbolua.org/doc/

It's main features and design principles are:

- Simple and intuitive API (much like Tornado).

- Low-level operations is possible if the users wishes that.

- Implemented in straight Lua and LuaJIT FFI, so the user can study and modify inner workings without too much effort.

- Good documentation

- Event driven, asynchronous and threadless design

- Small footprint

- SSL support (requires OpenSSL or axTLS)

.. image:: https://api.travis-ci.org/kernelsauce/turbo.png
   :target: http://travis-ci.org/kernelsauce/turbo

Supported Architectures
-----------------------
x86, x64, ARM, PPC

Installation
------------

You can use LuaRocks to install Turbo.

``luarocks install turbo``

If installation fails make sure that you have these required pacakages:

``apt-get install luajit luarocks git build-essential libssl-dev``


Linux distro's are the only OS supported at this point (although adding support for other Unix's is trivial).
Make sure that the latest LuaJIT is installed. Version 2.0 is required, http://luajit.org/. Most package managers have LuaJIT 2.0 available by now.

Turbo.lua can also be installed by the included Makefile. Simply download and run ``make install`` (requires root priv). It is installed in the default Lua 5.1 and LuaJIT 2.0 module directory.

You can specify your own prefix by using ``make install PREFIX=<prefix>``, and you can specify LuaJIT version with a ``LUAJIT_VERSION=2.0.0`` style parameter.

To compile without support for OpenSSL (and SSL connections) use the make option SSL=none.
To compile with axTLS support instead of OpenSSL use the make option SSL=axTLS.

In essence the toolkit can run from anywere, but is must be able to load the libtffi_wrap.so at run time.
To verify a installation you can try running the applications in the examples folder.

Dependencies
------------
All of the modules of Turbo.lua are made with the class implementation that Middleclass provides.
https://github.com/kikito/middleclass. 

The HTTP parser by Ryan Dahl is used for HTTP parsing. This is built and installed as part of the package.

OpenSSL or axTLS is required for SSL support. It is possible to run without this feature, and thus not need an SSL library.

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

