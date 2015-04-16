.. _structs:

********************************
turbo.structs -- Data structures
********************************

Usefull data structures implemented using Lua and the LuaJIT FFI.

deque, Double ended queue
~~~~~~~~~~~~~~~~~~~~~~~~~~~

A deque can insert items at both the beginning and then end in constant time, "O(1)"
If you are going to insert things regurarly to the front it is wise to use this class instead of the
standard Lua table. Keep in mind that inserting to the back is still slower than a Lua table.

.. function:: deque()

	Create a new deque class instance.

	:rtype: Deque class instance

.. function:: deque:append(item)

	Append elements to tail.

.. function:: deque:appendleft(item)

	Append element to head.

.. function:: deque:peeklast()

	Returns element at tail.

.. function:: deque:peekfirst()

	Returns element at front.

.. function:: deque:pop()

	Removes element at tail and returns it.

.. function:: deque:popleft()

	Removes element at head and returns it.

.. function:: deque:not_empty()

	Check if deque is empty.

	:rtype: Boolean

.. function:: deque:size()

	Returns the amount of elements in the deque.

.. function:: deque:strlen()

	Find length of all elements in deque combined.
	(Only works if the elements have a :len() method)

.. function:: deque:concat()

	Concat elements in deque. Only works if the elements in the deque have a :__concat() method.

.. function:: deque:getn(pos)

	Get element at position.

	:rtype: Element or nil if not existing.


buffer, Low-level mutable buffer
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Can be used to replace plain Lua strings where it is of importance to not create temporary strings, and there
is little help in the Lua string interning. It is mutable and allows preallocations to be done on intialization.
The data stored in a buffer is not handled by the LuaJIT 2.0 GC which in turn circumvents the memory limit.

Keep in mind that this class i "low-level" and giving the wrong arguments to its methods may cause memory segmentation fault.
It is NOT protected.

.. function:: Buffer(size_hint)

	Create a new buffer. May raise error if there is not enough memory available.

	:param size_hint: The buffer is preallocated with this amount (in bytes) of storage.
	:type size_hint: Number
	:rtype: Buffer class instance.

.. function:: Buffer:append_right(data, len)

	Append data to buffer.
	Keep in mind that defining a length longer than the actual data, might lead to a segmentation fault.

	:param data: The data to append in char * form.
	:type data: char *
	:param len: The length of the data in bytes.
	:type len: Number

.. function:: Buffer:append_luastr_right(str)

	Append Lua string to buffer.

	:param str: The data to append.
	:type str: String

.. function:: Buffer:append_left(data, len)

	Prepend data to buffer.

	:param data: The data to prepend in char * form.
	:type data: char *
	:param len: The length of the data in bytes.
	:type len: Number

.. function:: Buffer:append_luastr_left(str)

	Prepend Lua string to the buffer.

	:param str: The data to prepend.
	:type str: String

.. function:: Buffer:pop_left(sz)

	Pop bytes from left side of buffer. If sz exceeds size of buffer then a error is raised. Note: does not release memory allocated.

	:param sz: Bytes to "pop".
	:type sz: Number

.. function:: Buffer:pop_right(sz)

	Pop bytes from right side of the buffer. If sz exceeds size of buffer then a error is raised. Note: does not release memory allocated.

	:param sz: Bytes to "pop".
	:type sz: Number

.. function:: Buffer:get()

	Get internal buffer pointer. Must be treated as a const value. Keep in mind that the internal pointer may or may not
	change when calling its methods.

	:rtype: Two values: const char * to data and current size in bytes.

.. function:: Buffer:copy()

	Create a "deep" copy of the buffer.

	:rtype: Buffer class instance

.. function:: Buffer:shrink()

	Shrink buffer memory (deallocate) usage to its minimum.

.. function:: Buffer:clear(wipe)

	Clear buffer. Note: does not release memory allocated.

	:param wipe: Optional switch to zero fill allocated memory range.
	:type wipe: Boolean

.. function:: Buffer:len()

	Get current size of the buffer.

	:rtype: Number. Size in bytes.

.. function:: Buffer:mem()

	Get the total number of bytes currently allocated to this instance.

	:rtype: Number. Bytes allocated.

.. function:: Buffer:__tostring()

	Convert to Lua type string using the tostring() builtin or implicit conversions.

.. function:: Buffer:__eq(cmp)

	Compare two buffers by using the == operator.

.. function:: Buffer:__concat(src)

	Concat by using the .. operator, Lua type strings can be concated also.
	Please note that all concatination involves deep copying and is slower than manually
	building a buffer with append methods.