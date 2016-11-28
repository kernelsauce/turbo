***********************************************************
turbo.thread -- Threads with communications
***********************************************************

Thread class
~~~~~~~~~~~~
The Thread class is implemented with C fork, and allows the user to create 
a seperate thread that runs independently of the parent thread, but can
communicate with each other over a AF_UNIX socket. Useful for long and heavy
tasks that can not be yielded. Also useful for running shell commands etc.

.. code-block:: lua

    local turbo = require "turbo"

    turbo.ioloop.instance():add_callback(function()

        local thread = turbo.thread.Thread(function(th)
            th:send("Hello World.")
            th:stop()
        end)

        print(thread:wait_for_data())
        thread:wait_for_finish()
        turbo.ioloop.instance():close()

    end):start()

All functions may raise errors. All functions yield to the IOLoop internally. You may catch errors with xpcall or pcall. Make sure to do proper cleanup of threads not being used anymore, they are not automatically stopped and collected.

.. function:: Thread(func)

    Create a new thread. Start running in provided func. 

    :param func: Function to call when thread has been created. Function is called with the childs Thread object, which contains its own IOLoop e.g: "th.io_loop".
    :type stream: Function
    :rtype: ``Thread object``

.. function:: Thread:stop()

    Stop and cleanup pipe. Can be called from both parent and child thread.

.. function:: Thread:send(data)

    Called by either parent or child thread to send data to each other. If you are calling from parent thread, make sure to call wait_for_pipe() first.

    :param data: String to be sent.
    :type pattern: String

.. function:: Thread:wait_for_data()

    Wait for data to become available from other thread. May be called by parent or child thread.

    :param num_bytes: The amount of bytes to read.
    :type num_bytes: Number
    :rtype: String

.. function:: Thread:wait_for_finish()

    Wait for child process to stop itself and end thread.

.. function:: Thread:wait_for_pipe()

    Wait for thread pipe to be connected. Must be used by main thread before attempting to send data to child. Only callable from parent thread.

.. function:: IOSimple:get_pid()

    Get PID of child.
    
    :rtype: Number
