.. _escape:

*****************************************
turbo.escape -- Escaping and JSON utilities
*****************************************

JSON conversion
---------------

.. function:: json_encode(t)

	JSON stringify a table. May raise a error if table could not be decoded.

	:param t: Value to JSON encode.
	:rtype: String

.. function:: json_decode(s)

	Decode a JSON string to table.

	:param s: JSON enoded string to decode into Lua primitives.
	:type s: String
	:rtype: Table

Escaping
--------

.. function:: unescape(s)

	Unescape a escaped hexadecimal representation string.

	:param s: String to unescape.
	:type s: String
	:rtype: String

.. function:: escape(s)

	Encodes a string into its escaped hexadecimal representation.

	:param s: String to escape.
	:type s: String
	:rtype: String

.. function:: html_escape(s)

	Encodes the HTML entities in a string. Helpfull to avoid XSS.

	:param s: String to escape.
	:type s: String
	:rtype: String

String trimming
---------------

.. function:: trim(s)

	Remove trailing and leading whitespace from string.

	:param s: String
	:rtype: String

.. function:: ltrim(s)

	Remove leading whitespace from string.

	:param s: String
	:rtype: String

.. function:: rtrim(s)

	Remove trailing whitespace from string.

	:param s: String
	:rtype: String
