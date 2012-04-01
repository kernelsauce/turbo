--[[
	
		Nonsence Asynchronous event based Lua Web server.
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
		limitations under the License.

  ]]

package.path = package.path .. ";./nonsence/?.lua" -- Put base dir in path.
local nonsence = require('nonsence')

--[[
	
		Lets make a site root that will show "Hello World!"
		First create new Handler with heritage from RequestHandler
		
  ]]
local ExampleHandler = class("ExampleHandler", nonsence.web.RequestHandler)

--[[

		Then lets define a method for the GET request towards our new 
		request handler instance:
		
  ]]
function ExampleHandler:get()
	self:write("Hello world!")
end

--[[

		We could also define a method for POST request:
		
  ]]
function ExampleHandler:post()
	local posted_value = self:get_argument('somevalue')
	self:write('You posted: ' .. posted_value)
end

--[[
	
		Lets also make our application post some JSON.
		Create another new handler instance with heritage.
		Notice how Lua tables are automagically converted to JSON.
  
  ]]
local MyJSONHandler = class("MyJSONHandler", nonsence.web.RequestHandler)

function MyJSONHandler:get()
	local my_list = { "one", "two", "three" }
	self:write(my_list)
end

--[[
	
		Register your handlers with a new application instance.
		The key could be any pattern.
	
  ]]
local application = nonsence.web.Application:new({ 
	['/$'] = ExampleHandler,
	['/json'] = MyJSONHandler
})

application:listen(8888) -- Listen on port 8888

nonsence.ioloop.instance():start() -- Start global IO loop.
