.. _get_started:

************************
Get Started With Turbo
************************

A set off simple examples to get you started using Turbo.

Installing Turbo
================
Turbo needs LuaJIT to run, because it uses the LuaJIT FFI library it will not 
run on 'official/normal/vanilla' Lua.
You can get the latest stable and installation instructions at http://luajit.org/download

There's no official stable releases of Turbo yet, but you can obtain
a pretty-stable copy from the git repository.

.. code-block:: sh

    $ git clone https://github.com/kernelsauce/turbo.git 
    $ make -C ./turbo install

You can also install Turbo to a different directory than /usr/local 
by setting the PREFIX variable when doing make install.


.. code-block:: sh

    $ make -C ./turbo install PREFIX=/path/to/my/dir


Or, if you want a self-contained directory with luajit and turbo, 
you can use the turbo-virtual-env tool from https://github.com/enotodden/turbo-virtual-env

.. code-block:: sh

    $ cd /some/dir
    $ curl https://raw.github.com/enotodden/turbo-virtual-env/master/turbo-virtual-env | bash -s - --create ./env


To start using the newly installed LuaJIT and Turbo, just source the 'activate' script located in /some/dir/env/bin/activate

.. code-block:: sh

    $ . env/bin/activate




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
