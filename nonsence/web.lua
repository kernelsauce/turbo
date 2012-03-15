--[[
	
	Nonsence Asynchronous event based Lua Web server.
	Author: John Abrahamsen < JhnAbrhmsn@gmail.com >
	
	This module "Web" is a part of the Nonsence Web server.
	< https://github.com/JohnAbrahamsen/nonsence-ng/ >
	
	Nonsence is licensed under the MIT license < http://www.opensource.org/licenses/mit-license.php >:

	"Permission is hereby granted, free of charge, to any person obtaining a copy of
	this software and associated documentation files (the "Software"), to deal in
	the Software without restriction, including without limitation the rights to
	use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
	of the Software, and to permit persons to whom the Software is furnished to do
	so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE."

  ]]

local httpserver = pcall(require, 'httpserver') and require('httpserver') or 
	error('Missing module httpserver')
local log = pcall(require, 'log') and require('log') or 
	error('Missing module log')
assert(require('middleclass'), 
	[[Missing required module: MiddleClass 
	https://github.com/kikito/middleclass]])
		
local web = {}

web.RequestHandler = class("RequestHandler")
--[[

	Request handler class.
		
  ]]

function web.RequestHandler:initialize(application, request, kwargs)
	self.application = application
	self.request = request
	self._headers_written = false
	self._finished = false
	self._auto_finish = true
	self._transforms = nil
	
	self:clear()
	
	local function _on_close_callback()
		self:on_connection_close()
	end
	
	if self.request:get("Connection") then
		self.request.connection.stream:set_close_callback(_on_close_callback)
	end
	self:on_creation(kwargs)
end

function web.RequestHandler:on_create(kwargs)
	--[[
	 
		Please redefine this class if you want to do something
		straight after the class has been created.
		
		Parameter can be either a table with kwargs, or a single parameter.
		
	  ]]
end

function web.RequestHandler:head(self, args, kwargs) HTTPError:new(405) end
function web.RequestHandler:get(self, args, kwargs) HTTPError:new(405) end
function web.RequestHandler:post(self, args, kwargs) HTTPError:new(405) end
function web.RequestHandler:delete(self, args, kwargs) HTTPError:new(405) end
function web.RequestHandler:put(self, args, kwargs) HTTPError:new(405) end
function web.RequestHandler:options(self, args, kwargs) HTTPError:new(405) end

function web.RequestHandler:prepare()
	--[[
	
		Redefine this method after your likings.
		Called before get/post/put etc. methods on a request.
		
	  ]]
end

function web.RequestHandler:on_finish()
	--[[ 
	
		Redefine this method after your likings.
		Called after the end of a request.
		Usage of this method could be something like a clean up etc.
		
	  ]]
end

function web.RequestHandler:on_connection_close()
	--[[
		
		Called in asynchronous handlers when the connection is closed.
		Use it to clean up the mess after the connection :-).
		
	  ]]
end

function web.RequestHandler:clear()
	-- Reset all headers and content for this request.
	-- TODO make this function :P
	
end

function web.RequestHandler:set_default_headers()
	-- Redefine this method to set HTTP headers at the beginning of
	-- the request.
end

function web.RequestHandler:set_status(status_code)
	-- Sets the status for our response.
	
	assert(type(status_code) == "int", [[set_status method requires int.]])
	self._status_code = status_code
end

function web.RequestHandler:get_status()
	-- Returns the status code currently set for our response.
	
	return self._status_code
end

function web.RequestHandler:add_header(key, value)
	-- Add the given response header key and value to the response.

	self.headers:add(key, value)
end

return web
