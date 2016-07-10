.. _web:

*******************************
turbo.web -- Core web framework
*******************************

The Turbo.lua Web framework is modeled after the framework offered by
Tornado (http://www.tornadoweb.org/), which again is based on web.py (http://webpy.org/) and
Google's webapp (http://code.google.com/appengine/docs/python/tools/webapp/)
Some modifications has been made to make it fit better into the Lua
eco system. The web framework utilizes asynchronous features that allow it
to scale to large numbers of open connections (thousands). The framework support
comet polling.

Create a web server that listens to port 8888 and prints the canoncial Hello world on
a GET request is very easy:

.. code-block:: lua
   :linenos:

	local turbo = require('turbo')

	local ExampleHandler = class("ExampleHandler", turbo.web.RequestHandler)
	function ExampleHandler:get()
		self:write("Hello world!")
	end

	local application = turbo.web.Application({
		{"^/$", ExampleHandler}
	})
	application:listen(8888)
	turbo.ioloop.instance():start()


RequestHandler class
~~~~~~~~~~~~~~~~~~~~
Base RequestHandler class. The heart of Turbo.lua.
The usual flow of using Turbo.lua is sub-classing the RequestHandler
class and implementing the HTTP request methods described in
self.SUPPORTED_METHODS. The main goal of this class is to wrap a HTTP
request and offer utilities to respond to the request. Requests are
deligated to RequestHandler's by the Application class.
The RequestHandler class are implemented so that it should be subclassed to process HTTP requests.

It is possible to modify self.SUPPORT_METHODS to add support for more methods if that is wanted.

Entry points
------------

.. function:: RequestHandler:on_create(kwargs)

	Redefine this method if you want to do something straight after the class
	has been initialized. This is called after a request has been
	received, and before the HTTP method has been verified against supported
	methods. So if a not supported method is requested, this method is still
	called.

        :param kwargs: The keyword arguments that you initialize the class with.
        :type kwargs: Table

.. function:: RequestHandler:prepare()

	Redefine this method if you want to do something after the class has been
	initialized. This method unlike on_create, is only called if the method has
	been found to be supported.

.. function:: RequestHandler:on_finish()

	Called after the end of a request. Useful for e.g a cleanup routine.

.. function:: RequestHandler:set_default_headers()

	Redefine this method to set HTTP headers at the beginning of all the
	request received by the RequestHandler. For example setting some kind
	of cookie or adjusting the Server key in the headers would be sensible
	to do in this method.

*Subclass RequestHandler and implement any of the following methods to handle
the corresponding HTTP request.
If not implemented they will provide a 405 (Method Not Allowed).
These methods receive variable arguments, depending on what the Application
instance calling them has captured from the pattern matching of the request
URL. The methods are run protected, so they are error safe. When a error
occurs in the execution of these methods the request is given a
500 Internal Server Error response. In debug mode, the stack trace leading
to the crash is also a part of the response. If not debug mode is set, then
only the status code is set.*

.. function:: RequestHandler:get(...)

	HTTP GET reqests handler.

        :param ...: Parameters from matched URL pattern with braces. E.g /users/(.*)$ would provide anything after /users/ as first parameter.

.. function:: RequestHandler:post(...)

	HTTP POST reqests handler.

        :param ...: Parameters from matched URL pattern with braces.

.. function:: RequestHandler:head(...)

	HTTP HEAD reqests handler.

        :param ...: Parameters from matched URL pattern with braces.

.. function:: RequestHandler:delete(...)

	HTTP DELETE reqests handler.

        :param ...: Parameters from matched URL pattern with braces.

.. function:: RequestHandler:put(...)

	HTTP PUT reqests handler.

        :param ...: Parameters from matched URL pattern with braces.

.. function:: RequestHandler:options(...)

	HTTP OPTIONS reqests handler.

        :param ...: Parameters from matched URL pattern with braces.

Input
-----

.. function:: RequestHandler:get_argument(name, default, strip)

	Returns the value of the argument with the given name.
	If default value is not given the argument is considered to be required and
	will result in a raise of a HTTPError 400 Bad Request if the argument does
	not exist.

	:param name: Name of the argument to get.
	:type name: String
	:param default: Optional fallback value in case argument is not set.
	:type default: String
	:param strip: Remove whitespace from head and tail of string.
	:type strip: Boolean
	:rtype: String

.. function:: RequestHandler:get_arguments(name, strip)

	Returns the values of the argument with the given name. Should be used when you expect multiple arguments values with same name. Strip will take away whitespaces at head and tail where 		applicable. Returns a empty table if argument does not exist.

	:param name: Name of the argument to get.
	:type name: String
	:param strip: Remove whitespace from head and tail of string.
	:type strip: Boolean
	:rtype: Table

.. function:: RequestHandler:get_json(force)

	Returns JSON request data as a table. By default, it only parses request with "application/json" as content-type header.

	:param force: If force is set to true, all request will be parsed regardless of content-type header.
	:type force: Boolean
	:rtype: Table or nil

.. function :: RequestHandler:get_cookie(name, default)

	Get cookie value from incoming request.

	:param name: The name of the cookie to get.
	:type name: String
	:param default: A default value if no cookie is found.
	:type default: String
	:rtype: String or nil if not found

.. function :: RequestHandler:get_secure_cookie(name, default, max_age)

	Get a signed cookie value from incoming request.

	If the cookie can not be validated, then an error with a string error
	is raised.

	Hash-based message authentication code (HMAC) is used to be able to verify
	that the cookie has been created with the "cookie_secret" set in the
	Application class kwargs. This is simply verifing that the cookie has been
	signed by your key, IT IS NOT ENCRYPTING DATA.

	:param name: The name of the cookie to get.
	:type name: String
	:param default: A default value if no cookie is found.
	:type default: String
	:param max_age: Timestamp used to sign cookie must be not be older than this value in seconds.
	:type max_age: Number
	:rtype: String or nil if not found

.. function :: RequestHandler:set_cookie(name, value, domain, expire_hours)

	Set a cookie with value to response.

	Note: Expiring relies on the requesting browser and may or may not be respected. Also keep in mind that the servers time is used to calculate expiry date, so the server should ideally be set up with NTP server.

	:param name: The name of the cookie to set.
	:type name: String
	:param value: The value of the cookie:
	:type value: String
	:param domain: The domain to apply cookie for.
	:type domain: String
	:param expire_hours: Set cookie to expire in given amount of hours.
	:type expire_hours: Number

.. function :: RequestHandler:set_secure_cookie(name, value, domain, expire_hours)

	Set a signed cookie value to response.

	Hash-based message authentication code (HMAC) is used to be able to verify
	that the cookie has been created with the "cookie_secret" set in the
	Application class kwargs. This is simply verifing that the cookie has been
	signed by your key, IT IS NOT ENCRYPTING DATA.

	Note: Expiring relies on the requesting browser and may or may not be respected. Also keep in mind that the servers time is used to calculate expiry date, so the server should ideally be set up with NTP server.

	:param name: The name of the cookie to set.
	:type name: String
	:param value: The value of the cookie:
	:type value: String
	:param domain: The domain to apply cookie for.
	:type domain: String
	:param expire_hours: Set cookie to expire in given amount of hours.
	:type expire_hours: Number

:RequestHandler.request:

	``turbo.httpserver.HTTPRequest`` class instance for this request. This object contains e.g ``turbo.httputil.HTTPHeader`` and the body payload etc. See the documentation for the classes for more details.

Output
------

.. function:: RequestHandler:write(chunk)

	Writes the given chunk to the output buffer.
	To write the output to the network, call the ``turbo.web.RequestHandler:flush()`` method.
	If the given chunk is a Lua table, it will be automatically
	stringifed to JSON.

        :param chunk: Data chunk to write to underlying connection.
        :type chunk: String

.. function:: RequestHandler:finish(chunk)

	Finishes the HTTP request. This method can only be called once for each
	request. This method flushes all data in the write buffer.

        :param chunk: Final data to write to stream before finishing.
        :type chunk: String

.. function:: RequestHandler:flush(callback)

	Flushes the current output buffer to the IO stream.

	If callback is given it will be run when the buffer has
	been written to the socket. Note that only one callback flush
	callback can be present per request. Giving a new callback
	before the pending has been run leads to discarding of the
	current pending callback. For HEAD method request the chunk
	is ignored and only headers are written to the socket.

        :param callback: Function to call after the buffer has been flushed.
        :type callback: Function

.. function:: RequestHandler:clear()

	Reset all headers, empty write buffer in a request.

.. function:: RequestHandler:add_header(name, value)

	Add the given name and value pair to the HTTP response headers.

        :param name: Key string for header field.
        :type name: String
        :param value: Value for header field.
        :type value: String

.. function:: RequestHandler:set_header(name, value)

	Set the given name and value pair of the HTTP response headers. If name exists then the value is overwritten.

        :param name: Key string for header field.
        :type name: String
        :param value: Value for header field.
        :type value: String

.. function:: RequestHandler:get_header(name)

	Returns the current value of the given name in the HTTP response headers. Returns nil if not set.

        :param name: Name of value to get.
        :type name: String
        :rtype: String or nil

.. function:: RequestHandler:set_status(code)

	Set the status code of the HTTP response headers. Must be number or error is raised.

	:param code: HTTP status code to set.
	:type code: Number

.. function:: RequestHandler:get_status()

	Get the curent status code of the HTTP response headers.

	:rtype: Number

.. function:: RequestHandler:redirect(url, permanent)

	Redirect client to another URL. Sets headers and finish request. User can not send data after this.

	:param url: The URL to redirect to.
	:type url: String
	:param permanent: Flag this as a permanent redirect or temporary.
	:type permanent: Boolean

Misc
----

.. function:: RequestHandler:set_async(bool)

	Set handler to not call finish() when request method has been called and
	returned. Default is false. When set to true, the user must explicitly call
	finish.

	:param bool:
	:type bool: Boolean

HTTPError class
~~~~~~~~~~~~~~~
This error is raisable from RequestHandler instances. It provides a
convinent and safe way to handle errors in handlers. E.g it is allowed to
do this:

.. code-block:: lua
   :linenos:

	function MyHandler:get()
	    local item = self:get_argument("item")
	     if not find_in_store(item) then
	         error(turbo.web.HTTPError(400, "Could not find item in store"))
	     end
	     ...
	end

The result is that the status code is set to 400 and the message is sent as
the body of the request. The request is always finished on error.

.. function:: HTTPError(code, message)

	Create a new HTTPError class instance.

	:param code: The HTTP status code to send to send to client.
	:type code: Number
	:param message: Optional message to pass as body in the response.
	:type message: String


StaticFileHandler class
~~~~~~~~~~~~~~~~~~~~~~~
A static file handler for files on the local file system.
All files below user defined ``_G.TURBO_STATIC_MAX`` or default 1MB in size
are stored in memory after initial request. Files larger than this are read
from disk on demand. If TURBO_STATIC_MAX is set to -1 then cache is disabled.

Usage:

.. code-block:: lua

	local app = turbo.web.Application:new({
		{"^/$", turbo.web.StaticFileHandler, "/var/www/index.html"},
		{"^/(.*)$", turbo.web.StaticFileHandler, "/var/www/"}
	})

Paths are not checked until intial hit on handler. The file is then cached in memory if it is a valid path.
Notice that paths postfixed with / indicates that it should be treated as a directory. Paths with no / is treated
as a single file.

RedirectHandler class
~~~~~~~~~~~~~~~~~~~~~
A simple redirect handler that simply redirects the client to the given
URL in 3rd argument of a entry in the Application class's routing table.

.. code-block:: lua

	local application = turbo.web.Application({
	    {"^/redirector$", turbo.web.RedirectHandler, "http://turbolua.org"}
	})

Application class
~~~~~~~~~~~~~~~~~
The Application class is a collection of request handler classes that make together up a web application. Example:

.. code-block:: lua
   :linenos:

	local application = turbo.web.Application({
		{"^/static/(.*)$", turbo.web.StaticFileHandler, "/var/www/"},
		{"^/$", ExampleHandler},
		{"^/item/(%d*)", ItemHandler}
	})

The constructor of this class takes a "map" of URL patterns and their respective handlers. The third element in the table are optional parameters the handler class might have.
E.g the ``turbo.web.StaticFileHandler`` class takes the root path for your static handler. This element could also be another table for multiple arguments.

The first element in the table is the URL that the application class matches incoming request with to determine how to serve it. These URLs simply be a URL or a any kind of Lua pattern.

The ItemHandler URL pattern is an example on how to map numbers from URL to your handlers. Pattern encased in parantheses are used as parameters when calling the request methods in your handlers.

*Note: Patterns are matched in a sequential manner. If a request matches multiple
handler pattern's only the first handler matched is delegated the request. Therefore, it is important to write good patterns.*

A good read on Lua patterns matching can be found here: http://www.wowwiki.com/Pattern_matching.

.. function:: Application(handlers, kwargs)

	Initialize a new Application class instance.

	:param handlers: As described above. Table of tables with pattern to handler binding.
	:type handlers: Table
	:param kwargs: Keyword arguments
	:type kwargs: Table

	Keyword arguments supported:

	* "default_host" (String) - Redirect to this URL if no matching handler is found.
	* "cookie_secret" (String) - Sequence of bytes used to sign secure cookies.

.. function:: Application:add_handler(pattern, handler, arg)

	Add handler to Application.

	:param pattern: Lua pattern string.
	:type pattern: String
	:param handler:
	:type handler: RequestHandler based class
	:param arg: Argument for handler.

.. function:: Application:listen(port, address, kwargs)

	Starts an HTTP server for this application on the given port.
	This is really just a convinence method. The same effect can be achieved
	by creating a ``turbo.httpserver.HTTPServer`` class instance and assigning the Application instance to its request_callback parameter and calling its listen()
	method.

	:param port: Port to bind server to.
	:type port: Number
	:param address: Address to bind server to. E.g "127.0.0.1".
	:type address: String or number.
	:param kwargs: Keyword arguments passed on to ``turbo.httpserver.HTTPServer``. See documentation for available options. This is used to set SSL certificates amongst other things.
	:type kwargs: Table

.. function:: Application:set_server_name(name)

	Sets the name of the server. Used in the response headers.

	:param name: The name used in HTTP responses. Default is "Turbo vx.x"
	:type name: String

.. function:: Application:get_server_name()

	Gets the current name of the server.
	:rtype: String


Mustache Templating
~~~~~~~~~~~~~~~~~~~

Turbo.lua has a small and very fast Mustache parser built-in. Mustache templates
are logic-less templates, which are supposed to help you keep your business logic
outside of templates and inside "controllers". It is widely known by Javascript
developers and very simple to understand.

For more information on the Mustache markup, please see this:
http://mustache.github.io/mustache.5.html

.. function:: Mustache.compile(template)

    Compile a Mustache highlighted string into its intermediate state before rendering. This function does some validation on the template. If it finds
    syntax errors a error with a message is raised. It is always a good idea to cache pre-compiled frequently used templates before rendering them. Although
    compiling each time is usally not a big overhead. This function can throw errors if the template contains invalid logic.

    :param template: (String) Template in string form.
    :rtype: Parse table that can be used for Mustache.render function

.. function:: Mustache.render(template, obj, partials, allow_blank)

    Render a template. Accepts a parse table compiled by Mustache.compile or a uncompiled string. Obj is the table with keys. This function can throw errors in
    case of un-compiled string being compiled with Mustache.compile internally.

    :param template: Accepts a pre-compiled template or a un-compiled string.
    :param obj: Parameters for template rendering.
    :type obj: Table
    :param partials: Partial snippets. Will be treated as static and not compiled...
    :type partials: Table
    :param allow_blank: Halt with error if key does not exist in object table.

Example templating:

.. code-block:: html
   :linenos:

    <body>
        <h1>
                {{heading }}
        </h1>
        {{!
            Some comment section that
            even spans across multiple lines,
            that I just have to have to explain my flawless code.
        }}
        <h2>
            {{{desc}}} {{! No escape with triple mustaches allow HTML tags! }}
            {{&desc}} {{! No escape can also be accomplished by & char }}
        </h2>
        <p>I am {{age}} years old. What would you like to buy in my shop?</p>
        {{  #items }}  {{! I like spaces alot! 		}}
            Item: {{item}}
            {{#types}}
                    {{! Only print items if available.}}
                    Type available: {{type}}
            {{/types}}
            {{^types}}	Only one type available.
            {{! Apparently only one type is available because types is not set,
            determined by the hat char ^}}
            {{/types}}
        {{/items}}
        {{^items}}
                No items available!
        {{/items}}
    </body>

With a render table likes this:

.. code-block:: lua

    {
        heading="My website!",
        desc="<b>Big important website</b>",
        age=27,
        items={
                  {item="Bread",
                      types={
                          {type="light"},
                          {type="fatty"}
                      }
              },
              {item="Milk"},
              {item="Sugar"}
       }
    }

Will produce this output after rendering:

.. code-block:: html

    <body>
        <h1>
            My%20website%21
        </h1>
        <h2>
            <b>Big important website</b>
            <b>Big important website</b>
        </h2>
        <p>I am 27 years old. What would you like to buy in my shop?</p>
            Item: Bread
                Type available: light
                Type available: fatty
            Item: Milk
                Only one type available.
            Item: Sugar
                Only one type available.
    </body>

Mustache.TemplateHelper class
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A simple class that simplifies the loading of Mustache templates, pre-compile and cache them for future use.

.. function:: Mustache.TemplateHelper(base_path)

    Create a new TemplateHelper class instance.

    :param base_path: Template base directory. This will be used as base path when loading templates using the load method.
    :type base_path: String
    :rtype: ``Mustache.TemplateHelper class``

.. function:: Mustache.TemplateHelper:load(template)

    Pre-load a template.

    :param template: Template name, e.g file name in base directory.
    :type template: String

.. function:: Mustache.TemplateHelper:render(template, table, partials, allow_blank)

    Render a template by name. If called twice the template will be cached from first time.

    :param template: Template name, e.g file name in base directory.
    :type template: String
    :param obj: Parameters for template rendering.
    :type obj: Table
    :param partials: Partial snippets. Will be treated as static and not compiled...
    :type partials: Table
    :param allow_blank: Halt with error if key does not exist in object table.
