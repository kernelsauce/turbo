.. _tcpserver:

***************************************************
turbo.tcpserver -- Callback based TCP socket Server
***************************************************

A simple non-blocking extensible TCP Server based on the IOStream class.
Includes SSL support. Used as base for the Turbo HTTP Server.

TCPServer class
~~~~~~~~~~~~~~
A non-blocking TCP server class.
Users which want to create a TCP server should inherit from this class and
implement the TCPServer:handle_stream() method. Optional SSL support is provided.

.. function:: TCPServer(io_loop, ssl_options, max_buffer_size)

	Create a new TCPServer class instance. If the SSL certificates is provided and can not be loaded, a error is raised.

	:param io_loop: Provide specific IOLoop class instance. If not provided the global instance is used.
	:type io_loop: ``turbo.ioloop.IOLoop instance``
	:param ssl_options:  Optional SSL parameters.
	:type ssl_options: Table
	:param max_buffer_size: The maximum buffer size of the server. If the limit is hit, the connection is closed.
	:type max_buffer_size: Number
	:rtype: TCPServer class instance

	Available ssl_options keys:

	* "key_file" (String) - Path to SSL key file if a SSL enabled server is wanted.
	* "cert_file" (String) - Path to certificate file. key_file must also be set.

.. function:: TCPServer:handle_stream(stream, address)

	This method is called by the class when clients connect. Implement this method in inheriting class to handle new connections.

	:param stream: Stream for the newly connected client.
	:type stream: ``turbo.iostream.IOStream`` instance
	:param address: IP address of newly connected client.
	:type address: String

.. function:: TCPServer:listen(port, address, backlog, family)

	Start listening on port and address. When using this method, as oposed to TCPServer:bind you should not call
	TCPServer:start. You can call this method multiple times with different parameters to bind multiple sockets to the same TCPServer.

	:param port: The port number to bind to.
	:type port: Number
	:param address: The address to bind to in unsigned integer hostlong format. If not address is given, ``turbo.socket.INADDR_ANY`` will be used, binding to all addresses.
	:type address: Number
	:param backlog: Maximum backlogged client connects to allow. If not defined then 128 is used as default.
	:type backlog: Number
	:param family: Optional socket family. All socket familys are defined in ``turbo.socket`` module. If not defined AF_INET is used as default.
	:type family: Number


.. function:: TCPServer:add_sockets(sockets)

	Add multiple sockets in a table that should be bound on calling start. Use the ``turbo.sockutil.bind_sockets`` function to create sockets easily and add them to the sockets table.

	:param sockets:  1 or more socket fd's.
	:type sockets: Table

.. function:: TCPServer:add_socket(socket)

	Single socket version of TCPServer:add_socket.

	:param socket:  Socket fd.
	:type socket: Number

.. function:: TCPServer:bind(port, address, backlog, family)

	Bind this server to port and address. User must also call TCPServer:start to start listening on the bound socket.

	:param port: The port number to bind to.
	:type port: Number
	:param address: The address to bind to in unsigned integer hostlong format. If not address is given, ``turbo.socket.INADDR_ANY`` will be used, binding to all addresses.
	:type address: Number
	:param backlog: Maximum backlogged client connects to allow. If not defined then 128 is used as default.
	:type backlog: Number
	:param family: Optional socket family. All socket familys are defined in ``turbo.socket`` module. If not defined AF_INET is used as default.
	:type family: Number

.. function:: TCPServer:start()

	Start the TCPServer, accepting conncetions on bound sockets.

.. function:: TCPServer:stop()

	Stop the TCPServer. Closing all the sockets bound to it. Before restarting the TCPServer, the socket must be readded.