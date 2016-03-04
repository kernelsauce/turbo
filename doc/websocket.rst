.. _websocket:

**********************************************
turbo.websocket -- WebSocket server and client
**********************************************

The WebSocket modules extends Turbo and offers RFC 6455 compliant WebSocket
support.

The module offers two classes:

- ``turbo.websocket.WebSocketHandler``, WebSocket support for ``turbo.web.Application``.
- ``turbo.websocket.WebSocketClient``, callback based WebSocket client.

Both classes uses the mixin class ``turbo.websocket.WebSocketStream``, which in
turn provides almost identical API's for the two classes once connected. Both
classes support SSL (wss://).

*NOTICE: _G.TURBO_SSL MUST be set to true and OpenSSL or axTLS MUST be
installed to use this module as certain hash functions are required by the
WebSocket protocol.*

A simple example subclassing ``turbo.websocket.WebSocketHandler``.:

.. code-block:: lua

	_G.TURBO_SSL = true
	local turbo = require "turbo"

	local WSExHandler = class("WSExHandler", turbo.websocket.WebSocketHandler)

	function WSExHandler:on_message(msg)
	    self:write_message("Hello World.")
	end

	turbo.web.Application({{"^/ws$", WSExHandler}}):listen(8888)
	turbo.ioloop.instance():start()

WebSocketStream mixin
~~~~~~~~~~~~~~~~~~~~~
WebSocketStream is a abstraction for a WebSocket connection, used as class mixin
in ``turbo.websocket.WebSocketHandler`` and ``turbo.websocket.WebSocketClient``.

.. function:: WebSocketStream:write_message(msg, binary)

	Send a message to the client of the active Websocket. If the stream has been
	closed a error is raised.

        :param msg: The message to send. This may be either a JSON-serializable table or a string.
        :type msg: String
        :param binary: Treat the message as binary data (use WebSocket binary opcode).
        :type binary: Boolean


.. function:: WebSocketStream:ping(data, callback, callback_arg)

	Send a ping to the connected client.

	:param data: Data to pong back.
	:type data: String
	:param callback: Function to call when pong is received.
	:type callback: Function
	:param callback_arg: Argument for callback function.

.. function:: WebSocketStream:pong(data)

	Send a pong to the connected server.

	:param data: Data to pong back.
	:type data: String

.. function:: WebSocketStream:close()

	Close the connection.

.. function:: WebSocketStream:closed()

	Has the stream been closed?

WebSocketHandler class
~~~~~~~~~~~~~~~~~~~~~~
The WebSocketHandler is a subclass of ``turbo.web.RequestHandler``.
So most of the methods and attributes of that class are available. However, some
of them will not work with WebSocket's. It also have the mixin class
``turbo.websocket.WebSocketStream`` included. Only the official WebSocket
specification, RFC 6455, is supported.

For a more thorough example of usage of this class you can review the "chatapp"
example bundled with Turbo, which uses most of its features to create a simple
Web-based chat app.

*Subclass WebSocketHandler and implement any of the following methods to handle
the corresponding events.*

.. function:: WebSocketHandler:open()

	Called when a new WebSocket request is opened.

.. function:: WebSocketHandler:on_message(msg)

	Called when a message is received.

	:param msg: The received message.
	:type msg: String

.. function:: WebSocketHandler:on_close()

	Called when the connection is closed.

.. function:: WebSocketHandler:on_error(msg)

	:param msg: A error string.
	:type msg: String

.. function:: WebSocketHandler:prepare()

	Called when the headers has been parsed and the server is about to initiate
	the WebSocket specific handshake. Use this to e.g check if the headers
	Origin field matches what you expect. To abort the connection you raise a
	error. ``turbo.web.HTTPError`` is the most convinient as you can set error
	code and a message returned to the client.

.. function:: WebSocketHandler:subprotocol(protocols)

	Called if the client have included a Sec-WebSocket-Protocol field
	in header. This method will then receive a table of protocols that
	the clients wants to use. If this field is not set, this method will
	never be called. The return value of this method should be a string
	which matches one of the suggested protcols in its parameter.
	If all of the suggested protocols are unacceptable then dismissing of
	the request is done by either raising error
	(such as ``turbo.web.HTTPError``) or returning nil.

	:param protocols: The protocol names received from client.
	:type protocols: Table of protocol name strings.

WebSocketClient class
~~~~~~~~~~~~~~~~~~~~~

A async callback based WebSocket client. Only the official WebSocket
specification, RFC 6455, is supported. The WebSocketClient is partly based
on the ``turbo.async.HTTPClient`` using its HTTP implementation to do the initial
connect to the server, then do the handshake and finally wrapping the connection
with the ``turbo.websocket.WebSocketStream``. All of the callback functions
receives the class instance as first argument for convinence. Furthermore the
class can be initialized with keyword arguments that are passed on to the
``turbo.async.HTTPClient`` that are being used. So if you are going to use
the connect to a SSL enabled server (wss://) then you simply refer to the documentation
of the HTTPClient and set "priv_file", "cert_file" keys properly.
Some arguments are discared though, such as e.g "method".

A simple usage example of ``turbo.websocket.WebSocketClient``.:

.. code-block:: lua

	_G.TURBO_SSL = true -- SSL must be enabled for WebSocket support!
	local turbo = require "turbo"

	turbo.ioloop.instance():add_callback(function()
	    turbo.websocket.WebSocketClient("ws://127.0.0.1:8888/ws", {
	        on_headers = function(self, headers)
	            -- Review headers received from the WebSocket server.
	            -- You can e.g drop the request if the response headers
	            -- are not satisfactory with self:close().
	        end,
	        modify_headers = function(self, headers)
	            -- Modify outgoing headers before they are sent.
	            -- headers parameter are a instance of httputil.HTTPHeader.
	        end,
	        on_connect = function(self)
	            -- Called when the client has successfully opened a WebSocket
	            -- connection to the server.
	            -- When the connection is established you can write a message:
	            self:write_message("Hello World!")
	        end,
	        on_message = function(self, msg)
	            -- Print the incoming message.
	            print(msg)
	            self:close()
	        end,
	        on_close = function(self)
	            -- I am called when connection is closed. Both gracefully and
	            -- not gracefully.
	        end,
	        on_error = function(self, code, reason)
	            -- I am called whenever there is a error with the WebSocket.
	            -- code are defined in ``turbo.websocket.errors``. reason are
	            -- a string representation of the same error.
	        end
	    })
	end):start()

WebSocketClient uses error codes to report failure for the ``on_error`` callback.

.. attribute::	errors

	Numeric error codes set as first argument of ``on_error``:

	    ``INVALID_URL``            - URL could not be parsed.

	    ``INVALID_SCHEMA``         - Invalid URL schema

	    ``COULD_NOT_CONNECT``      - Could not connect, check message.

	    ``PARSE_ERROR_HEADERS``    - Could not parse response headers.

	    ``CONNECT_TIMEOUT``        - Connect timed out.

	    ``REQUEST_TIMEOUT``        - Request timed out.

	    ``NO_HEADERS``             - Shouldn't happen.

	    ``REQUIRES_BODY``          - Expected a HTTP body, but none set.

	    ``INVALID_BODY``           - Request body is not a string.

	    ``SOCKET_ERROR``           - Socket error, check message.

	    ``SSL_ERROR``              - SSL error, check message.

	    ``BUSY``              	   - Operation in progress.

	    ``REDIRECT_MAX``		   - Redirect maximum reached.

	    ``CALLBACK_ERROR``         - Error in callback.

	    ``BAD_HTTP_STATUS``        - Did not receive expected 101 Upgrade.

	    ``WEBSOCKET_PROTOCOL_ERROR``  - Invalid WebSocket protocol data received.

.. function:: WebSocketClient(address, kwargs):

	Create a new WebSocketClient class instance.

	:param address: URL for WebSocket server to connect to.
	:type address: String
	:param kwargs: Optional keyword arguments.
	:type kwargs: Table
	:rtype: Instance of ``turbo.websocket.WebSocketClient``

	Available keyword arguments:

	* ``params`` - Provide parameters as table.
	* ``cookie`` - The cookie to use.
	* ``allow_redirects`` - Allow or disallow redirects. Default is true.
	* ``max_redirects`` - Maximum redirections allowed. Default is 4.
	* ``body`` - Request HTTP body in plain form.
	* ``request_timeout`` - Total timeout in seconds (including connect) for request. Default is 60 seconds. After the connection has been established the timeout is removed.
	* ``connect_timeout`` - Timeout in seconds for connect. Default is 20 secs.
	* ``auth_username`` - Basic Auth user name.
	* ``auth_password`` - Basic Auth password.
	* ``user_agent`` - User Agent string used in request headers. Default is ``Turbo Client vx.x.x``.
	* ``priv_file`` - Path to SSL / HTTPS private key file.
	* ``cert_file`` - Path to SSL / HTTPS certificate key file.
	* ``ca_path`` - Path to SSL / HTTPS CA certificate verify location, if not given builtin is used, which is copied from Ubuntu 12.10.
	* ``verify_ca`` - SSL / HTTPS verify servers certificate. Default is true.

Description of the callback functions
-------------------------------------

.. function:: modify_headers(self, headers)

	Modify OUTGOING HTTP headers before they are sent to the server.

	:param self: The WebSocketClient instance calling the callback.
	:type self: turbo.websocket.WebSocketClient
	:param headers: Headers ready to be sent and possibly modified.
	:type headers: ``turbo.httputil.HTTPHeader``

.. function:: on_headers(self, headers)

	Review HTTP headers received from the WebSocket server.
	You can e.g drop the request if the response headers
	are not satisfactory with self:close().

	:param self: The WebSocketClient instance calling the callback.
	:type self: turbo.websocket.WebSocketClient
	:param headers: Headers received from the client.
	:type headers: ``turbo.httputil.HTTPHeader``

.. function:: on_connect(self)

	Called when the client has successfully opened a WebSocket
	connection to the server.

	:param self: The WebSocketClient instance calling the callback.
	:type self: turbo.websocket.WebSocketClient

.. function:: on_message(self, msg)

	Called when a message is received.

	:param self: The WebSocketClient instance calling the callback.
	:type self: turbo.websocket.WebSocketClient
	:param msg: The message or binary data.
	:type msg: String

.. function:: on_close(self)

	Called when connection is closed. Both gracefully and
	not gracefully.

	:param self: The WebSocketClient instance calling the callback.
	:type self: turbo.websocket.WebSocketClient

.. function:: on_error(self, code, reason)

	Called whenever there is a error with the WebSocket.
	code are defined in ``turbo.websocket.errors``. reason are
	a string representation of the same error.

	:param self: The WebSocketClient instance calling the callback.
	:type self: turbo.websocket.WebSocketClient
	:param code: Error code defined in ``turbo.websocket.errors``.
	:type code: Number
	:param reason: String representation of error.
	:type reason: String

.. function:: on_ping(self, data)

	Called when a ping request is received.

	:param self: The WebSocketClient instance calling the callback.
	:type self: turbo.websocket.WebSocketClient
	:param data: The ping payload data.
	:type data: String

