--[[
	
		Nonsence Asynchronous event based Lua Web server.
		Author: John Abrahamsen < JhnAbrhmsn@gmail.com >
		
		This module "web" is a part of the Nonsence Web server.
		For the complete stack hereby called "software package" please see:
		
		https://github.com/JohnAbrahamsen/nonsence-ng/
		
		Many of the modules in the software package are derivatives of the 
		Tornado web server. Tornado is also licensed under Apache 2.0 license.
		For more details on Tornado please see:
		
		http://www.tornadoweb.org/
		
		
		Copyright 2011 John Abrahamsen

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

local log = pcall(require, 'log') and require('log') or error('Missing module log')
local util = pcall(require, 'util') and require('util') or error('Missing module util')
require('middleclass')

local is_in = util.is_in

local web = {}

web.RequestHandler = class("RequestHandler")
--[[

		RequestHandler class.
		Decides what the heck to do with incoming requests that matches its
		corresponding pattern / patterns.
		
		All request handler classes should inherit from this one.
		
  ]]

function web.RequestHandler:init(application, request, kwargs)
	self.SUPPORTED_METHODS = {"GET", "HEAD", "POST", "DELETE", "PUT", "OPTIONS"}
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


	if self.request._request.headers:get("Connection") then
		self.request.stream:set_close_callback(_on_close_callback)
	end

	self:on_create(kwargs)
end

function web.RequestHandler:on_create(kwargs)
	--[[
	 
			Please redefine this class if you want to do something
			straight after the class has been created.
			
			Parameter can be either a table with kwargs, or a single parameter.
		
	  ]]
end

function web.RequestHandler:head(self, args, kwargs) error(HTTPError:new(405)) end
function web.RequestHandler:get(self, args, kwargs) error(HTTPError:new(405)) end
function web.RequestHandler:post(self, args, kwargs) error(HTTPError:new(405)) end
function web.RequestHandler:delete(self, args, kwargs) error(HTTPError:new(405)) end
function web.RequestHandler:put(self, args, kwargs) error(HTTPError:new(405)) end
function web.RequestHandler:options(self, args, kwargs) error(HTTPError:new(405)) end

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
	--[[ 
	
			Redefine this method to set HTTP headers at the beginning of
			the request.
		
	  ]]
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

function web.RequestHandler:get_argument(name, default, strip)
	--[[
	 
			Returns the value of the argument with the given name.
			If default value is not given the argument is considered to be
			required and will result in a 400 Bad Request if the argument
			does not exist.
			
	  ]]
	
	local args = self.get_arguments(name, strip)
	if not args and default then
		return default
	else
		error(HTTPError:new(400))
	end
end

function web.RequestHandler:_execute()
	--[[
	
			Main execution of the RequestHandler class.
			
			Here we do different things:
			- Match HTTP method against methods in the class e.g GET,
			POST, HEAD, PUT...
			- Pass any arguments from the pattern match in the Application
			class.
	
	  ]]
	  
	  if not is_in(self.request._request.method, self.SUPPORTED_METHODS) then
			error(HTTPError:new(405))
	  end
	  
	  error("should fail but doesnt")
	  self:prepare()
	  if not self._finished then
			self[self.request._request.method:lower()](self, args, kwargs)
	  end
	  self:finish()
		
end

web.Application = class("Application")

function web.Application:init(handlers, default_host)
	self.handlers = handlers
	self.default_host = default_host
end

function web.Application:listen(port, address, kwargs)
	-- Starts the HTTP server for this application on the given port.
	
	local httpserver = pcall(require, 'httpserver') and require('httpserver') or 
		error('Missing module httpserver')
	local server = httpserver.HTTPServer:new(self, kwargs)
	server:listen(port, address)
end

function web.Application:_get_request_handlers(request)
	--[[
	
			Find a matching request handler for the request object.
			Simply match the URI against the pattern matches supplied
			to the Application class.
			
			TODO: is a check for this tables presence needed?
			
	  ]]
	  
	local path = request._request.path and request._request.path:lower()
	if not path then 
		path = "/"
	end
	for pattern, handlers in pairs(self.handlers) do 
		if path:match(pattern) then
			return handlers
		end
	end
end

function web.Application:__call(request)

	local function error_handler(err)
		-- Handles errors in _run_callback.
		-- Verbose printing of error to console.
		log.error([[_callback_error_handler caught error: ]] .. err)
		log.error(debug.traceback())
	end
	
	
	local function __call_safe()
		-- Handler for HTTP request.

		local handler
		local handlers = self:_get_request_handlers(request)
		
		if handlers then
			handler = handlers:new(self, request)
			
		elseif not handlers and self.default_host then 
			handler = web.RedirectHandler:new("http://" + self.default_host + "/")
			
		else
			handler = web.ErrorHandler:new(request, 404)
			
		end

		handler:_execute()
		return handler
	end
	
	xpcall(__call_safe, error_handler)
	
end

return web
