.. _apiref:

**************************
Nonsence Web API Reference
**************************

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
~~~~~~~~~~~~~~
The RequestHandler class are implemented so that it must be subclassed to process HTTP requests.

*Subclass and implement any of the following methods to handle the corresponding HTTP method, if a request method that is not implemented is recieved the requester will get a 405 (Not Implemented) status code:*

.. function:: RequestHandler:get()	
	
	HTTP GET reqests handler.

.. function:: RequestHandler:post()

	HTTP POST reqests handler.

.. function:: RequestHandler:head()

	HTTP HEAD reqests handler.

.. function:: RequestHandler:delete()

	HTTP DELETE reqests handler.

.. function:: RequestHandler:put()

	HTTP PUT reqests handler.

.. function:: RequestHandler:options()

	HTTP OPTIONS reqests handler.

All of these methods recieves the arguments from the patterns in the ``nonsence.Web.Application`` handler section.

*Candidates for redefinition:*

.. function:: RequestHandler:on_create(kwargs)

	Reimplement this method if you want to do something straight after the class instance has been created.

.. function:: RequestHandler:prepare()

	Called before each request, independent on the HTTP method used for the request..

.. function:: RequestHandler:on_finish()

	Called after the end of a request. Useful for e.g a cleanup routine.

.. funciton:: RequestHandler:set_default_headers()

	Reimplement this method if you want to set special headers on all requests to the handler.

*Stream modifiying methods:*

.. function:: RequestHandler:write(chunk)

	Writes the given chunk to the output buffer.			
	To write the output to the network, call the ``nonsence.web.RequestHandler:flush()`` method.
	If the given chunk is a Lua table, it will be automatically
	stringifed to JSON. 

.. function:: RequestHandler:finish(chunk)

	Writes the chunk to the output buffer and finishes the HTTP request.
	This method should only be called once in one request.

.. function:: RequestHandler:flush(callback)

	Flushes the current output buffer to the IO stream.
			
	If callback is given it will be run when the buffer has 
	been written to the socket. Note that only one callback flush
	callback can be present per request. Giving a new callback
	before the pending has been run leads to discarding of the
	current pending callback. For HEAD method request the chunk 
	is ignored and only headers are written to the socket.  

.. function:: RequestHandler:clear()
	
	Reset all headers, empty write buffer in a request.

.. function:: RequestHandler:add_header(name, value)

	Add the given name and value pair to the HTTP response headers. Raises error if name already exists.

.. function:: RequestHandler:set_header(name, value)

	Set the given name and value pair of the HTTP response headers. If name exists then the value is overwritten.

.. function:: RequestHandler:get_header(key)

	Returns the current value of the given key in the HTTP response headers. Returns nil if not set.

.. function:: RequestHandler:set_status(code)
	
	Set the status code of the HTTP response headers.

.. function:: RequestHandler:get_status(code)
	
	Get the curent status code of the HTTP response headers.

.. function:: RequestHandler:get_argument(name, default, strip)

	Returns the value of the argument with the given name.
	If default value is not given the argument is considered to be
	required and will result in a 400 Bad Request if the argument
	does not exist. Strip will take away whitespaces at head and tail.

.. function:: RequestHandler:get_arguments(name, strip)

	Returns the values of the argument with the given name. Should be used when you expect multiple arguments values with same name. Strip will take away whitespaces at head and tail where 		applicable.
	
	Returns a empty table if argument does not exist.

.. function:: RequestHandler:redirect(url, permanent)

	Redirect client to another URL. Sets headers and finish request. User can not send data after this. 


HTTPError
~~~~~~~~~
Convinence class for raising errors in ``nonsence.web.RequestHandler`` and return a HTTP status code to the client. The error is caught by the RequestHandler and requests is ended. Usage:

::

	local ExampleHandler = class("ExampleHandler", nonsence.web.RequestHandler)
	function ExampleHandler:get() 
		local param = self:get_argument("some_key")
		if param ~= "expected" then
			error(nonsence.web.HTTPError:new(400))
		else
			self:write("Success!")
		end
	end

.. function:: HTTPError:new(code, message)
	
	Provide code and optional message.


StaticFileHandler
~~~~~~~~~~~~~~~~~
A simple static file handler. All files are cached in memory after initial request. Usage:

::

	local application = nonsence.web.Application:new({ 
		{"/static/(.*)$", nonsence.web.StaticFileHandler, "/var/www/"},
	})


Application
~~~~~~~~~~~
The Application class is a collection of request handler classes that make together up a web application. Example:

::
	
	local application = nonsence.web.Application:new({ 
		{"/static/(.*)$", nonsence.web.StaticFileHandler, "/var/www/"},
		{"/$", ExampleHandler},
		{"/item/(%d*)", ItemHandler}
	})

The constructor of this class takes a "map" of URL patterns and their respective handlers. The third element in the table are optional parameters the handler class might have.
E.g the ``nonsence.web.StaticFileHandler`` class takes the root path for your static handler. This element could also be another table for multiple arguments.

The first element in the table is the URL that the application class matches incoming request with to determine how to serve it. These URLs simply be a URL or a any kind of Lua pattern.
The ItemHandler URL pattern is an example on how to map numbers from URL to your handlers. Pattern encased in parantheses are used as parameters when calling the request methods in your handlers.

A good read on Lua patterns matching can be found here: http://www.wowwiki.com/Pattern_matching.

.. function:: Application:listen(port, address)
	
	 Starts the HTTP server for this application on the given port.

.. function:: Application:set_server_name(name)

	Sets the name of the server. Used in the response headers.

.. function:: Application:get_server_name(name)

	Gets the current name of the server.


nonsence.ioloop
===============
nonsence.ioloop namespace provides a abstracted IO loop, driven typically by Linux Epoll or any other supported poll implemenation. Poll implementations are abstracted and can 
easily be extended with new variants. On Linux Epoll is used and exposed through LuaJIT FFI. The IOLoop class are used by Nonsence Web for event driven services.

A simple event driven server that will write "IOLoop works!" to any opened connection on port 8080 and writes "This is a callback" to stdout after connection has closed:

::

	local ioloop = require('nonsence_ioloop')
	nixio = require('nixio')
	
	local exampleloop = ioloop.IOLoop:new()

	local sock = nixio.socket('inet', 'stream')
	local fd = sock:fileno()
	sock:setblocking(false)
	assert(sock:setsockopt('socket', 'reuseaddr', 1))

	sock:bind(nil, 8080)
	assert(sock:listen(1024))

	function some_handler_that_accepts()
		-- Accept socket connection.
		local new_connection = sock:accept()
		local fd = new_connection:fileno()

		function some_handler_that_reads()
			new_connection:write('IOLoop works!')
			new_connection:close()

			exampleloop:add_callback(function() print "This is a callback" end)
		end	
		exampleloop:add_handler(fd, ioloop.READ, some_handler_that_reads)
	end

	exampleloop:add_handler(fd, ioloop.READ, some_handler_that_accepts)
	exampleloop:start()

IOLoop
~~~~~~
IOLoop is a class responsible for managing I/O events through file descriptors. 
Heavily influenced by ioloop.py in the Tornado web server.
Add file descriptors with :add_handler(fd, listen_to_this, handler).
Handler will be called when event is triggered. Handlers can also be removed from
the I/O Loop with :remove_handler(fd). This will also remove the event from epoll.
You can change the event listened for with :update_handler(fd, listen_to_this).
