.. _log:

************************************
turbo.log -- Command-line log helper
************************************

A simple log writer implementation with different levels and standard
formatting. Messages written is appended to level and timestamp. You
can turn off unwanted categories by modifiying the table at log.categories.

For messages shorter than 4096 bytes a static buffer is used to
improve performance. C time.h functions are used as Lua builtin's is
not compiled by LuaJIT. This statement applies to all log functions, except
log.dump.

Example output:
``[S 2013/07/15 18:58:03] [web.lua] 200 OK GET / (127.0.0.1) 0ms``

To enable or disable categories, modify the table in ``turbo.log.categories``.

As default, it is declared as such:

.. code-block:: lua

	log = {
	    ["categories"] = {
	        -- Enable or disable global log categories.
	        -- The categories can be modified at any time.
	        ["success"] = true,
	        ["notice"] = true,
	        ["warning"] = true,
	        ["error"] = true,
	        ["debug"] = true,
	        ["development"] = false
	    }
	}

.. function:: success(str)

	Log to stdout. Success category.
	Use for successfull events etc.
	Messages are printed with green color.

	:param str: Log string.
	:type str: String

.. function:: notice(str)

	Log to stdout. Notice category.
	Use for notices, typically non-critical messages to give a hint.
	Messages are printed with white color.

	:param str: Log string.
	:type str: String

.. function:: warning(str)

	Log to stderr. Warning category.
	Use for warnings.
	Messages are printed with yellow color.

	:param str: Log string.
	:type str: String

.. function:: error(str)

	Log to stderr. Error category.
	Use for critical errors, when something is clearly wrong.
	Messages are printed with red color.

	:param str: Log string.
	:type str: String

.. function:: debug(str)

	Log to stdout. Debug category.
	Use for debug messages not critical for releases.

	:param str: Log string.
	:type str: String

.. function:: devel(str)

	Log to stdout. Development category.
	Use for development purpose messages.
	Messages are printed with cyan color.

	:param str: Log string.
	:type str: String

.. function:: stringify(t, name, indent)

	Stringify Lua table.

	:param t: Lua table
	:type t: Table
	:param name: Optional identifier for table.
	:type name: String
	:param indent: Optional indent level.
	:type indent: Number
	:rtype: String