.. _httputil:

*************************************************
turbo.httputil -- Utilities for the HTTP protocol
*************************************************

The httputil namespace contains the HTTPHeader class and POST data parsers, which is a integral part of the HTTPServer class.

HTTPHeaders class
~~~~~~~~~~~~~~~~~
Used to compile and parse HTTP headers. Parsing is done through the Joyent Node HTTP parser via FFI. It is based on the nginx parser. It is
very fast and contains various protection against attacks. The .so is compiled when Turbo is installed with ``make install``.
Note that this class has sanity checking for input parameters. If they are of wrong type or contains bad data they will raise a error.

.. function :: HTTPHeaders(header_string)

    Create a new HTTPHeaders class instance.
    
    :param header_string: (optional) Raw header, up until double CLRF, if you want the class to parse headers on construction
    :type header_string: String
    :rtype: HTTPHeaders object
    
.. function :: HTTPHeaders:get_url_field(UF_prop)
    
    Get specified URL segment. If segment does not exist, -1 is returned. Parameter is either: ``turbo.httputil.UF.SCHEMA``,
    ``turbo.httputil.UF.HOST``, ``turbo.httputil.UF.PORT``, ``turbo.httputil.UF.PATH``, ``turbo.httputil.UF.PATH``,
    ``turbo.httputil.QUERY``, ``turbo.httputil.UF.FRAGMENT`` or ``turbo.httputil.UF.USERINFO``
    
    :param UF_prop: Segment to return, values defined in ``turbo.httputil.UF``.
    :type UF_prop: Number
    :rtype: String or Number on error (-1)
    
.. function :: HTTPHeaders:set_uri(uri)

    Set URI.
    
    :param uri: URI string to set.
    :type uri: String
    
.. function :: HTTPHeaders:get_uri()

    Get URI.
    
    :rtype: String or nil
    
.. function :: HTTPHeaders:set_content_length(len)

    Set Content-Length key.
    
    :param len: Length to set.
    :type len: Number
    
.. function :: HTTPHeaders:get_content_length()

    Get Content-Length key.
    
    :rtype: Number or nil
    
.. function :: HTTPHeaders:set_method(method)
    
    Set URL request method. E.g "POST" or "GET".
    
    :param method: Method to set.
    :type method: String
    
.. function :: HTTPHeaders:get_method()

    Get current URL request method.
    
    :rtype: String or nil
    
.. function :: HTTPHeaders:set_version(version)

    Set HTTP protocol version.
    
    :param version: Version string to set.
    :type version: String
    
.. function :: HTTPHeaders:get_version()
    
    Get current HTTP protocol version.
    
    :rtype: String or nil
    
.. function :: HTTPHeaders:set_status_code(code)

    Set HTTP status code. The code is validated against all known.
    
    :param code: The code to set.
    :type code: Number
    
.. function :: HTTPHeaders:get_status_code()

    Get the current HTTP status code.
    
    :rtype: Number or nil
    
.. function :: HTTPHeaders:get_argument(name)

    Get a argument from the query section of parsed URL. (e.g ?param1=myvalue)
    Note that this method only gets one argument. If there are multiple arguments with same name
    use ``HTTPHeaders:get_arguments()``
    
    :param name: The name of the argument.
    :type name: String
    :rtype: String or nil
    
.. function :: HTTPHeaders:get_arguments()

    Get all URL query arguments in a table. Support multiple values with same name.
    
    :rtype: Table
    
.. function :: HTTPHeaders:get(key)

    Get given key's current value from headers.
    
    :param key: Value to get, e.g "Content-Encoding".
    :type key: String
    :rtype: String    
    
.. function :: HTTPHeaders:add(key, value)
    
    Add a key value pair to headers. Will not overwrite existing keys, use ``HTTPHeaders:set()`` for that.
    
    :param key: The key to set.
    :type key: String
    :param value: The value to set.
    :type value: String
    
.. function :: HTTPHeaders:set(key, value)

    Set a key value to headers. Will overwrite existing key.
    
    :param key: The key to set.
    :type key: String
    :param value: The value to set.
    :type value: String
    
.. function :: HTTPHeaders:remove(key)
    
    Remove a key value combination from the headers.
    
    :param key: Key to remove.
    :type key: String
    
.. function :: HTTPHeaders:update(raw_headers)

    Parse raw HTTP headers and fill the current headers with the data.
    
    :param raw_headers: Raw HTTP header string, up to and including double CRLF.
    :type raw_headers: String
    
.. function :: HTTPHeaders:__tostring()

    Convert the current HTTP headers object to string format.
    
    :rtype: String