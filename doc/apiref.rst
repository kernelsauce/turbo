.. _apiref:

**************************
Turbo Web API Reference
**************************

.. highlight:: lua

Preliminaries
=============
All modules are required in turbo.lua, so it's enough to

::

   local turbo = require('turbo')
	
All functionality is placed in the "turbo" namespace.

Module Version
==============
The Turbo Web version is of the form *A.B.C*, where *A* is the
major version, *B* is the minor version, and *C* is the micro version.
If the micro version is zero, it's omitted from the version string.

When a new release only fixes bugs and doesn't add new features or
functionality, the micro version is incremented. When new features are
added in a backwards compatible way, the minor version is incremented
and the micro version is set to zero. When there are backwards
incompatible changes, the major version is incremented and others are
set to zero.
	
The following constants specify the current version of the module:

``turbo.MAJOR_VERSION``, ``turbo.MINOR_VERSION``, ``turbo.MICRO_VERSION``
  Numbers specifiying the major, minor and micro versions respectively.

``turbo.VERSION``
  A string representation of the current version, e.g ``"1.0.0"`` or ``"1.1.0"``.
  
``turbo.VERSION_HEX``
  A 3-byte hexadecimal representation of the version, e.g.
  ``0x010201`` for version 1.2.1 and ``0x010300`` for version 1.3.

Object oriented Lua
===================
Turbo Web are programmed in a object oriented fashion. There are many ways to do 
object orientation in Lua, this library uses the Middleclass module. Which is documented
at https://github.com/kikito/middleclass/wiki. Middleclass is being used internally in 
Turbo Web, but is also exposed to the user when inheriting from classes such as the
``turbo.web.RequestHandler`` class. Middleclass is a very lightweight, fast and very
easy to learn if you are used to Python, Java or C++.


turbo.web namespace
======================
turbo.web namespace provides a web framework with asynchronous features that allow it
to scale to large numbers of open connections.

Create a web server that listens to port 8888 and prints the canoncial Hello world on a GET request is
very easy:

.. code-block:: lua
   :linenos:

	local turbo = require('turbo')

	local ExampleHandler = class("ExampleHandler", turbo.web.RequestHandler)
	function ExampleHandler:get() 
		self:write("Hello world!") 
	end

	local application = turbo.web.Application:new({ 
		{"/$", ExampleHandler}
	})
	application:listen(8888)
	turbo.ioloop.instance():start()


RequestHandler class
~~~~~~~~~~~~~~~~~~~~
The RequestHandler class are implemented so that it must be subclassed to process HTTP requests.

*Subclass a RequsetHandlerr class and reimplement any of the following methods to handle the corresponding HTTP method, if a request method that is not implemented is recieved the requester will get a 405 (Not Implemented) status code:*

.. function:: RequestHandler:get(...)	
	
	HTTP GET reqests handler.
        
        :param ...: Parameters from matched URL pattern with braces. E.g /users/(.*)$ would provide anything after /users/ as first parameter.

.. function:: RequestHandler:post(...)

	HTTP POST reqests handler.
        
        :param ...: Parameters from matched URL pattern with braces.

.. function:: RequestHandler:head(...)

	HTTP HEAD reqests handler.
        
        :param ...: Parameters from matched URL pattern with braces.

.. function:: RequestHandler:delete(...)

	HTTP DELETE reqests handler.
        
        :param ...: Parameters from matched URL pattern with braces.

.. function:: RequestHandler:put(...)

	HTTP PUT reqests handler.
        
        :param ...: Parameters from matched URL pattern with braces.

.. function:: RequestHandler:options(...)

	HTTP OPTIONS reqests handler.
        
        :param ...: Parameters from matched URL pattern with braces.

All of these methods recieves the arguments from the patterns in the ``turbo.Web.Application`` handler section.

*Candidates for redefinition:*

.. function:: RequestHandler:on_create(kwargs)

	Reimplement this method if you want to do something straight after the class instance has been created.
        
        :param kwargs: The keyword arguments that you initialize the class with.
        :type kwargs: Table

.. function:: RequestHandler:prepare()

	Called before each request, independent on the HTTP method used for the request..

.. function:: RequestHandler:on_finish()

	Called after the end of a request. Useful for e.g a cleanup routine.

.. function:: RequestHandler:set_default_headers()

	Reimplement this method if you want to set special headers on all requests to the handler.

*Stream modifiying methods:*

.. function:: RequestHandler:write(chunk)

	Writes the given chunk to the output buffer.			
	To write the output to the network, call the ``turbo.web.RequestHandler:flush()`` method.
	If the given chunk is a Lua table, it will be automatically
	stringifed to JSON.
        
        :param chunk: Bytes to add to output buffer.
        :type chunk: String

.. function:: RequestHandler:finish(chunk)

	Writes the chunk to the output buffer and finishes the HTTP request.
	This method should only be called once in one request.
        
        :param chunk: Bytes to add to output buffer.
        :type chunk: String

.. function:: RequestHandler:flush(callback)

	Flushes the current output buffer to the IO stream.
			
	If callback is given it will be run when the buffer has 
	been written to the socket. Note that only one callback flush
	callback can be present per request. Giving a new callback
	before the pending has been run leads to discarding of the
	current pending callback. For HEAD method request the chunk 
	is ignored and only headers are written to the socket.
        
        :param callback: Function to call after the buffer has been flushed.
        :type callback: Function

.. function:: RequestHandler:clear()
	
	Reset all headers, empty write buffer in a request.

.. function:: RequestHandler:add_header(name, value)

	Add the given name and value pair to the HTTP response headers. Raises error if name already exists.
        
        :param name: Name of value to add.
        :type name: String
        :param value: Value to add.
        :type value: String

.. function:: RequestHandler:set_header(name, value)

	Set the given name and value pair of the HTTP response headers. If name exists then the value is overwritten.
        
        :param name: Name of value to add.
        :type name: String
        :param value: Value to add.
        :type value: String
        
.. function:: RequestHandler:get_header(name)

	Returns the current value of the given name in the HTTP response headers. Returns nil if not set.
        
        :param name: Name of value to get.
        :type name: String
        :rtype: String or nil

.. function:: RequestHandler:set_status(code)
	
	Set the status code of the HTTP response headers.
	
	:param code: HTTP status code to set.
	:type code: Number

.. function:: RequestHandler:get_status()
	
	Get the curent status code of the HTTP response headers.
	
	:rtype: Number

.. function:: RequestHandler:get_argument(name, default, strip)

	Returns the value of the argument with the given name.
	If default value is not given the argument is considered to be
	required and will result in a 400 Bad Request if the argument
	does not exist.
	
	:param name: Name of the argument to get.
	:type name: String
	:param default: Optional fallback value in case argument is not set.
	:type default: String
	:param strip: Remove whitespace from head and tail of string.
	:type strip: Boolean
	:rtype: String

.. function:: RequestHandler:get_arguments(name, strip)

	Returns the values of the argument with the given name. Should be used when you expect multiple arguments values with same name. Strip will take away whitespaces at head and tail where 		applicable.
	
	Returns a empty table if argument does not exist.
	
	:param name: Name of the argument to get.
	:type name: String
	:param strip: Remove whitespace from head and tail of string.
	:type strip: Boolean
        :rtype: Table

.. function:: RequestHandler:redirect(url, permanent)

	Redirect client to another URL. Sets headers and finish request. User can not send data after this.
        
	:param url: The URL to redirect to.
	:type url: String
	:param permanent: Flag this as a permanent redirect or temporary.
	:type permanent: Boolean


HTTPError class
~~~~~~~~~~~~~~~
Convinence class for raising errors in ``turbo.web.RequestHandler`` and return a HTTP status code to the client. The error is caught by the RequestHandler and requests is ended. Usage:

::

	local ExampleHandler = class("ExampleHandler", turbo.web.RequestHandler)
	function ExampleHandler:get() 
		local param = self:get_argument("some_key")
		if param ~= "expected" then
			error(turbo.web.HTTPError:new(400))
		else
			self:write("Success!")
		end
	end

.. function:: HTTPError:new(code, message)
	
	Provide code and optional message.
	
	:param code: The HTTP status code to send to send to client.
	:type code: Number
	:param message: Optional message to pass as body in the response.
	:type message: String


StaticFileHandler class
~~~~~~~~~~~~~~~~~~~~~~~
A simple static file handler. All files are cached in memory after initial request. Usage:

::

	local application = turbo.web.Application:new({ 
		{"/static/(.*)$", turbo.web.StaticFileHandler, "/var/www/"},
	})


Application class
~~~~~~~~~~~~~~~~~
The Application class is a collection of request handler classes that make together up a web application. Example:

::
	
	local application = turbo.web.Application:new({ 
		{"/static/(.*)$", turbo.web.StaticFileHandler, "/var/www/"},
		{"/$", ExampleHandler},
		{"/item/(%d*)", ItemHandler}
	})

The constructor of this class takes a "map" of URL patterns and their respective handlers. The third element in the table are optional parameters the handler class might have.
E.g the ``turbo.web.StaticFileHandler`` class takes the root path for your static handler. This element could also be another table for multiple arguments.

The first element in the table is the URL that the application class matches incoming request with to determine how to serve it. These URLs simply be a URL or a any kind of Lua pattern.
The ItemHandler URL pattern is an example on how to map numbers from URL to your handlers. Pattern encased in parantheses are used as parameters when calling the request methods in your handlers.

A good read on Lua patterns matching can be found here: http://www.wowwiki.com/Pattern_matching.

.. function:: Application:listen(port, address)
	
	 Starts the HTTP server for this application on the given port.
	 
	 :param port: TCP port to bind server to.
	 :type port: Number
	 :param address: Optional address to bind server to. Use ``turbo.socket.htonl()`` to create address. We use the integer format of the IP.
	 :type address: Number

.. function:: Application:set_server_name(name)

	Sets the name of the server. Used in the response headers.
	
	:param name: The name used in HTTP responses. Default is "Turbo vx.x"
	:type name: String

.. function:: Application:get_server_name()

	Gets the current name of the server.
	:rtype: String


turbo.ioloop namespace
=========================
turbo.ioloop namespace provides a abstracted IO loop, driven typically by Linux Epoll or any other supported poll implemenation. This is the core of Turbo. 
Poll implementations are abstracted and can easily be extended with new variants. 
On Linux Epoll is used and exposed through LuaJIT FFI. The IOLoop class are used by Turbo Web for event driven services.

The inner working are as follows:
	- Set iteration timeout to 3600 milliseconds.
	- If there exists any timeout callbacks, check if they are scheduled to be run. Run them if they are. If timeout callback would be delayed because of too long iteration timeout, the timeout is adjusted.
	- If there exists any interval callbacks, check if they are scheduled to be run. If interval callback would be missed because of too long iteration timeout, the iteration timeout is adjusted.
	- If any callbacks exists, run them. If callbacks add new callbacks, adjust the iteration timeout to 0.
	- If there are any events for sockets file descriptors, run their respective handlers. Else wait for specified interval timeout, or any socket events, jump back to start.
	
Note that because of the fact that the server itself does not know if callbacks block or have a long processing time it cannot guarantee that timeouts and intervals are called on time.
In a perfect world they would be called within a reasonable time of what is specified.

Event types for file descriptors are defined in the ioloop module's namespace:
	``turbo.ioloop.READ``, ``turbo.ioloop.WRITE``, ``turbo.ioloop.PRI``, ``turbo.ioloop.ERROR``

.. function:: ioloop.instance()

        Return the global IO Loop. If none has been created yet, a global IO loop class instance will be created.
        
        :rtype: IOLoop class.

IOLoop class
~~~~~~~~~~~~
IOLoop is a class responsible for managing I/O events through file descriptors. 
Heavily influenced by ioloop.py in the Tornado web framework.
Warning: Only one instance of IOLoop can ever run at the same time!

.. function:: IOLoop:new()

        Instanciate a new IO Loop class.

.. function:: IOLoop:add_handler(file_descriptor, events, handler)

        Add a handler (function) to the IO loop. File descriptor must be a socket, and not a file.
        
        :param file_descriptor: A file descriptor to trigger the handler.
        :type file_descriptor: Number
        :param events: The events to trigger the handler. E.g ``turbo.ioloop.WRITE``. If you wish to listen for multiple events, the event values should be OR'ed together.
        :type events: Number
        :param handler: A callback function that will be called when the handler is triggered.
        :type handler: Function
        
.. function:: IOLoop:update_handler(file_descriptor, events)

        Modify existing handler with new events to trigger it.

        :param file_descriptor: A file descriptor to trigger the handler.
        :type file_descriptor: Number
        :param events: The events to replace the current set events. E.g ``turbo.ioloop.WRITE``. If you wish to listen for multiple events, the event values should be OR'ed together.

.. function:: IOLoop:remove_handler(file_descriptor)

        Remove a existing handler from the IO Loop.
        
        :param file_descriptor: A file descriptor to trigger the handler.
        :type file_descriptor: Number
        
.. function:: IOLoop:add_callback(callback)

        Add a callback to be called on next iteration of the IO Loop.
        
        :param callback: A function to be called on next iteration.
        :type callback: Function
        
.. function:: IOLoop:list_callbacks()

        Returns all current callbacks in the IO Loop.
        
        :rtype: Table
        
.. function:: IOLoop:add_timeout(timestamp, callback)

        Schedule a callback to be called no earlier than given timestamp. There is given no gurantees that the callback will be called
        on time. See the note at beginning of this section.
        
        :param timestamp: A Lua timestamp. E.g os.time()
        :type timestamp: Number
        :param callback: A function to be called after timestamp is reached.
        :type callback: Function
        :rtype: Unique identifer as a reference for this timeout. The reference can be used as parameter for ``IOLoop:remove_timeout()``
        
.. function:: IOLoop:remove_timeout(ref)

        Remove a scheduled timeout by using its identifer.
        
        :param identifer: Identifier returned by ``IOLoop:add_timeout()``
        :type identifer: Number
        
.. function:: IOLoop:set_interval(msec, callback)

        Add a function to be called every milliseconds. There is given no guarantees that the callback will be called on time. See the note at beginning of this section.
        
        :param msec: Milliseconds interval.
        :type msec: Number
        :param callback: A function to be called every msecs.
        :type callback: Function
        :rtype: Unique numeric identifier as a reference to this interval. The refence can be used as parameter for ``IOLoop:clear_interval()``
        
.. function:: IOLoop:clear_interval(ref)

        Clear a interval.
        
        :param ref: Reference returned by ``IOLoop:set_interval()``
        :type ref: Number
        
.. function:: IOLoop:start()

        Start the IO Loop. Blocks until ``IOLoop:close()`` is called from the loop.
        
.. function:: IOLoop:close()
        
        Close the I/O loop. Closes the loop after current iteration is done. Any callbacks queued will be run before closing.
        
.. function:: IOLoop:running()
    
        Is the IO Loop running?
        
        :rtype: Boolean 
        

turbo.iostream namespace
===========================
The turbo.iostream namespace contains the IOStream and SSLIOStream classes, which are abstractions to provide easy to use streaming sockets.

IOStream class
~~~~~~~~~~~~~~
The IOStream class is implemented through the use of the IOLoop class, and are utilized e.g in the RequestHandler class and its subclasses. They provide a non-blocking interface
and support callbacks for most of its operations. For read operations the class supports methods suchs as read until delimiter, read n bytes and read until close. The class has
its own write buffer and there is no need to buffer data at any other level. The default maximum write buffer is defined to 100 MB. This can be defined on class initialization.

.. function:: IOStream:new(provided_socket, io_loop, max_buffer_size, read_chunk_size)

	Create a new IOStream instance.
	
	:param provided_socket: File descriptor, either open or closed. If closed then, the ``IOStream:connect()`` method can be used to connect.
	:type provided_socket: Number
	:param io_loop: IOLoop class instance to use for event processing. If none is set then the global instance is used, see the ``ioloop.instance()`` function.
	:type io_loop: IOLoop object
	:param max_buffer_size: The maximum number of bytes that can be held in internal buffer before flushing must occur. If none is set, 104857600 are used as default.
	:type max_buffer_size: Number
	:param read_chunk_size: The read chunk size that the underlying socket read call is called with. If none is set 4096 are used as default.
	:type read_chunk_size: Number
        :rtype: IOStream object
	
.. function:: IOStream:connect(host, port, callback)

	Connect a socket to given host and port. Specified callback is called upon connection established.
	
	:param host: The host to connect to. Either hostname or IP.
	:type host: String
	:param port: The port to connect to. E.g 80.
	:type port: Number
	:param callback: Function to call on connect.
	:type callback: Function
	
.. function:: IOStream:read_until(delimiter, callback)

	Read from a connected socket up until delimiter, then call callback. The callback recieves the data read as a parameter.
	
	:param delimiter: The string to read up until. E.g "\r\n\r\n".
	:type delimiter: String
	:param callback: Function to call when data has been read up until delimiter. The function is called with the recieved data as first parameter.
	:type callback: Function with one parameter.
	
.. function:: IOStream:read_bytes(num_bytes, callback, streaming_callback)
	
	Call callback when we read the given number of bytes.
	If a streaming_callback argument is given, it will be called with chunks of data as they become available, and the argument to the final call to callback will be empty. 
	
	:param num_bytes: Number of bytes to read before calling callback with the recieved bytes.
	:type num_bytes: Number
	:param callback: Function to call when specified amount of bytes is available.
	:type callback: Function with one parameter.
	:param streaming_callback: Function to call as bytes become available.
	:type streaming_callback: Function with one parameter.
	
.. function:: IOStream:read_until_close(callback, streaming_callback)

	Reads all data from the socket until it is closed.
	If a streaming_callback argument is given, it will be called with
	chunks of data as they become available, and the argument to the
	final call to callback will be empty.
	This method respects the max_buffer_size set in the IOStream object.
	
	:param callback: Function to call when connection has been closed.
	:type callback: Function with one parameter or nil.
	:param streaming_callback: Function to call as bytes become available.
	:type callback: Function with one parameter or nil.
	
.. function:: IOStream:write(data, callback)

	Write the given data to this stream.
	If callback is given, we call it when all of the buffered write
	data has been successfully written to the stream. If there was
	previously buffered write data and an old write callback, that
	callback is simply overwritten with this new callback.
	
	:param data: The chunk to write to the stream.
	:type data: String
	:param callback: Function to be called when data has been written to stream.
	:type callback: Function
	
.. function:: IOStream:set_close_callback(callback)

	Set a callback to be called when the stream is closed.
	
	:type callback: Function
	
.. function:: IOStream:close()

	Close the stream and its associated socket.
	
.. function:: IOStream:reading()

	Is the stream currently being read from?
	
	:rtype: Boolean
	
.. function:: IOStream:writing()

	Is the stream currently being written to?
	
	:rtype: Boolean
	
.. function:: IOStream:closed()

	Has the stream been closed?
	
	:rtype: Boolean
        
turbo.httputil namespace
===========================
The httputil namespace contains the HTTPHeader class and POST data parsers, which is a integral part of the HTTPServer class.

HTTPHeaders class
~~~~~~~~~~~~~~~~~
Used to compile and parse HTTP headers. Parsing is done through the Joyent Node HTTP parser via FFI. It is based on the nginx parser. It is
very fast and contains various protection against attacks. The .so is compiled when Turbo is installed with ``make install``.
Note that this class has sanity checking for input parameters. If they are of wrong type or contains bad data they will raise a error.

.. function :: HTTPHeaders:new(header_string)

    Create a new HTTPHeaders class instance.
    
    :param header_string: (optional) Raw header, up until double CLRF, if you want the class to parse headers on construction
    :type header_string: String
    :rtype: HTTPHeaders object
    
.. function :: HTTPHeaders:get_url_field(UF_prop)
    
    Get specified URL segment. If segment does not exist, -1 is returned. Parameter is either: ``turbo.httputil.UF.SCHEMA``,
    ``turbo.httputil.UF.HOST``, ``turbo.httputil.UF.PORT``, ``turbo.httputil.UF.PATH``, ``turbo.httputil.UF.PATH``,
    ``turbo.httputil.QUERY``, ``turbo.httputil.UF.FRAGMENT`` or ``turbo.httputil.UF.USERINFO``
    
    :param UF_prop: Segment to return, values defined in ``turbo.httputil.UF``.
    :type UF_prop: Number
    :rtype: String or Number on error (-1)
    
.. function :: HTTPHeaders:set_uri(uri)

    Set URI.
    
    :param uri: URI string to set.
    :type uri: String
    
.. function :: HTTPHeaders:get_uri()

    Get URI.
    
    :rtype: String or nil
    
.. function :: HTTPHeaders:set_content_length(len)

    Set Content-Length key.
    
    :param len: Length to set.
    :type len: Number
    
.. function :: HTTPHeaders:get_content_length()

    Get Content-Length key.
    
    :rtype: Number or nil
    
.. function :: HTTPHeaders:set_method(method)
    
    Set URL request method. E.g "POST" or "GET".
    
    :param method: Method to set.
    :type method: String
    
.. function :: HTTPHeaders:get_method()

    Get current URL request method.
    
    :rtype: String or nil
    
.. function :: HTTPHeaders:set_version(version)

    Set HTTP protocol version.
    
    :param version: Version string to set.
    :type version: String
    
.. function :: HTTPHeaders:get_version()
    
    Get current HTTP protocol version.
    
    :rtype: String or nil
    
.. function :: HTTPHeaders:set_status_code(code)

    Set HTTP status code. The code is validated against all known.
    
    :param code: The code to set.
    :type code: Number
    
.. function :: HTTPHeaders:get_status_code()

    Get the current HTTP status code.
    
    :rtype: Number or nil
    
.. function :: HTTPHeaders:get_argument(name)

    Get a argument from the query section of parsed URL. (e.g ?param1=myvalue)
    Note that this method only gets one argument. If there are multiple arguments with same name
    use ``HTTPHeaders:get_arguments()``
    
    :param name: The name of the argument.
    :type name: String
    :rtype: String or nil
    
.. function :: HTTPHeaders:get_arguments()

    Get all URL query arguments in a table. Support multiple values with same name.
    
    :rtype: Table
    
.. function :: HTTPHeaders:get(key)

    Get given key's current value from headers.
    
    :param key: Value to get, e.g "Content-Encoding".
    :type key: String
    :rtype: String    
    
.. function :: HTTPHeaders:add(key, value)
    
    Add a key value pair to headers. Will not overwrite existing keys, use ``HTTPHeaders:set()`` for that.
    
    :param key: The key to set.
    :type key: String
    :param value: The value to set.
    :type value: String
    
.. function :: HTTPHeaders:set(key, value)

    Set a key value to headers. Will overwrite existing key.
    
    :param key: The key to set.
    :type key: String
    :param value: The value to set.
    :type value: String
    
.. function :: HTTPHeaders:remove(key)
    
    Remove a key value combination from the headers.
    
    :param key: Key to remove.
    :type key: String
    
.. function :: HTTPHeaders:update(raw_headers)

    Parse raw HTTP headers and fill the current headers with the data.
    
    :param raw_headers: Raw HTTP header string, up to and including double CRLF.
    :type raw_headers: String
    
.. function :: HTTPHeaders:__tostring()

    Convert the current HTTP headers object to string format.
    
    :rtype: String
    

turbo.util namespace
=======================
The util namespace contains various convinience functions that fits no where else. As Lua is fairly naked as standard. Just the way we like it.

.. function:: string:split(sep, max, pattern)

	Split a string into a table on given seperator. This function extends the standard string library with new functionality.
	
	:param sep: String that seperate elements.
	:type sep: String
	:param max: Max elements to split
	:type max: Number
	:param pattern: Separator should be treated as a Lua pattern. Slower.
	:type pattern: Boolean
	:rtype: Table
	
.. function:: join(delimiter, list)

	Join a table into a string.
	
	:param delimiter: Inserts this string between each table element.
	:type delimiter: String
	:param list: The table to join.
	:type list: Table
	:rtype: String
	
.. function:: is_in(needle, haystack)

	Search table for given element.
	
	:param needle: The needle to find.
	:type needle: Any that supports == operator.
	:param haystack: The haystack to search.
	:type haystack: Table
	
.. function:: hex(num)

	Convert number value to hexadecimal string format.
	
	:param num: The number to convert.
	:type num: Number
	:rtype: String
	
.. function:: mem_dump(ptr, sz)

	Dump memory region to stdout, from ptr to given size. Usefull for debugging Luajit FFI.
	Notice! This can and will cause a SIGSEGV if not being used on valid pointers.
	
	:param ptr: A cdata pointer (from FFI)
	:type ptr: cdata
	:param sz: Length to print hex chars for.
	:type sz: Number
	
.. function:: gettimeofday()

	Returns the current time in milliseconds precision.
	
	:rtype: Number
