.. _sockutil:

*********************************************
turbo.sockutil -- Socket utilites and helpers
*********************************************

.. function:: bind_sockets(port, address, backlog, family)

	Binds sockets to port and address.
	If not address is defined then * will be used.
	If no backlog size is given then 128 connections will be used.

	:param port: (Number) The port number to bind to.
	:param address: (Number) The address to bind to in unsigned integer hostlong format. If not address is given, INADDR_ANY will be used, binding to all addresses.
	:param backlog: (Number) Maximum backlogged client connects to allow. If not defined then 128 is used as default.
	:param family: (Number) Optional socket family. Defined in Socket module. If not defined AF_INET is used as default.
	:rtype: (Number) File descriptor

.. function:: add_accept_handler(sock, callback, io_loop, arg)


	Add accept handler for socket with given callback.
	Either supply a IOLoop object, or the global instance will be used...

	:param sock: (Number) Socket file descriptor to add handler for.
	:param callback: (Function) Callback to handle connects. Function receives socket fd (Number) and address (String) of client as parameters.
	:param io_loop: (IOLoop instance) If not set the global is used.
	:param arg: Optional argument for callback.