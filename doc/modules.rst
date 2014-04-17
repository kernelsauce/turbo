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
