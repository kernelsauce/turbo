Nonsence Web 
============

<b>Asynchronous event based Lua Web server with inspiration from the Tornado web server.</b>

<b>Making a Hello World server:</b>

        local nonsence = require('nonsence')


        -- Create class with RequestHandler heritage.
        local ExampleHandler = class("ExampleHandler", nonsence.web.RequestHandler)
        function ExampleHandler:get()
                -- Echo hello world on HTTP GET!
                self:write("Hello world!")
        end
        
        function ExampleHandler:post()
                -- Echo post value example on HTTP POST. Or give a bad request if the argument is not set.
                local posted_value = self:get_argument('somevalue')
                self:write('You posted: ' .. posted_value)
        end
        
        
        local MyJSONHandler = class("MyJSONHandler", nonsence.web.RequestHandler)
        function MyJSONHandler:get()
                -- Pass table to JSON stringify it.  
                local my_list = { "one", "two", "three" }
                self:write(my_list)
        end
        
         
        local application = nonsence.web.Application:new({
                -- Nonsence serves static files as well!
                {"/static/(.*)$", nonsence.web.StaticFileHandler, "/var/www/"},
                -- Register handlers
                {"/$", ExampleHandler},
                {"/json", MyJSONHandler},
        })
        
        application:listen(8888)
        nonsence.ioloop.instance():start()

Introduction
------------
Nonsence Web is a Lua module / toolkit (whatever) for developing web apps in Lua. It is different from all the other
Lua HTTP servers out there in that it's modern, fresh, object oriented and easy to modify, and probably the fastest scriptable Web server
available.

Its main features and design principles are:

- Simple and intuitive API

- Good documentation

- Few dependencies

- Event driven, asynchronous and threadless design

- Extremely fast with LuaJIT

- Written completely in pure Lua with some LuaJIT FFI modules.

- Linux Epoll support

- Small footprint

Nonsence Web is licensed under the Apache License, version 2.0. See LICENSE in the source code for more details. Some modules 
are dual licensed with both MIT and Apache 2.0 licenses.

Dependencies
------------
Nonsence Web has dropped support for vanilla Lua because of the decision to drop C modules all together and write all these as LuaJIT FFI modules,
which gives a much better performance. Latest version of LuaJIT can be downloaded here: http://luajit.org/

All of the modules of Nonsence Web are made with the class implementation that Middleclass provides <https://github.com/kikito/middleclass>. 


Performance
-----------
So all this bragging, but nothing to back it up?!
Running:

	ab -n 100000 -c 500 -k 127.0.0.1:8888/

on my Lenovo Thinkpad W510 running ExampleUsage.lua yields these numbers:

        Server Software:        Nonsence
        Server Hostname:        127.0.0.1
        Server Port:            8888
        
        Document Path:          /
        Document Length:        12 bytes
        
        Concurrency Level:      500
        Time taken for tests:   7.620 seconds
        Complete requests:      100000
        Failed requests:        0
        Write errors:           0
        Keep-Alive requests:    100000
        Total transferred:      17500000 bytes
        HTML transferred:       1200000 bytes
        Requests per second:    13124.10 [#/sec] (mean)
        Time per request:       38.098 [ms] (mean)
        Time per request:       0.076 [ms] (mean, across all concurrent requests)
        Transfer rate:          2242.89 [Kbytes/sec] received

        Connection Times (ms)
                      min  mean[+/-sd] median   max
        Connect:        0    6 124.6      0    3012
        Processing:     1   32  10.1     37     245
        Waiting:        1   32  10.1     37     244
        Total:          1   38 126.6     37    3256
        
        Percentage of the requests served within a certain time (ms)
          50%     37
          66%     38
          75%     39
          80%     39
          90%     40
          95%     40
          98%     40
          99%     40
         100%   3256 (longest request)


Tornado (with demo hello world app):

        Server Software:        TornadoServer/3.1.dev2
        Server Hostname:        127.0.0.1
        Server Port:            8888
        
        Document Path:          /
        Document Length:        12 bytes
        
        Concurrency Level:      500
        Time taken for tests:   33.960 seconds
        Complete requests:      100000
        Failed requests:        0
        Write errors:           0
        Keep-Alive requests:    100000
        Total transferred:      23400000 bytes
        HTML transferred:       1200000 bytes
        Requests per second:    2944.64 [#/sec] (mean)
        Time per request:       169.800 [ms] (mean)
        Time per request:       0.340 [ms] (mean, across all concurrent requests)
        Transfer rate:          672.90 [Kbytes/sec] received
        
        Connection Times (ms)
                      min  mean[+/-sd] median   max
        Connect:        0    7 128.3      0    3008
        Processing:    14  163  36.0    168     382
        Waiting:       14  163  36.0    168     382
        Total:         14  169 136.3    168    3375
        
        Percentage of the requests served within a certain time (ms)
          50%    168
          66%    170
          75%    174
          80%    178
          90%    185
          95%    197
          98%    259
          99%    282
         100%   3375 (longest request)


Don't believe me? Try it yourself and see :).


License
-------
Copyright 2011, 2012 and 2013 John Abrahamsen

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Many of the modules in the software package are derivatives of the 
Tornado web server. Tornado is also licensed under Apache 2.0 license.
For more details on Tornado please see:

<http://www.tornadoweb.org/>

Some of the modules in this software package are licensed under
both the MIT and Apache 2.0 License. Modules that are dual licensed 
clearly states this in the file header.

