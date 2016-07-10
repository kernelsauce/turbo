.. _httpserver:

**********************************************
turbo.httpserver -- Callback based HTTP Server
**********************************************

A non-blocking HTTPS Server based on the TCPServer class.
Supports HTTP/1.0 and HTTP/1.1.
Includes SSL support.

HTTPServer class
~~~~~~~~~~~~~~~~

HTTPServer based on TCPServer, IOStream and IOLoop classes.
This class is used by the ``turbo.web.Application`` class to serve its RequestHandlers.
The server itself is only responsible for handling incoming requests, no
response to the request is produced, that is the purpose of the request
callback given as argument on initialization. The callback receives the
HTTPRequest class instance produced for the incoming request and can
by data provided in that instance decide on how it want to respond to
the client. The callback must produce a valid HTTP response header and
optionally a response body and use the ``turbo.web.HTTPRequest:write`` method.
The server supports SSL, HTTP/1.1 Keep-Alive and optionally HTTP/1.0
Keep-Alive if the header field is specified.

Only use this class if you wish to have full control of things. Otherwise use the
wrapper ``turbo.web.Application``!

Example usage of HTTPServer:

.. code-block:: lua

	local httpserver = require('turbo.httpserver')
	local ioloop = require('turbo.ioloop')
	local ioloop_instance = ioloop.instance()

	function handle_request(request)
	    local message = "You requested: " .. request.path
	    request:write("HTTP/1.1 200 OK\r\nContent-Length:" .. message:len() .. "\r\n\r\n")
	    request:write(message)
	    request:finish()
	end

	http_server = httpserver.HTTPServer:new(handle_request)
	http_server:listen(8888)
	ioloop_instance:start()

.. function:: HTTPServer(request_callback, no_keep_alive, io_loop, xheaders, kwargs)

	Create a new HTTPServer class instance.

	:param request_callback: Function to be called when requests are received by the server. The callback receives the HTTPRequest class instance produced for the incoming request as first argument. See the HTTPRequest documentation.
	:type request_callback: Function
	:param no_keep_alive: If clients request to use Keep-Alive is to be ignored.
	:type no_keep_alive: Boolean
	:param io_loop: The IOLoop instance you want to use, if not defined the global instance is used.
	:type io_loop: ``turbo.ioloop.IOLoop`` class instance.
	:param xheaders: Care about X-* header fields or not. If set to true the remote_ip attribute in self
		reflects the X-Real-Ip or X-Forwarded-For HTTP header value received.
	:type xheaders: Boolean
	:param kwars: Optional keyword arguments
	:type kwargs: Table

	Available keyword arguments:

	* ``read_body`` - Automatically read, and parse any request body. Default is true. If set to false, the user must read the body from the connection himself. Not reading a body in the case of a keep-alive request may lead to undefined behaviour. The body should be read or connection closed.
	* ``max_header_size`` - The maximum amount of bytes a header can be. If exceeded, request is dropped.
	* ``max_body_size`` - The maxium amount of bytes a request body can be. If exceeded, request is dropped. HAS NO EFFECT IF read_body IS FALSE.
	* ``ssl_options`` :
	     ``key_file`` - SSL key file if a SSL enabled server is wanted,
	     ``cert_file`` - Certificate file.

General note regarding callbacks for all write methods: If you do writes before the previous callback has been called it is replaced with the new callback. If there is no callback defined in consequtive calls, the old callback is simply removed.

HTTPRequest class
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Represents a HTTP request to the server.

This class has some attributes that can be accessed:

	:method: (String) HTTP Request method. Also available in the ``headers`` attribute.
	:version: (String) HTTP Version
	:uri: (String) Uniform Resource Identifier
	:path: (String) Request URL
	:headers: ``turbo.httputil.HTTPHeaders`` class instance of the request headers.
	:body: (String) The raw payload of the request, if any.
	:connection: ``turbo.httpserver.HTTPConection`` class instance for this request.
	:files: (Table) Files sent, file name is key and contents is its value.
	:host: (String) Host IP
	:arguments: (Table) Raw arguments table. The ``turbo.web.RequestHandler`` have convience methods for accessing these.

.. function:: HTTPRequest:request_time()

	Return the time used to handle the request or the time up to now if request not finished.

	:rtype: (Number) Milliseconds the request took to finish, or up until now if not yet completed.

.. function:: HTTPRequest:full_url()

	Return the full URL that the user requested.

	:rtype: String

.. function:: HTTPRequest:write(chunk, callback, arg)

	Writes a chunk of output to the stream.

 	:param chunk: Data chunk to write to underlying IOStream.
 	:type chunk: String
	:param callback: Optional function called when buffer is fully flushed.
	:type callback: Function
	:param arg: Optional first argument for callback.

.. function:: HTTPRequest:write_buffer(buf, callback, arg)

	Write the given ``turbo.structs.buffer`` to the underlying stream.

	:param buf: The buffer to write to the stream.
	:type buf: ``turbo.structs.buffer`` class instance
	:param callback: Optional function called when buffer is fully flushed
	:type callback: Function
	:param arg: Optional argument for callback. If arg is given then it will be the first argument for the callback.

.. function:: HTTPRequest:write_zero_copy(buf, callback, arg)

	Write a Buffer class instance without copying it into the underlying IOStream's internal
	buffer. Some considerations has to be done when using this. Any prior calls
	to HTTPConnection:write or HTTPConnection:write_buffer must have completed
	before this method can be used. The zero copy write must complete before any
	other writes may be done. Also the buffer class should not be modified
	while the write is being completed. Failure to follow these advice will lead
	to undefined behaviour.

	:param buf: Buffer class instance
	:param callback: Optional function called when buffer is fully flushed
	:type callback: Function
	:param arg: Optional first argument for callback.

.. function:: HTTPConnection:finish()

	Finishes request.

.. function:: HTTPRequest:supports_http_1_1()

	Returns true if requester supports HTTP 1.1

	:rtype: Boolean

HTTPConnection class
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Represents a live connection to the server. Basically a helper class to
HTTPServer. It uses the IOStream class's callbacks to handle the different
sections of a HTTP request.

.. function:: HTTPConnection:write(chunk, callback, arg)

	Writes a chunk of output to the stream.

 	:param chunk: Data chunk to write to underlying IOStream.
 	:type chunk: String
	:param callback: Optional function called when buffer is fully flushed.
	:type callback: Function
	:param arg: Optional first argument for callback.

.. function:: HTTPConnection:write_buffer(buf, callback, arg)

	Write the given ``turbo.structs.buffer`` to the underlying stream.

	:param buf: The buffer to write to the stream.
	:type buf: ``turbo.structs.buffer`` class instance
	:param callback: Optional function called when buffer is fully flushed
	:type callback: Function
	:param arg: Optional argument for callback. If arg is given then it will be the first argument for the callback.

.. function:: HTTPConnection:write_zero_copy(buf, callback, arg)

	Write a Buffer class instance without copying it into the underlying IOStream's internal
	buffer. Some considerations has to be done when using this. Any prior calls
	to HTTPConnection:write or HTTPConnection:write_buffer must have completed
	before this method can be used. The zero copy write must complete before any
	other writes may be done. Also the buffer class should not be modified
	while the write is being completed. Failure to follow these advice will lead
	to undefined behaviour.

	:param buf: Buffer class instance
	:param callback: Optional function called when buffer is fully flushed
	:type callback: Function
	:param arg: Optional first argument for callback.

.. function:: HTTPConnection:finish()

	Finishes request.
