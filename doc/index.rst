
.. image:: _static/turbo.png

Introduction
------------
Turbo.lua is a framework built for LuaJIT 2 to simplify the task of building fast and scalable network applications. It uses a event-driven, non-blocking, no thread design to deliver excellent performance and minimal footprint to high-load applications while also providing excellent support for embedded uses. The toolkit can be used for HTTP REST API's, traditional dynamic web pages through templating, open connections like WebSockets, or just as high level building blocks for native speed network applications.

First and foremost the framework is aimed at the HTTP(S) protocol. This means web developers and HTTP API developers are the first class citizens. But the framework contains generic nuts and bolts such as; a I/O loop, IO Stream classes, customizeable TCP (with SSL) server classes giving it value for everyone doing any kind of high performance network application. It will also speak directly to your exising C libraries, and happily also create native C struct's for the ultimate memory and CPU performance.

Keep in mind that running this with LuaJIT provides you with roughly the speed of compiled C code with only a fraction of the development time. Perfect for small devices running cheap CPU's on battery power as well as your pay per use Amazon cluster.

LuaJIT 2 is REQUIRED, PUC-RIO Lua is unsupported.

API Documentation is available at http://turbolua.org/doc/

It's main features and design principles are:

- Simple and intuitive API (much like Tornado).

- Low-level operations is possible if the users wishes that.

- Implemented in straight Lua and LuaJIT FFI on Linux, so the user can study and modify inner workings without too much effort. The Windows implementation uses some Lua modules to make compability possible.

- Good documentation

- Event driven, asynchronous and threadless design

- Small footprint

- SSL support (requires OpenSSL or LuaSec module for Windows)

Travis Linux CI

.. image:: https://api.travis-ci.org/kernelsauce/turbo.png
   :target: http://travis-ci.org/kernelsauce/turbo

Appveyor Windows CI

.. image:: https://api.travis-ci.org/kernelsauce/turbo.png
   :target: https://ci.appveyor.com/project/kernelsauce/turbo

Supported Architectures
-----------------------
x86, x64, ARM, PPC, MIPSEL

Supported Operating Systems
---------------------------
Linux distros (x86, x64) and Windows x64. Possibly others using LuaSocket, but not tested or supported.

Installation
------------

You can use LuaRocks to install Turbo on Linux.

``luarocks install turbo``

If installation fails make sure that you have these required pacakages:

``apt-get install luajit luarocks git build-essential libssl-dev``

For Windows use the included install.bat file or one line downloader:

``powershell -command "& { iwr https://raw.githubusercontent.com/kernelsauce/turbo/luasocket/install.bat OutFile t.bat }" && t.bat``

This will install all dependencies: Visual Studio, git, mingw, gnuwin, openssl using Chocolatey. LuaJIT, the LuaRocks package manager and Turbo will be installed at C:\\turbo.lua. It will also install LuaSocket and LuaFileSystem with LuaRocks. The Windows environment will be ready to use upon success.

Try: ``luajit C:\turbo.lua\src\turbo\examples\helloworld.lua``

If any of the .dll or. so's are placed at non-default location then use environment variables to point to the correct place:

E.g:
``SET TURBO_LIBTFFI=C:\turbo.lua\src\turbo\libtffi_wrap.dll`` and
``SET TURBO_LIBSSL=C:\Program Files\OpenSSL\libeay32.dll``

Applies for Linux only:

Turbo.lua can also be installed by the included Makefile. Simply download and run ``make install`` (requires root priv). It is installed in the default Lua 5.1 and LuaJIT 2.0 module directory.

You can specify your own prefix by using ``make install PREFIX=<prefix>``, and you can specify LuaJIT version with a ``LUAJIT_VERSION=2.0.0`` style parameter.

To compile without support for OpenSSL (and SSL connections) use the make option SSL=none.
To compile with axTLS support instead of OpenSSL use the make option SSL=axTLS.

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
    modules


API documentation
-----------------

.. toctree::
   :maxdepth: 3

   apiref
   web
   websocket
   iosimple
   iostream
   ioloop
   async
   escape
   turbovisor
   httputil
   httpserver
   tcpserver
   structs
   hash
   util
   sockutil
   log
