--[[ Nonsence Asynchronous event based Lua Web server.
Author: John Abrahamsen < JhnAbrhmsn@gmail.com >

https://github.com/JohnAbrahamsen/nonsence-ng/

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.     ]]

local nonsence = require('nonsence')

local ExampleHandler = class("ExampleHandler", nonsence.web.RequestHandler)

--[[ Hello World example. ]]
function ExampleHandler:get()
	self:write("Hello world!")
end

--[[ Echo post value example.    ]]
function ExampleHandler:post()
	local posted_value = self:get_argument('somevalue')
	self:write('You posted: ' .. posted_value)
end

local MyJSONHandler = class("MyJSONHandler", nonsence.web.RequestHandler)

--[[ Pass table to JSON stringify it.  ]]
function MyJSONHandler:get()
	local my_list = { "one", "two", "three" }
	self:write(my_list)
end


 
local application = nonsence.web.Application:new({ 
	{"/static/(.*)$", nonsence.web.StaticFileHandler, "/var/www"},
	{"/$", ExampleHandler},
	{"/json", MyJSONHandler},
})

application:listen(8888) -- Listen on port 8888

nonsence.ioloop.instance():start() -- Start global IO loop.
