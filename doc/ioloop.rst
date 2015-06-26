.. _ioloop:


*****************************
turbo.ioloop -- Main I/O Loop
*****************************

.. highlight:: lua

Single threaded I/O event loop implementation. The module handles socket
events and timeouts and scheduled intervals with millisecond precision

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

        Create or get the global IOLoop instance.
		Multiple calls to this function returns the same IOLoop.

        :rtype: IOLoop class.

IOLoop class
~~~~~~~~~~~~
IOLoop is a level triggered I/O loop, with additional support for timeout
and time interval callbacks. Heavily influenced by ioloop.py in the Tornado web framework.
*Note: Only one instance of IOLoop can ever run at the same time!*

.. function:: IOLoop()

        Create a new IOLoop class instance.

.. function:: IOLoop:add_handler(fd, events, handler, arg)

        Add handler function for given event mask on fd.

        :param fd: File descriptor to bind handler for.
        :type fd: Number
        :param events: Events bit mask. Defined in ioloop namespace. E.g ``turbo.ioloop.READ`` and ``turbo.ioloop.WRITE``. Multiple bits can be AND'ed together.
        :type events: Number
        :param handler: Handler function.
        :type handler: Function
        :param arg: Optional argument for function handler. Handler is called with this as first argument if set.
        :rtype: Boolean

.. function:: IOLoop:update_handler(fd, events)

        Update existing handler function's trigger events.

        :param fd: File descriptor to update.
        :type fd: Number
        :param events: Events bit mask. Defined in ioloop namespace. E.g ``turbo.ioloop.READ`` and ``turbo.ioloop.WRITE``. Multiple bits can be AND'ed together.
        :type events: Number

.. function:: IOLoop:remove_handler(fd)

        Remove a existing handler from the IO Loop.

        :param fd: File descriptor to remove handler from.
        :type fd: Number

.. function:: IOLoop:add_callback(callback, arg)

        Add a callback to be called on next iteration of the IO Loop.

        :param callback: A function to be called on next iteration.
        :type callback: Function
        :param arg: Optional argument for callback. Callback is called with this as first argument if set.
        :rtype: IOLoop class. Returns self for convinience.

.. function:: IOLoop:add_timeout(timestamp, func, arg)

        Add a timeout with function to be called in future. There is given no gurantees that the function will be called
        on time. See the note at beginning of this section.

        :param timestamp: Timestamp when to call function, based on Unix CLOCK_MONOTONIC time in milliseconds precision. E.g util.gettimemonotonic() + 3000 will timeout in 3 seconds. See ``turbo.util.gettimemonotonic()``.
        :type timestamp: Number
        :param func: A function to be called after timestamp is reached.
        :type func: Function
        :param arg: Optional argument for func.
        :rtype: Unique reference as a reference for this timeout. The reference can be used as parameter for ``IOLoop:remove_timeout()``

.. function:: IOLoop:remove_timeout(ref)

        Remove a scheduled timeout by using its reference.

        :param identifer: Identifier returned by ``IOLoop:add_timeout()``
        :type identifer: Number
        :rtype: Boolean

.. function:: IOLoop:set_interval(msec, func, arg)

        Add a function to be called every milliseconds. There is given no guarantees that the function will be called on time. See the note at beginning of this section.

        :param msec: Milliseconds interval.
        :type msec: Number
        :param func: A function to be called every msecs.
        :type func: Function
        :param arg: Optional argument for func.
        :rtype: Unique numeric identifier as a reference to this interval. The refence can be used as parameter for ``IOLoop:clear_interval()``

.. function:: IOLoop:clear_interval(ref)

        Clear a interval.

        :param ref: Reference returned by ``IOLoop:set_interval()``
        :type ref: Boolean

.. function:: IOLoop:add_signal_handler(signo, handler, arg)

        Add a signal handler. If handler already exists for signal it is overwritten. Calling of multiple functions should be
        handled by user.

        :param signo: The signal number(s) too handle.
        :type signo: (Number) Signal number, defined in turbo.signal, e.g turbo.signal.SIGINT.
        :param handler: Function to handle the signal.
        :type handler: Function
        :param arg: Optional argument for handler function.

.. function:: IOLoop:remove_signal_handler(signo)

        Remove a signal handler for specified signal number.

        :param signo: The signal number to remove.
        :type signo: (Number) Signal number, defined in turbo.signal, e.g turbo.signal.SIGINT.

.. function:: IOLoop:start()

        Start the IO Loop. The loop will continue running until ``IOLoop.close`` is called via a callback added.

.. function:: IOLoop:close()

        Close the I/O loop. This call must be made from within the running I/O loop via a  callback, timeout, or interval. Notice: All pending callbacks and handlers are cleared upon close.

.. function:: IOLoop:running()

        Is the IO Loop running?

        :rtype: Boolean
