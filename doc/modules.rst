.. _modules:

Asynchronous modules
********************

Using native modules instead of generic Lua modules are important when using sockets to communicate with e.g databases
to get the best performance, since the generic modules will block during long operations. If the operations you are
doing are relatively fast then you may get away with using a generic module. This is something you have to benchmark yourself
in your specific cases.

Creating modules for Turbo using the highly abstracted IOStream classes is real easy. If there is not a driver for e.g a database
etc available then please do try to make it.

Overview
~~~~~~~~

There are many ways of implementing async modules in Turbo.lua. To list the most apparent:

* Using callbacks
* Using Coroutine wrappable functions
* Using Coroutines and the CoroutineContext class

Which one suits your module best is up to your. Know that at the time of writing, no functions within the Lua Coroutine namespace
is inlined by LuaJIT. Instead it fallbacks to the very fast interpreter. So if every little performance matters then callbacks
are the way to go. All of the modules in the core framework uses Coroutine wrappable functions, except the HTTPClient, which uses
coroutines and the CoroutineContext class.

Callback based modules is probably the flavour that most have used before. Basically you take in a callback
(and maybe a callback argument/userdata) as argument(s) for the functions of your module. This function is then called when I/O
has been completed. This means the user of your module must either split his program flow into seperate functions (seemingly in parts)
or create closures inside functions.

Coroutine wrappable functions means that the functions of your API strictly adhers to the convention where the last two arguments of a
functions always are a callback AND a callback argument (the argument is passed as first argument into the provided callback when it is
called on I/O completion). If, and only if these requirements are met, the users of your module may use the ``turbo.async.task`` function
to wrap the function and use the builtin Lua yield functionality. These functions then supports both callback-style and yield-style programming.

Coroutine directly with the CoroutineContext class does not offer a callback compatible API, and the users of the module must always yield
to the I/O loop. This has some advantages in that it creates a 100% "I don't care about this async stuff" environment.

Programmatically this can be illustrated as follows:

"I don't care about this async stuff" module:

.. code-block:: lua
   :linenos:

    local turbo = require "turbo"
    local turboredis = require "turbo-redis"
    local rconn = turboredis.connect("127.0.0.1", 1337)

    local ExampleHandler = class("ExampleHandler", turbo.web.RequestHandler)
    function ExampleHandler:get()
        self:write("The value is " .. rconn:get("myvalue"))
    end

    local application = turbo.web.Application({
        {"^/$", ExampleHandler}
    })
    application:listen(8888)
    turbo.ioloop.instance():start()

Callback-type module:

.. code-block:: lua
   :linenos:

    local turbo = require "turbo"
    local turboredis = require "turbo-redis"
    local rconn = turboredis.connect("127.0.0.1", 1337)

    local ExampleHandler = class("ExampleHandler", turbo.web.RequestHandler)
    function ExampleHandler:get()
        local _self = self
        rconn:get("myvalue", function(val)
            _self:write("The value is " .. rconn:get("myvalue"))
        end)
    end

    local application = turbo.web.Application({
        {"^/$", ExampleHandler}
    })
    application:listen(8888)
    turbo.ioloop.instance():start()

Callback-type module with callback argument and no closures, probably
well known for those familiar with Python and Tornado.

.. code-block:: lua
   :linenos:

    local turbo = require "turbo"
    local turboredis = require "turbo-redis"
    local rconn = turboredis.connect("127.0.0.1", 1337)

    function ExampleHandler:_process_request(data)
        self:write("The value is " .. data)
    end

    local ExampleHandler = class("ExampleHandler", turbo.web.RequestHandler)
    function ExampleHandler:get()
        rconn:get("myvalue", ExampleHandler._process_request, self)
    end

    local application = turbo.web.Application({
        {"^/$", ExampleHandler}
    })
    application:listen(8888)
    turbo.ioloop.instance():start()

Coroutine wrappable Callback-type module:

.. code-block:: lua
   :linenos:

    local turbo = require "turbo"
    local turboredis = require "turbo-redis"
    local task = turbo.async.task
    local yield = coroutine.yield

    local rconn = turboredis("127.0.0.1", 1337)

    local ExampleHandler = class("ExampleHandler", turbo.web.RequestHandler)
    function ExampleHandler:get()
        self:write("The value is " .. yield(task(turboredis.get(rconn, "myvalue"))))
    end

    local application = turbo.web.Application({
        {"^/$", ExampleHandler}
    })
    application:listen(8888)
    turbo.ioloop.instance():start()

The easiest to use is probably the first, where the program flow and code paths are more easily
followed. The builtin HTTPClient uses this style of API... It is probably also a good choice for
database queries etc, so you can keep your logic clean and easy to follow.

All callbacks added to the I/O loop are executed in its own coroutine. The callback functions can yield
execution back to the I/O loop. Lua yield's can return a object as it return to where the coroutine where
started... This is utilized in the Turbo.lua I/O loop which will treat yields different based on what they
return as they yield. The I/O Loop supports these returns:

* A function, that will be called on next iteration and its results returned when resuming the coroutine thread.
* Nil, a empty yield that will simply resume the coroutine thread on next iteration.
* A CoroutineContext class, which acts as a reference to the I/O loop which allow the coroutine thread to be
  managed manually and resumed on demand.

Example module
~~~~~~~~~~~~~~


So bearing this in mind let us create a CouchDB module.

We will create this one with a API that supports the business as usual programming style where the programmer does
not yield or control this flow by himself. Note that this is in no way a complete and stable module, it is only
meant to give some pointers:

.. code-block:: lua
   :linenos:

    local turbo = require "turbo"

    -- Create a namespace to return.
    local couch = {}

    -- CouchDB class, it is obviously optional if you want to use object orientation or not.
    couch.CouchDB = class("CouchDB")


    -- Init function to setup connection to CouchDB and more.
    function couch.CouchDB:initialize(addr, ioloop)
        assert(type(addr) == "string", "addr argument is not a valid address.")
        self.ioloop = ioloop
        local sock, msg = turbo.socket.new_nonblock_socket(
            turbo.socket.AF_INET,
            turbo.socket.SOCK_STREAM,
            0)
        if sock == -1 then
            error("Could not create socket.")
        end
        self.sock = sock

        self.iostream = turbo.iostream.IOStream(
            self.sock,
            self.io_loop,
            1024*1024)

        local hostname, port = unpack(util.strsplit(addr, ":"))
        self.hostname = hostname
        self.port = tonumber(port)
        self.connected = false
        self.busy = false
        local _self = self

        local rc, msg = self.iostream:connect(
            self.hostname,
            self.port,
            turbo.socket.AF_INET,
            function()
                -- Set a connected flag, so that we know we can process requests.
                _self.connected = true
                turbo.log.success("Couch Connected!") end,
            function() turbo.log.error("Could not connect to CouchDB!") end)
        if rc ~= 0 then
            error("Host not reachable. " .. msg or "")
        end
        self.iostream:set_close_callback(function()
            _self.connected = false
            turbo.log.error("CouchDB disconnected!")
            -- Add reconnect code here.
        end)
    end

    function couch.CouchDB:get(resource)
        assert(self.connected, "No connection to CouchDB, can not process request.")
        assert(not self.busy, "Connection is busy, try again later.")
        self.busy = true

        self.headers = turbo.httputil.HTTPHeaders()
        self.headers:add("Host", self.hostname)
        self.headers:add("User-Agent", "Turbo Couch")
        self.headers:set_method("GET")
        self.headers:set_version("HTTP/1.1")
        self.headers:set_uri(resource)
        local buf = self.headers:stringify_as_request()

        -- Write request HTTP header to stream and wait for finish using the simple way with turbo.async.task wrapper
        -- function.
        coroutine.yield (turbo.async.task(self.iostream.write, self.iostream, buf))

        -- Wait until end of HTTP response header has been read.
        local res = coroutine.yield (turbo.async.task(self.iostream.read_until_pattern, self.iostream, "\r?\n\r?\n"))

        -- Decode response header.
        local response_headers = turbo.httputil.HTTPParser(res, turbo.httputil.hdr_t["HTTP_RESPONSE"])

        -- Read the actual body now that we know the size of body.
        local body = coroutine.yield (turbo.async.task(
                self.iostream.read_bytes,
                self.iostream,
                tonumber((response_headers:get("Content-Length")))))

        -- Decode JSON response body and return it to caller.
        local json_dec = turbo.escape.json_decode(body)
        return json_dec
    end

    --- Add more methods :)

    return couch

Usage from a turbo.web.RequestHandler:

.. code-block:: lua
   :linenos:

    local turbo = require "turbo"
    local couch = require "turbo-couch"

    -- Create a instance.
    local cdb = couch.CouchDB("localhost:5984")

    local ExampleHandler = class("ExampleHandler", turbo.web.RequestHandler)
    function ExampleHandler:get()
        -- Write response directly through.
        self:write(cdb:get("/test/toms_resource"))
    end

    turbo.web.Application({{"^/$", ExampleHandler}}):listen(8888)
    turbo.ioloop.instance():start()