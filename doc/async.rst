.. _async:

***********************************
turbo.async -- Asynchronous clients
***********************************

Utilities for coroutines
~~~~~~~~~~~~~~~~~~~~~~~~

.. function:: task(func, ...)

	A wrapper for functions that always takes callback and callback
	argument as last arguments to be able to yield and resume execution of
	function when callback is called from another function.

	No callbacks required, the arguments that would normally be used to
	call the callback is put in the left-side result.

	Usage:
	Consider one of the functions of the IOStream class which uses a
	callback based API: IOStream:read_until(delimiter, callback, arg)

.. code-block:: lua
	:linenos:

	local res = coroutine.yield(turbo.async.task(
		stream.read_until, stream, "\r\n"))

	-- Result from read_until operation will be returned in the res variable.


A HTTP(S) client - HTTPClient class
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Based on the IOStream/SSLIOStream and IOLoop classes.
Designed to asynchronously communicate with a HTTP server via the Turbo I/O
Loop. The user MUST use Lua's builtin coroutines to manage yielding, after
doing a request. The aim for the client is to support as many standards of
HTTP as possible. However there may be some artifacts as there usually are
many compability fixes in equivalent software such as curl.
Websockets are not handled by this class. It is the users responsibility to
check the returned values for errors before usage.

When using this class, keep in mind that it is not supported to launch
muliple :fetch()'s with the same class instance. If the instance is already
in use then it will return a error.

Usage inside a ``turbo.web.RequestHandler`` method:

.. code-block:: lua
   :linenos:

	local res = coroutine.yield(
	   	turbo.async.HTTPClient():fetch("http://domain.com/latest"))
	if res.error then
		self:write("Could not get latest from domain.come")
	else
		self:write(res.body)
	end

.. function:: HTTPClient(ssl_options, io_loop, max_buffer_size)

	Create a new HTTPClient class instance. One instance can serve 1 request
	at a time. If multiple request should be sent then create multiple instances.

	:param ssl_options: SSL keys, verify certificate, CA path etc.
	:type ssl_options: Table
	:param io_loop: Provide a IOLoop instance or global instance is used.
	:type io_loop: IOLoop class instance.
	:param max_buffer_size: Maximum response buffer size in bytes.
	:type max_buffer_size: Number

	Available SSL options:

	* ``priv_file`` (String) - Path to SSL / HTTPS private key file.
	* ``cert_file`` (String) - Path to SSL / HTTPS certificate key file.
	* ``ca_path`` (String) - Path to SSL / HTTPS CA certificate verify location, if not given builtin is used, which is copied from Ubuntu 12.10.
	* ``verify_ca`` (Boolean) SSL / HTTPS verify servers certificate. Default is true.

.. attribute::	errors

	Numeric error codes set in the HTTPResponse returned by ``HTTPClient:fetch``:

	    ``INVALID_URL``            - URL could not be parsed.

	    ``INVALID_SCHEMA``         - Invalid URL schema

	    ``COULD_NOT_CONNECT``      - Could not connect, check message.

	    ``PARSE_ERROR_HEADERS``    - Could not parse response headers.

	    ``CONNECT_TIMEOUT``        - Connect timed out.

	    ``REQUEST_TIMEOUT``        - Request timed out.

	    ``NO_HEADERS``             - Shouldn't happen.

	    ``REQUIRES_BODY``          - Expected a HTTP body, but none set.

	    ``INVALID_BODY``           - Request body is not a string.

	    ``SOCKET_ERROR``           - Socket error, check message.

	    ``SSL_ERROR``              - SSL error, check message.

	    ``BUSY``              	   - Operation in progress.

	    ``REDIRECT_MAX``		   - Redirect maximum reached.

.. function:: HTTPClient:fetch(url, kwargs)

	:param url: URL to fetch.
	:type url: String
	:param kwargs: Keyword arguments
	:type kwargs: Table
	:rtype: ``turbo.coctx.CoroutineContext`` class instance. Resumes coroutine with ``turbo.async.HTTPResponse``.

	Available keyword arguments:

	* ``method`` - The HTTP method to use. Default is ``GET``
	* ``params`` - Provide parameters as table.
	* ``keep_alive`` - Reuse connection if scenario supports it.
	* ``cookie`` - The cookie to use.
	* ``http_version`` - Set HTTP version. Default is HTTP1.1
	* ``use_gzip`` - Use gzip compression. Default is true.
	* ``allow_redirects`` - Allow or disallow redirects. Default is true.
	* ``max_redirects`` - Maximum redirections allowed. Default is 4.
	* ``on_headers`` - Callback to be called when assembling request HTTPHeaders instance. Called with ``turbo.httputil.HTTPHeaders`` as argument.
	* ``body`` - Request HTTP body in plain form.
	* ``request_timeout`` - Total timeout in seconds (including connect) for request. Default is 60 seconds.
	* ``connect_timeout`` - Timeout in seconds for connect. Default is 20 secs.
	* ``auth_username`` - Basic Auth user name.
	* ``auth_password`` - Basic Auth password.
	* ``user_agent`` - User Agent string used in request headers. Default is ``Turbo Client vx.x.x``.

HTTPResponse class
~~~~~~~~~~~~~~~~~~
Represents a HTTP response by a few attributes. Returned by ``turbo.async.HTTPClient:fetch``.

	:error: (Table) Table with code and message members. Possible codes is defined in ``async.errors``. Always check if the error attribute is set, before trying to access others. If error is set, then all of the other attributes, except request_time is nil.
	:request: (HTTPHeaders class instance) The request header sent to the server.
	:code: (Number) The HTTP response code
	:headers: (HTTPHeader class instance) Response headers received from the server.
	:body: (String) Body of response
	:url: (String) The URL that was used for final resource.
	:request_time: (Number) msec used to process request.
