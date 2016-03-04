***********************************************************
turbo.iosimple -- Simple Callback-less asynchronous sockets
***********************************************************

A simple interface for the IOStream class without the callback spaghetti, but still
the async backend (the yield is done internally):

.. code-block:: lua

    turbo.ioloop.instance():add_callback(function()
        local stream = turbo.iosimple.dial("tcp://turbolua.org:80")
        stream:write("GET / HTTP/1.0\r\n\r\n")

        local data = stream:read_until_close()
        print(data)

        turbo.ioloop.instance():close()
    end):start()

.. function:: iosimple.dial(address, ssl, io)

    Connect to a host using a simple URL pattern.

    :param address: The address to connect to in URL form, e.g: ``"tcp://turbolua.org:80"``.
    :type address: String
    :param ssl: Option to connect with SSL. Takes either a boolean true or a table with options, options described below.
    :type ssl: Boolean or Table
    :param io: IOLoop class instance to use for event processing. If none is set then the global instance is used, see the ioloop.instance() function.
    :type io: IOLoop object

    Available SSL options:

    Boolean, if ssl param is set to ``true``, it will be equal to a SSL option table
    like this ``{verify=true}``. If not argument is given or nil then SSL will not be used at all.

    A table may be used to give additional options instead of just a "enable" button:

    * ``key_file`` (String) - Path to SSL / HTTPS key file.
    * ``cert_file`` (String) - Path to SSL / HTTPS certificate file.
    * ``ca_cert_file`` (String) - Path to SSL / HTTPS CA certificate verify location, if not given builtin is used, which is copied from Ubuntu 12.10.
    * ``verify`` (Boolean) SSL / HTTPS verify servers certificate. Default is true.

IOSimple class
~~~~~~~~~~~~~~
A alternative to the IOStream class that were added in version 2.0. The goal
of this class is to further simplify the way that we use Turbo. The IOStream class
is based on callbacks, and while this to some may be the optimum way it might not 
be for others. You could always use the ``async.task()`` function to wrap it in a
coroutine and yield it. To save you the hassle a new class has been made.

All functions may raise errors. All functions yield to the IOLoop internally. You may catch errors with xpcall or pcall.

.. function:: IOSimple(stream)

    Wrap a IOStream class instance with a simpler IO. If you are not wrapping consider using ``iosimple.dial()``.

    :param stream: A stream already connected. If not consider using ``iosimple.dial()``.
    :type stream: ``IOStream object``
    :rtype: ``IOSimple object``

.. function:: IOSimple:read_until(delimiter)

    Read until delimiter. Delimiter is plain text, and does
    not support Lua patterns. See read_until_pattern for that functionality.
    read_until should be used instead of read_until_pattern wherever possible
    because of the overhead of doing pattern matching.

    :param delimiter: Delimiter sequence, text or binary.
    :type delimiter: String
    :rtype: String

.. function:: IOSimple:read_until_pattern(pattern)

    Read until pattern is matched, then return with received data. If you only are
    doing plain text matching then using read_until is recommended for
    less overhead.

    :param pattern: Lua pattern string.
    :type pattern: String
    :rtype: String

.. function:: IOSimple:read_bytes(num_bytes)

    Read the given number of bytes.

    :param num_bytes: The amount of bytes to read.
    :type num_bytes: Number
    :rtype: String

.. function:: IOSimple:read_until_close()

    Reads all data from the socket until it is closed.

    :rtype: String

.. function:: IOSimple:write(data)

    Write the given data to this stream. Returns when the data has been written
    to socket.

.. function:: IOSimple:close()
    
    Close this stream and its socket.

.. function:: IOSimple:get_iostream()

    Returns the IOStream instance used by the IOSimple instance.
    
    :rtype: ``IOStream object``