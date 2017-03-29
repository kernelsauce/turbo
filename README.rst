.. image:: https://raw.github.com/kernelsauce/turbo/master/doc/design/turbo.png
   :target: http://turbolua.org

Turbo is a framework built for LuaJIT 2 to simplify the task of building fast and scalable network applications. It uses a event-driven, non-blocking, no thread design to deliver excellent performance and minimal footprint to high-load applications while also providing excellent support for embedded uses. The toolkit can be used for HTTP REST API's, traditional dynamic web pages through templating, open connections like WebSockets, or just as high level building blocks for native speed network applications.

First and foremost the framework is aimed at the HTTP(S) protocol. This means web developers and HTTP API developers are the first class citizens. But the framework contains generic nuts and bolts such as; a I/O loop, IO Stream classes, customizeable TCP (with SSL) server classes giving it value for everyone doing any kind of high performance network application. It will also speak directly to your exising C libraries, and happily also create native C struct's for the ultimate memory and CPU performance.

Keep in mind that running this with LuaJIT provides you with roughly the speed of compiled C code with only a fraction of the development time. Perfect for small devices running cheap CPU's on battery power as well as your pay per use Amazon cluster.

LuaJIT 2 is REQUIRED, PUC-RIO Lua is unsupported.

API Documentation is available at http://turbolua.org, or it can be built from source with ``make html`` from /doc in the source tree.

It's main features and design principles are:

- Simple and intuitive API (much like Tornado).

- Low-level operations is possible if the users wishes that.

- Implemented in straight Lua and LuaJIT FFI on Linux, so the user can study and modify inner workings without too much effort. The Windows implementation uses some Lua modules to make compability possible.

- Good documentation

- Event driven, asynchronous and threadless design

- Small footprint

- SSL support (requires OpenSSL or LuaSec module for Windows)

.. image:: https://api.travis-ci.org/kernelsauce/turbo.png
   :target: http://travis-ci.org/kernelsauce/turbo

Supported Architectures
-----------------------
x86, x64, ARM, PPC, MIPSEL

Supported Operating Systems
---------------------------
Linux distros (x86, x64), OSX (Intel-based) and Windows x64. Possibly others using LuaSocket, but not tested or supported.

Installation
------------

You can use LuaRocks to install Turbo on Linux.

``luarocks install turbo``

If installation fails make sure that you have these required pacakages:

``apt-get install luajit luarocks git build-essential libssl-dev``

For Windows run the included install.bat file.
This will install all dependencies: Visual Studio, git, mingw, gnuwin, openssl using Chocolatey. LuaJIT, the LuaRocks package manager and Turbo will be installed at C:\\turbo.lua. It will also install LuaSocket and LuaFileSystem with LuaRocks. The Windows environment will be ready to use upon success.

Try: ``luajit C:\turbo.lua\src\turbo\examples\helloworld.lua``

If any of the .dll or. so's are placed at non-default location then use environment variables to point to the correct place:

E.g:
``SET TURBO_LIBTFFI=C:\turbo.lua\src\turbo\libtffi_wrap.dll`` and
``SET TURBO_LIBSSL=C:\Program Files\OpenSSL\libeay32.dll``

Applies for Linux based OS and OSX only:

Turbo.lua can also be installed by the included Makefile. Simply download and run ``make install`` (requires root priv). It is installed in the default Lua 5.1 and LuaJIT 2.0 module directory.

You can specify your own prefix by using ``make install PREFIX=<prefix>``, and you can specify LuaJIT version with a ``LUAJIT_VERSION=2.0.0`` style parameter.

To compile without support for OpenSSL (and SSL connections) use the make option SSL=none.
To compile with axTLS support instead of OpenSSL use the make option SSL=axTLS. If you
want to install the framework in a bytecode form use: ``make bcodeinstall``

In essence the toolkit can run from anywere, but is must be able to load the libtffi_wrap.so at run time.
To verify a installation you can try running the applications in the examples folder.

Packaging
---------
The included Makefile supports packaging the current tree as a versioned tar.gz file.
This file will include only the neccessary bits and pieces for Turbo to run. The files
will be built as bytecode (luajit -b -g) with debug info. This reduces size drastically.
Suitable for embedded devices with limited storage... It also reduces the startup time.

Use ``make package``.

this results in a turbo.x.x.x.tar.gz file and a package/ directory being created.

Dependencies
------------
All of the modules of Turbo.lua are made with the class implementation that Middleclass provides.
https://github.com/kikito/middleclass.

The HTTP parser by Ryan Dahl is used for HTTP parsing. This is built and installed as part of the package.

OpenSSL is required for SSL support. It is possible to run without this feature, and thus not need an SSL library.

License
-------
Copyright 2011 - 2016 John Abrahamsen

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

