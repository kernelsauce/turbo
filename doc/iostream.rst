.. _iostream:

***************************************************************
turbo.iostream -- Callback based asynchronous streaming sockets
***************************************************************

The turbo.iostream namespace contains the IOStream and SSLIOStream classes, which are abstractions to provide easy to use streaming sockets. All API's are callback based and depend on the ``turbo.ioloop.IOLoop`` class.

IOStream class
~~~~~~~~~~~~~~
The IOStream class is implemented through the use of the IOLoop class, and are utilized e.g in the RequestHandler class and its subclasses. They provide a non-blocking interface
and support callbacks for most of its operations. For read operations the class supports methods suchs as read until delimiter, read n bytes and read until close. The class has
its own write buffer and there is no need to buffer data at any other level. The default maximum write buffer is defined to 100 MB. This can be defined on class initialization.

.. function:: IOStream(fd, io_loop, max_buffer_size, kwargs)

	Create a new IOStream instance.

	:param fd: File descriptor, either open or closed. If closed then, the ``turbo.iostream.IOStream:connect()`` method can be used to connect.
	:type fd: Number
	:param io_loop: IOLoop class instance to use for event processing. If none is set then the global instance is used, see the ``ioloop.instance()`` function.
	:type io_loop: IOLoop object
	:param max_buffer_size: The maximum number of bytes that can be held in internal buffer before flushing must occur. If none is set, 104857600 are used as default.
	:type max_buffer_size: Number
	:param kwargs: Keyword arguments
	:type kwargs: Table
	:rtype: IOStream object

	Available keyword arguments:

	* ``dns_timeout`` - (Number) Timeout for DNS lookup on connect.

.. function:: IOStream:connect(address, port, family, callback, fail_callback, arg)

	Connect to a address without blocking. To successfully use this method it is neccessary to use a success and a fail callback function to properly handle both cases.

	:param host: The host to connect to. Either hostname or IP.
	:type host: String
	:param port: The port to connect to. E.g 80.
	:type port: Number
	:param family: Socket family. Optional. Pass nil to guess.
	:param callback: Optional callback for "on successfull connect"
	:type callback: Function
	:param fail_callback: Optional callback for "on error". Called with errno and its string representation as arguments.
	:type fail_callback: Function
	:param arg: Optional argument for callback. callback and fail_callback are called with this as first argument.

.. function:: IOStream:read_until(delimiter, callback, arg)

	Read until delimiter, then call callback with received data. The callback
	receives the data read as a parameter. Delimiter is plain text, and does
	not support Lua patterns. See read_until_pattern for that functionality.
	read_until should be used instead of read_until_pattern wherever possible
	because of the overhead of doing pattern matching.

	:param delimiter: Delimiter sequence, text or binary.
	:type delimiter: String
	:param callback:  Callback function. The function is called with the received data as parameter.
	:type callback: Function
	:param arg: Optional argument for callback. If arg is given then it will be the first argument for the callback and the data will be the second.

.. function:: IOStream:read_until_pattern(pattern, callback, arg)

	Read until pattern is matched, then call callback with received data.
	The callback receives the data read as a parameter. If you only are
	doing plain text matching then using read_until is recommended for
	less overhead.

	:param pattern: Lua pattern string.
	:type pattern: String
	:param callback: Callback function. The function is called with the received data as parameter.
	:type callback: Function
	:param arg: Optional argument for callback. If arg is given then it will be the first argument for the callback and the data will be the second.

.. function:: IOStream:read_bytes(num_bytes, callback, arg, streaming_callback, streaming_arg)

	Call callback when we read the given number of bytes.
	If a streaming_callback argument is given, it will be called with chunks
	of data as they become available, and the argument to the final call to
	callback will be empty.

	:param num_bytes: The amount of bytes to read.
	:type num_bytes: Number
	:param callback: Callback function. The function is called with the received data as parameter.
	:type callback: Function
	:param arg: Optional argument for callback. If arg is given then it will be the first argument for the callback and the data will be the second.
	:param streaming_callback: Optional callback to be called as chunks become available.
	:type streaming_callback: Function
	:param streaming_arg: Optional argument for callback. If arg is given then it will be the first argument for the callback and the data will be the second.

.. function:: IOStream:read_until_close(callback, arg, streaming_callback, streaming_arg)

	Reads all data from the socket until it is closed.
	If a streaming_callback argument is given, it will be called with
	chunks of data as they become available, and the argument to the final call to
	callback will contain the final chunk.
	This method respects the max_buffer_size set in the IOStream object.

	:param callback: Function to call when connection has been closed.
	:type callback: Function with one parameter or nil.
	:param arg: Optional argument for callback. If arg is given then it will be the first argument for the callback and the data will be the second.
	:param streaming_callback: Function to call as chunks become available.
	:type callback: Function with one parameter or nil.
	:param streaming_arg: Optional argument for callback. If arg is given then it will be the first argument for the callback and the data will be the second.

.. function:: IOStream:write(data, callback, arg)

	Write the given data to this stream.
	If callback is given, we call it when all of the buffered write
	data has been successfully written to the stream. If there was
	previously buffered write data and an old write callback, that
	callback is simply overwritten with this new callback.

	:param data: The chunk to write to the stream.
	:type data: String
	:param callback: Function to be called when data has been written to stream.
	:type callback: Function
	:param arg: Optional argument for callback. If arg is given then it will be the first argument for the callback.

.. function:: IOStream:write_buffer(buf, callback, arg)

	Write the given ``turbo.structs.buffer`` to the stream.

	:param buf: The buffer to write to the stream.
	:type buf: ``turbo.structs.buffer`` class instance
	:param callback: Function to be called when data has been written to stream.
	:type callback: Function
	:param arg: Optional argument for callback. If arg is given then it will be the first argument for the callback.

.. function:: IOStream:write_zero_copy(buf, callback, arg)

	Write the given buffer class instance to the stream without
	copying. This means that this write MUST complete before any other
	writes can be performed, and that the internal buffer has to be completely flushed
	before it is invoked. This can be achieved by either using ``IOStream:writing`` or adding a callback to
	other write methods callled before this. There is a barrier in place to stop this from
	happening. A error is raised in the case of invalid use. This method is recommended
	when you are serving static data, it refrains from copying the contents of
	the buffer into its internal buffer, at the cost of not allowing
	more data being added to the internal buffer before this write is finished. The reward is lower
	memory usage and higher throughput.

	:param buf: The buffer to send. Will not be modified, and must not be modified until write is done.
	:type buf: ``turbo.structs.buffer``
	:param callback: Function to be called when data has been written to stream.
	:type callback: Function
	:param arg: Optional argument for callback. If arg is given then it will be the first argument for the callback.

.. function:: IOStream:set_close_callback(callback, arg)

	Set a callback to be called when the stream is closed.

	:param callback: Function to call on close.
	:type callback: Function
	:param arg: Optional argument for callback.

.. function:: IOStream:set_max_buffer_size(sz)

    Set the maximum amount of bytes to be buffered internally in the IOStream instance.
    This limit can also be set on class instanciation. This method does NOT check the
    current size and does NOT immediately raise a error if the size is already exceeded.
    A error will instead occur when the IOStream is adding data to its buffer on the next
    occasion and detects a breached limit.

    :param sz: Size of max buffer in bytes.
    :type sz: Number

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

SSLIOStream class
~~~~~~~~~~~~~~~~~
The class is a extended IOStream class and uses
OpenSSL for its implementation. All of the methods in its super class IOStream, are available. Obviously a SSL tunnel software is a more optimal approach than this, as there
is quite a bit of overhead in handling SSL connections.
For this class to be available, the global ``_G.TURBO_SSL``
must be set.

.. function:: SSLIOStream(fd, ssl_options, io_loop, max_buffer_size)

	Create a new SSLIOStream instance. You can use:

	* ``turbo.crypto.ssl_create_client_context``
	* ``turbo.crypto.ssl_create_server_context``
	to create a SSL context to pass in the ssl_options argument.

	ssl_options table should contain:

	* "_ssl_ctx" - SSL_CTX pointer created with context functions in crypto.lua.
	* "_type" - Optional number, 0 or 1. 0 indicates that the context is a server context, and 1 indicates a client context. If not set, it is presumed to be a server context.

	:param fd: File descriptor, either open or closed. If closed then, the ``turbo.iostream SSLIOStream:connect()`` method can be used to connect.
	:type fd: Number
	:param ssl_options: SSL arguments.
	:type ssl_options: Table
	:param io_loop: IOLoop class instance to use for event processing. If none is set then the global instance is used, see the ``ioloop.instance()`` function.
	:type io_loop: IOLoop class instance
	:param max_buffer_size: The maximum number of bytes that can be held in internal buffer before flushing must occur. If none is set, 104857600 are used as default.
	:type max_buffer_size: Number
	:rtype: SSLIOStream object

.. function:: SSLIOStream:connect(address, port, family, verify, callback, errhandler, arg)

	Connect to a address without blocking. To successfully use this method it is neccessary to check
	the return value, and also assign a error handler function. Notice that the verify arugment has
	been added as opposed to the ``SSLIOStream:connect`` method.

	:param host: The host to connect to. Either hostname or IP.
	:type host: String
	:param port: The port to connect to. E.g 80.
	:type port: Number
	:param family: Socket family. Optional. Pass nil to guess.
	:param verify: Verify SSL certificate chain and match hostname in certificate on connect. Setting this to false is only recommended if the server certificates are self-signed or something like that.
	:type verify: Boolean
	:param callback: Optional callback for "on successfull connect"
	:type callback: Function
	:param errhandler: Optional callback for "on error". Called with errno and its string representation as arguments.
	:type errhandler: Function
	:param arg: Optional argument for callback. callback and errhandler are called with this as first argument.
	:rtype: Number. -1 + error message on error, 0 on success.
