.. _apiref:

*************
API Reference
*************

.. highlight:: lua

Preliminaries
=============
All modules are required in nonsence.lua, so it's enough to

::

   local nonsence = require('nonsence')
	
All functionality is placed in the "nonsence" namespace.

Module Version
==============
The Nonsence Web version is of the form *A.B.C*, where *A* is the
major version, *B* is the minor version, and *C* is the micro version.
If the micro version is zero, it's omitted from the version string.

When a new release only fixes bugs and doesn't add new features or
functionality, the micro version is incremented. When new features are
added in a backwards compatible way, the minor version is incremented
and the micro version is set to zero. When there are backwards
incompatible changes, the major version is incremented and others are
set to zero.
	
The following constants specify the current version of the module:

``nonsence.MAJOR_VERSION``, ``nonsence.MINOR_VERSION``, ``nonsence.MICRO_VERSION``
  Numbers specifiying the major, minor and micro versions respectively.

``nonsence.VERSION``
  A string representation of the current version, e.g ``"1.0.0"`` or ``"1.1.0"``.
  
``nonsence.VERSION_HEX``
  A 3-byte hexadecimal representation of the version, e.g.
  ``0x010201`` for version 1.2.1 and ``0x010300`` for version 1.3.

Object oriented Lua
===================
Nonsence Web are programmed in a object oriented fashion. There are many ways to do 
object orientation in Lua, this library uses the Middleclass module. Which is documented
at https://github.com/kikito/middleclass/wiki. Middleclass is being used internally in 
Nonsence Web, but is also exposed to the user when inheriting from classes such as the
``nonsence.web.RequestHandler`` class. Middleclass is a very lightweight, fast and very
easy to learn if you are used to Python, Java or C++.

nonsence.web
============
nonsence.web namespace provides a web framework with asynchronous features that allow it
to scale to large numbers of open connections.

Create a web server that listens to port 8888 and prints the canoncial Hello world on a GET request is
very easy:

.. code-block:: lua
   :linenos:

	local nonsence = require('nonsence')

	local ExampleHandler = class("ExampleHandler", nonsence.web.RequestHandler)
	function ExampleHandler:get() 
		self:write("Hello world!") 
	end

	local application = nonsence.web.Application:new({ 
		{"/$", ExampleHandler}
	})
	application:listen(8888)
	nonsence.ioloop.instance():start()

RequestHandler
==============
The RequestHandler class are implemented so that it must be subclassed to process HTTP requests.

Subclass and implement any of the following methods to handle the corresponding HTTP method:

.. function:: nonsence.web.RequestHandler:get()	
.. function:: nonsence.web.RequestHandler:post()
.. function:: nonsence.web.RequestHandler:head()
.. function:: nonsence.web.RequestHandler:delete()
.. function:: nonsence.web.RequestHandler:put()
.. function:: nonsence.web.RequestHandler:options()

If a request method that is not implemented is recieved the requester will get a 405 (Not Implemented) status code.

	
	