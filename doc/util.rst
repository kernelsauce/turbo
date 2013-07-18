.. _util:

***************************
turbo.util Common utilities
***************************

The util namespace contains various convinience functions that fits no where else. As Lua is fairly naked as standard. Just the way we like it.

.. function:: string:split(sep, max, pattern)

	Split a string into a table on given seperator. This function extends the standard string library with new functionality.
	
	:param sep: String that seperate elements.
	:type sep: String
	:param max: Max elements to split
	:type max: Number
	:param pattern: Separator should be treated as a Lua pattern. Slower.
	:type pattern: Boolean
	:rtype: Table
	
.. function:: join(delimiter, list)

	Join a table into a string.
	
	:param delimiter: Inserts this string between each table element.
	:type delimiter: String
	:param list: The table to join.
	:type list: Table
	:rtype: String
	
.. function:: is_in(needle, haystack)

	Search table for given element.
	
	:param needle: The needle to find.
	:type needle: Any that supports == operator.
	:param haystack: The haystack to search.
	:type haystack: Table
	
.. function:: hex(num)

	Convert number value to hexadecimal string format.
	
	:param num: The number to convert.
	:type num: Number
	:rtype: String
	
.. function:: mem_dump(ptr, sz)

	Dump memory region to stdout, from ptr to given size. Usefull for debugging Luajit FFI.
	Notice! This can and will cause a SIGSEGV if not being used on valid pointers.
	
	:param ptr: A cdata pointer (from FFI)
	:type ptr: cdata
	:param sz: Length to print hex chars for.
	:type sz: Number
	
.. function:: gettimeofday()

	Returns the current time in milliseconds precision.
	
	:rtype: Number
