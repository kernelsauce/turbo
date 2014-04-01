.. _websocket:

**********************************************
turbo.websocket -- WebSocket server and client
**********************************************

The WebSocket modules extends Turbo and offers RFC 6455 compliant WebSocket
support.

The module offers two classes:
	
- ``turbo.websocket.WebSocketHandler``, WebSocket support for ``turbo.web.Application``.
- ``turbo.websocket.WebSocketClient``, callback based WebSocket client.

Both classes uses the mixin class WebSocketStream, which in turn provides
almost identical API's for the two classes once connected. Both classes
support SSL (wss://).

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

WebSocketHandler class
~~~~~~~~~~~~~~~~~~~~~~
The WebSocketHandler is a subclass of ``turbo.web.RequestHandler``. 
So most of the methods and attributes of that class are available. However, some
of them will not work with WebSocket's. It also have the mixin class 
``turbo.websocket.WebSocketStream`` included.

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
		:param callback: Function to call when pong is recieved.
		:type callback: Function
		:param callback_arg: Argument for callback function.

