.. _get_started:

************************
Get Started With Turbo
************************

A set of simple examples to get you started using Turbo.

Installing Turbo
================
Turbo needs LuaJIT to run, because it uses the LuaJIT FFI library it will not
run on 'official/normal/vanilla' Lua. Quick install on Debian/Ubuntu (you may need
to add sudo or run these as root user):

.. code-block:: sh

    $ apt-get install luajit luarocks git build-essential libssl-dev
    $ luarocks install turbo

You can also install Turbo use the included Makefile in the project source:


.. code-block:: sh

    $ git clone https://github.com/kernelsauce/turbo.git
    $ cd turbo && make install

You can provide a PREFIX argument to the make which will install Turbo in a specified directory. 

For Windows users it is recommended to use the included install.bat file or running the one-line command below from a administrative command line. Beware that this will compile and install all dependencies: Visual Studio, git, mingw, gnuwin, openssl using Chocolatey. LuaJIT, the LuaRocks package manager and Turbo will be installed at C:\\turbo.lua. Unfortunately it is required to have Visual Studio to effectively use LuaRocks on Windows. LuaRocks will be used to install LuaSocket and LuaFileSystem. The Windows environment will be ready to use upon success, and the luajit and luarocks commands will be in your Windows environment PATH.

.. code-block:: bat

    powershell -command "& { iwr https://raw.githubusercontent.com/kernelsauce/turbo/master/install.bat -OutFile t.bat }" && t.bat



Hello World
===========

The traditional and mandatory 'Hello World'

.. code-block:: lua

    -- Import turbo,
    local turbo = require("turbo")

    -- Create a new requesthandler with a method get() for HTTP GET.
    local HelloWorldHandler = class("HelloWorldHandler", turbo.web.RequestHandler)
    function HelloWorldHandler:get()
        self:write("Hello World!")
    end

    -- Create an Application object and bind our HelloWorldHandler to the route '/hello'.
    local app = turbo.web.Application:new({
        {"/hello", HelloWorldHandler}
    })

    -- Set the server to listen on port 8888 and start the ioloop.
    app:listen(8888)
    turbo.ioloop.instance():start()

Save the file as helloworld.lua and run it with ``luajit helloworld.lua``.

Request parameters
==================

A slightly more advanced example, a server echoing the request parameter 'name'.

.. code-block:: lua

    local turbo = require("turbo")

    local HelloNameHandler = class("HelloNameHandler", turbo.web.RequestHandler)

    function HelloNameHandler:get()
        -- Get the 'name' argument, or use 'Santa Claus' if it does not exist
        local name = self:get_argument("name", "Santa Claus")
        self:write("Hello " .. name .. "!")
    end

    function HelloNameHandler:post()
        -- Get the 'name' argument, or use 'Easter Bunny' if it does not exist
        local name = self:get_argument("name", "Easter Bunny")
        self:write("Hello " .. name .. "!")
    end

    local app = turbo.web.Application:new({
        {"/hello", HelloNameHandler}
    })

    app:listen(8888)
    turbo.ioloop.instance():start()


Routes
======

Turbo has a nice routing feature using Lua pattern matching.
You can assign handler classes to routes in the turbo.web.Application constructor.

.. code-block:: lua


    local turbo = require("turbo")

    -- Handler that takes no argument, just like in the hello world example
    local IndexHandler = class("IndexHandler", turbo.web.RequestHandler)
    function IndexHandler:get()
        self:write("Index..")
    end

    -- Handler that takes a single argument 'username'
    local UserHandler = class("UserHandler", turbo.web.RequestHandler)
    function UserHandler:get(username)
        self:write("Username is " .. username)
    end

    -- Handler that takes two integers as arguments and adds them..
    local AddHandler = class("AddHandler", turbo.web.RequestHandler)
    function AddHandler:get(a1, a2)
        self:write("Result is: " .. tostring(a1+a2))
    end

    local app = turbo.web.Application:new({
        -- No arguments, will work for 'localhost:8888' and 'localhost:8888/'
        {"/$", IndexHandler},

        -- Use the part of the url after /user/ as the first argument to
        -- UserHandler:get
        {"/user/(.*)$", UserHandler},

        -- Find two int's separated by a '/' after /add in the url
        -- and pass them as arguments to AddHandler:get
        {"/add/(%d+)/(%d+)$", AddHandler}
    })

    app:listen(8888)
    turbo.ioloop.instance():start()


Serving Static Files
====================

It's often useful to be able to serve static assets, at least for
development purposes. Turbo makes this really easy with the built in turbo.web.StaticFileHandler,
just specify a directory, and it will do the heavy lifting, as well as cache your files
for optimal performance.


.. code-block:: lua

    local turbo = require("turbo")

    app = turbo.web.Application:new({
        -- Serve static files from /var/www using the route "/static/(path-to-file)"
        {"/static/(.*)$", turbo.web.StaticFileHandler, "/var/www/"}
    })

    app:listen(8888)
    turbo.ioloop.instance():start()


JSON Output
===========

Turbo has implicit JSON coversion.
This means that you can pass a JSON-serializable table to self:write and
Turbo will set the 'Content-Type' header to 'application/json' and
serialize the table for you.

.. code-block:: lua

    local turbo = require("turbo")

    -- Handler that responds with '{"hello":"json"}' and a Content-Type of application/json
    local HelloJSONHandler = class("HelloJSONHandler", turbo.web.RequestHandler)
    function HelloJSONHandler:get()
        self:write({hello="json"})
    end

    local application = turbo.web.Application:new({
        {"/hello", HelloJSONHandler}
    })

    application:listen(8888)
    turbo.ioloop.instance():start()
