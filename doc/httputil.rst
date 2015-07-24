.. _httputil:

*************************************************
turbo.httputil -- Utilities for the HTTP protocol
*************************************************

The httputil namespace contains the HTTPHeader class and POST data parsers, which is a integral part of the HTTPServer class.


HTTPParser class
~~~~~~~~~~~~~~~~~
Used to parse HTTP headers. Parsing is done through Ryan Dahls HTTP Parser via the FFI. It is
very fast and contains various protection against attacks. The .so is compiled when Turbo is installed with ``make install``.
Note that this class has sanity checking for input parameters. If they are of wrong type or contains bad data they will raise a error.

.. function :: HTTPParser(hdr_str, hdr_t)

    Create a new HTTPParser class instance.

    hdr_t available:

    * ``turbo.httputil.hdr_t.HTTP_RESPONSE``,
    * ``turbo.httputil.hdr_t.HTTP_REQUEST``,
    * ``turbo.httputil.hdr_t.HTTP_BOTH``

    :param hdr_str: (optional) Raw header, including ending double CLRF, if you want the class to parse headers on construction.
    :type hdr_str: String
    :param hdr_t: (optional) If hdr_str is defined this should also be defined. It is used to specify what kind of header you want to parse.
    :type hdr_t: Number
    :rtype: HTTPParser object

.. function :: HTTPParser:get_url()

    Get URL.

    :rtype: String or nil

.. function :: HTTPParser:get_url_field(UF_prop)

    Get specified URL segment. If segment does not exist, nil is returned. Will throw error if no URL has been parsed.
    UF_prop available:

    * ``turbo.httputil.UF.SCHEMA``,
    * ``turbo.httputil.UF.HOST``,
    * ``turbo.httputil.UF.PORT``,
    * ``turbo.httputil.UF.PATH``,
    * ``turbo.httputil.UF.PATH``,
    * ``turbo.httputil.QUERY``,
    * ``turbo.httputil.UF.FRAGMENT``,
    * ``turbo.httputil.UF.USERINFO``

    :param UF_prop: Segment to return, values defined in ``turbo.httputil.UF``.
    :type UF_prop: Number
    :rtype: String or nil

.. function :: HTTPParser:parse_url(url)

    Parse standalone URL and populate class instance with values.  ``HTTPParser.get_url_field`` must be used to read out value.

    :param url: URL string.
    :type url: String

.. function :: HTTPParser:get_method()

    Get current URL request method.

    :rtype: String or nil

.. function :: HTTPParser:get_status_code()

    Get the current HTTP status code.

    :rtype: Number or nil

.. function :: HTTPParser:get(key, caseinsensitive)

    Get given key from header key value section.

    :param key: Value to get, e.g "Content-Encoding".
    :type key: String
    :param caseinsensitive: If true then the key will be matched without regard for case sensitivity.
    :type caseinsensitive: Boolean
    :rtype: The value of the key in String form, or nil if not existing. May return a table if multiple keys are set.

.. function :: HTTPParser:get_argument(name)

    Get a argument from the query section of parsed URL. (e.g ?param1=myvalue)
    Note that this method only gets one argument. If there are multiple arguments with same name
    use ``HTTPParser.get_arguments()``

    :param name: The name of the argument.
    :type name: String
    :rtype: String or nil

.. function :: HTTPParser:get_arguments()

    Get all URL query arguments of parsed URL. Support multiple values with same name.

    :rtype: Table

.. function :: HTTPParser:parse_response_header(raw_headers)

    Parse HTTP response headers. Populates the class with all data in headers. Will throw error on parsing failure.

    :param raw_headers: Raw HTTP response header in string form.
    :type raw_headers: String

.. function :: HTTPParser:parse_request_header(raw_headers)

    Parse HTTP request headers. Populates the class with all data in headers. Will throw error on parsing failure.

    :param raw_headers: Raw HTTP request header in string form.
    :type raw_headers: String

HTTPHeaders class
~~~~~~~~~~~~~~~~~
Used to compile HTTP headers.
Note that this class has sanity checking for input parameters. If they are of wrong type or contains bad data they will raise a error.

.. function :: HTTPHeaders()

    Create a new HTTPHeaders class instance.

    :rtype: HTTPHeaders object

Manipulation
------------

.. function :: HTTPHeaders:set_uri(uri)

    Set URI. Mostly usefull when building up request headers, NOT when parsing response headers. Parsing should be done with HTTPHeaders:parse_url.

    :param uri: URI string to set.
    :type uri: String

.. function :: HTTPHeaders:get_uri()

    Get current URI.

    :rtype: String or nil

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

.. function :: HTTPHeaders:get(key, caseinsensitive)

    Get given key from header key value section.

    :param key: Value to get, e.g "Content-Encoding".
    :type key: String
    :param caseinsensitive: If true then the key will be matched without regard for case sensitivity.
    :type caseinsensitive: Boolean
    :rtype: The value of the key in String form, or nil if not existing. May return a table if multiple keys are set.

.. function :: HTTPHeaders:add(key, value)

    Add a key with value to the headers. Supports adding multiple values to  one key. E.g mutiple "Set-Cookie" header fields.

    :param key: Key to add to headers. Must be string or error is raised.
    :type key: String
    :param value: Value to associate with the key.
    :type value: String

.. function :: HTTPHeaders:set(key, value, caseinsensitive)

    Set a key with value to the headers. Overwiting existing key.

    :param key: The key to set.
    :type key: String
    :param value: Value to associate with the key.
    :type value: String
    :param caseinsensitive: If true then the existing keys will be matched without regard for case sensitivity and overwritten.
    :type caseinsensitive: Boolean

.. function :: HTTPHeaders:remove(key, caseinsensitive)

    Remove a key value combination from the headers.

    :param key: Key to remove.
    :type key: String
    :param caseinsensitive: If true then the existing keys will be matched without regard for case sensitivity and overwritten.
    :type caseinsensitive: Boolean

Stringifiers
------------

.. function:: HTTPHeaders:stringify_as_request()

    Stringify data set in class as a HTTP request header.

    :rtype: String. HTTP header string excluding final delimiter.

.. function :: HTTPHeaders:stringify_as_response()

    Stringify data set in class as a HTTP response header.
    If not "Date" field is set, it will be generated automatically.

    :rtype: String. HTTP header string excluding final delimiter.

.. function :: HTTPHeaders:__tostring()

    Convinience method to return HTTPHeaders:stringify_as_response on string conversion.

    :rtype: String. HTTP header string excluding final delimiter.

Functions
~~~~~~~~~

.. function:: parse_multipart_data(data)

    Parse multipart form data.

    :param data: Multi-part form data in string form.
    :type data: String
    :rtype: Table of keys with corresponding values. Each key may hold multiple values if there were found multiple values for one key.

.. function:: parse_post_arguments(data)

    Parse ? and & separated key value fields.

    :param data: Form data in string form.
    :type data: String
    :rtype: Table of keys with corresponding values. Each key may hold multiple values if there were found multiple values for one key.
