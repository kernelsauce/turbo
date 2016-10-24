.. _util:

***************************
turbo.util Common utilities
***************************

The util namespace contains various convinience functions that fits no where else. As Lua is fairly naked as standard. Just the way we like it.

Table tools
-----------

.. function:: strsplit(str, sep, max, pattern)

	Split a string into a table on given seperator. This function extends the standard string library with new functionality.

	:param str: String to split
	:type str: String
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

.. function:: tablemerge(t1, t2)

	Merge two tables together.

	:param t1: First table.
	:type t1: Table
	:param t2: Second table.
	:type t2: Table
	:rtype: Table

Low level
---------

.. function:: mem_dump(ptr, sz)

	Dump memory region to stdout, from ptr to given size. Usefull for debugging Luajit FFI.
	Notice! This can and will cause a SIGSEGV if not being used on valid pointers.

	:param ptr: A cdata pointer (from FFI)
	:type ptr: cdata
	:param sz: Length to dump contents for.
	:type sz: Number

.. function:: TBM(x, m, y, n)

	Turbo Booyer-Moore memory search algorithm.
	Search through arbitrary memory and find first occurence of given byte sequence. Effective when looking
	for large needles in a large haystack.

	:param x: Needle memory pointer.
	:type x: char*
	:param m: Needle size.
	:type m: int
	:param y: Haystack memory pointer.
	:type y: char*
	:param n: Haystack size.
	:type n: int
	:rtype: First occurence of byte sequence in y defined in x or nil if not found.

Misc
----

.. function:: file_exists(name)

	Check if file exists on local filesystem.

	:param path: Full path to file.
	:type path: String
	:rtype: Boolean

.. function:: hex(num)

	Convert number value to hexadecimal string format.

	:param num: The number to convert.
	:type num: Number
	:rtype: String

.. function:: gettimeofday()

	Returns the current time in milliseconds precision. Unlike Lua builtin which only offers granularity in seconds.

	:rtype: Number

.. function:: gettimemonotonic()

	Returns milliseconds since arbitraty start point, doesn't jump due to time changes.

	:rtype: Number

