.. _iostream:

****************************************************************
turbo.iostream -- High-level asynchronous streaming sockets
****************************************************************

The turbo.iostream namespace contains the IOStream and SSLIOStream classes, which are abstractions to provide easy to use streaming sockets.

IOStream class
~~~~~~~~~~~~~~
The IOStream class is implemented through the use of the IOLoop class, and are utilized e.g in the RequestHandler class and its subclasses. They provide a non-blocking interface
and support callbacks for most of its operations. For read operations the class supports methods suchs as read until delimiter, read n bytes and read until close. The class has
its own write buffer and there is no need to buffer data at any other level. The default maximum write buffer is defined to 100 MB. This can be defined on class initialization.

.. function:: IOStream(provided_socket, io_loop, max_buffer_size, read_chunk_size)

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