--[[ Nonsence Asynchronous event based Lua Web server.
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
limitations under the License.        ]]

local log, util, httputil, deque, escape, response_codes, mime_types = require('log'), require('util'), 
require("httputil"), require("deque"), require("escape"), require("http_response_codes"), require("mime_types")

require('middleclass')

local is_in, type = util.is_in, type

local web = {} -- web namespace


--[[ RequestHandler class.

Decides what the heck to do with incoming requests that matches its
corresponding pattern / patterns.
		
All request handler classes should inherit from this one.   ]]
web.RequestHandler = class("RequestHandler")

function web.RequestHandler:init(application, request, url_args, kwargs)
	self.SUPPORTED_METHODS = {"GET", "HEAD", "POST", "DELETE", "PUT", "OPTIONS"}
	self.application = application
	self.request = request
	self._headers_written = false
	self._finished = false
	self._auto_finish = true
	self._transforms = nil
	self._url_args = url_args
	self.arguments = {}
	self:clear()
	
	local function _on_close_callback()
		self:on_connection_close()
	end

	if self.request._request.headers:get("Connection") then
		self.request.stream:set_close_callback(_on_close_callback)
	end

	self:on_create(kwargs)
end

--[[ Returns the applications settings.          ]] --
function web.RequestHandler:settings() return self.application.settings end


--[[ Please redefine this class if you want to do something straight after the class has been created.
Parameter can be either a table with kwargs, or a single parameter.      ]]
function web.RequestHandler:on_create(kwargs) end

--[[ Redefine this method after your likings.
Called before get/post/put etc. methods on a request.    ]]
function web.RequestHandler:prepare() end

--[[ Redefine this method after your likings.
Called after the end of a request.
Usage of this method could be something like a clean up etc.  ]]
function web.RequestHandler:on_finish() end

--[[ Called in asynchronous handlers when the connection is closed.
Use it to clean up the mess after the connection :-).     ]]
function web.RequestHandler:on_connection_close() end

--[[ Standard methods for RequestHandler class. 
If not redefined they will provide a 405 response code (Method Not Allowed)    ]]
function web.RequestHandler:head(self, args, kwargs) error(web.HTTPError:new(405)) end
function web.RequestHandler:get(self, args, kwargs) error(web.HTTPError:new(405)) end
function web.RequestHandler:post(self, args, kwargs) error(web.HTTPError:new(405)) end
function web.RequestHandler:delete(self, args, kwargs) error(web.HTTPError:new(405)) end
function web.RequestHandler:put(self, args, kwargs) error(web.HTTPError:new(405)) end
function web.RequestHandler:options(self, args, kwargs)	error(web.HTTPError:new(405)) end

--[[ Reset all headers and content for this request. Run on class initialization.		]]
function web.RequestHandler:clear()
	self.headers = httputil.HTTPHeaders:new()
	self:set_default_headers()
	self:set_header("Content-Type", "text/html; charset=UTF-8")
	self:set_header("Server", self.application.application_name)
	if not self.request._request:supports_http_1_1() then
		if self.request._request.headers:get("Connection") == "Keep-Alive" then
			self:set_header("Connection", "Keep-Alive")
		end
	end
	self._write_buffer = deque:new()
	self._status_code = 200
end

--[[ Redefine this method to set HTTP headers at the beginning of the request.    ]]
function web.RequestHandler:set_default_headers() end

--[[ Add the given name and value pair to the HTTP response  headers.
self.headers are a instance of the HTTPHeaders class which does all the hard work in this case.   ]]
function web.RequestHandler:add_header(name, value)	self.headers:add(name, value) end

--[[ Set the given name and value pair to the HTTP response  headers. Returns true on success.]]
function web.RequestHandler:set_header(name, value)	self.headers:set(name, value) end

--[[ Returns the current value set to given key.   ]]
function web.RequestHandler:get_header(key) return self.headers:get(key) end

--[[ Sets the status for our response.   ]]
function web.RequestHandler:set_status(status_code)
	assert(type(status_code) == "number", [[set_status method requires number.]])
	self._status_code = status_code
end

--[[  Returns the status code currently set for our response.    ]]
function web.RequestHandler:get_status() return self._status_code end


--[[ Returns the value of the argument with the given name.
If default value is not given the argument is considered to be
required and will result in a 400 Bad Request if the argument
does not exist.

FIXME: implement strip.  ]]
function web.RequestHandler:get_argument(name, default, strip)	
	local args = self:get_arguments(name, strip)
	if type(args) == "string" then
		return args
	elseif type(args) == "table" and #args > 0 then 
		return args[1]
	elseif default then
		return default
	else
		error(web.HTTPError:new(400))
	end
end

--[[ Returns the values of the argument with the given name.
Will return a empty table if argument does not exist.
TOOD: implement strip.   ]]
function web.RequestHandler:get_arguments(name, strip)
	local values = {}
	
	if self.request.arguments[name] then
		values = self.request.arguments[name]

	elseif self.request._request.arguments[name] then
		values = self.request._request.arguments[name]
	end
	return values
end

--[[ Redirect client to another URL. Sets headers and finish request.   
User can not send data after this.    ]]
function web.RequestHandler:redirect(url, permanent)
	if self._headers_written then
		error("Cannot redirect after headers have been written")
	end
	
	local status = permanent and 302 or 301
	self:set_status(status)
	
	self:set_header("Location", url)
	
	self:finish()
end


--[[ Writes the given chunk to the output buffer.			
To write the output to the network, use the flush() method.
If the given chunk is a Lua table, it will be automatically
stringifed to JSON.    ]]
function web.RequestHandler:write(chunk)
	local chunk = chunk
	
	if self._finished then
		error("write() method was called after finish().")
	end
	
	if type(chunk) == "table" then
		self:set_header("Content-Type", "application/json; charset=UTF-8")
		chunk = escape.json_encode(chunk)
	end
	
	self._write_buffer:append(chunk)
end


--[[ Flushes the current output buffer to the IO stream.
			
If callback is given it will be run when the buffer has 
been written to the socket. Note that only one callback flush
callback can be present per request. Giving a new callback
before the pending has been run leads to discarding of the
current pending callback. For HEAD method request the chunk 
is ignored and only headers are written to the socket.  	]]
function web.RequestHandler:flush(callback)
	local headers
	local chunk = self._write_buffer:concat() or ''
	self._write_buffer = deque:new()
	
	if not self._headers_written then
		self._headers_written = true
		headers = self.headers:__tostring()
	end
	
	if self.request._request.headers.method == "HEAD" then
		if headers then 
			self.request:write(headers, callback)
		end
	end
	
	if headers or chunk then
		self.request:write(headers .. chunk, callback)
	end
end

--[[ Set request to automatically call finish when request method has been called. Default
behaviour is to finish the request immediately.   ]]
function web.RequestHandler:set_auto_finish(bool)
	assert(type(bool) == "boolean", "bool must be boolean!")
	self._auto_finish = bool
end

--[[ Finishes the HTTP request.
Cleaning up of different messes etc.    ]]
function web.RequestHandler:finish(chunk)	
	assert((not self._finished), [[finish() called twice. Something terrible has happened]])
	
	if chunk then
		self:write(chunk)
	end

	if not self._headers_written then
		if not self:get_header("Content-Length") then
			self:set_header("Content-Length", self._write_buffer:concat():len())
		end
		self.headers:set_status_code(self._status_code)
		self.headers:set_version("HTTP/1.1")
	end
	
	if self._status_code == 200 then
		log.success(string.format([[[web.lua] %d %s %s %s (%s)]], 
			self._status_code, 
			response_codes[self._status_code],
			self.request._request.headers.method,
			self.request._request.headers.url,
			self.request._request.remote_ip))
	else
		log.warning(string.format([[[web.lua] %d %s %s %s (%s)]], 
			self._status_code, 
			response_codes[self._status_code],
			self.request._request.headers.method,
			self.request._request.headers.url,
			self.request._request.remote_ip))
	end
	
	self:flush()
	self.request:finish()
	self._finished = true
	self:on_finish()
end


--[[ Main execution of the RequestHandler class.     ]]
function web.RequestHandler:_execute(args)
	if not is_in(self.request._request.method, self.SUPPORTED_METHODS) then
		error(web.HTTPError:new(405))
	end

	self:prepare()
	if not self._finished then
		self[self.request._request.method:lower()](self, unpack(self._url_args), kwargs)
		if self._auto_finish and not self._finished then
			self:finish()
		end
	end
end


--[[ Static files cache class. Files that does not exist in cache are added to cache on first read.   ]]
web._StaticWebCache = class("_StaticWebCache")
function web._StaticWebCache:init()
	self.files = {}
end

--[[ Read complete file. Returns rc and buffer in case read were successfull.  ]]
function web._StaticWebCache:read_file(path)
	local fd = io.open(path, "r")
	if not fd then
		return -1, nil
	end

	local buf = fd:read("*all")
	return 0, buf
end

function web._StaticWebCache:get_file(path)
	for filepath, bytes in pairs(self.files) do
		if (filepath == path) then
			return 0, bytes
		end
	end
	-- Fallthrough, read from disk.
	local rc, buf = self:read_file(path)
	if rc == 0 then
		self.files[path] = buf
		log.notice(string.format("[web.lua] Added %s (%d bytes) to static file cache. ", path, buf:len()))
		return 0, buf
	else
		return -1, nil
	end

end



STATIC_CACHE = web._StaticWebCache:new()


--[[ Static file handler class.  Provide the filesystem path as option in nonsence.web.Application.  ]]
web.StaticFileHandler = class("StaticFileHandler", web.RequestHandler)
function web.StaticFileHandler:init(app, request, args, options)
	web.RequestHandler:init(app, request, args)	
	self.path = options
end


--[[ Determine MIME type according to file exstension.   ]]
function web.StaticFileHandler:get_mime()
	local filename = self._url_args[1]
	assert(filename)
	local parts = filename:split(".")
	if #parts == 0 then
		return -1
	end
	local file_ending = parts[#parts]
	local mime_type = mime_types[file_ending]
	if mime_type then
		return 0, mime_type
	else
		return -1
	end
end

--[[ GET method for static file handling.   ]]
function web.StaticFileHandler:get(path)
	if #self._url_args == 0 or self._url_args[1]:len() == 0 then
		error(web.HTTPError(404))
	end

	local filename = self._url_args[1]
	if filename:match("%.%.") then -- Prevent dir traversing.
		error(web.HTTPError(401))
	end

	local full_path = string.format("%s%s", self.path, filename)
	local rc, buf = STATIC_CACHE:get_file(full_path)
	if rc == 0 then
		local rc, mime_type = self:get_mime()
		if rc == 0 then
			self:set_header("Content-Type", mime_type)
		end
		self:set_header("Content-Length", buf:len())
		self:write(buf)
	else
		error(web.HTTPError(404)) -- Not found
	end
end


function web.StaticFileHandler:head(path)
	if #self._url_args == 0 or self._url_args[1]:len() == 0 then
		error(web.HTTPError(404))
	end

	local filename = self._url_args[1]
	if filename:match("%.%.") then -- Prevent dir traversing.
		error(web.HTTPError(401))
	end

	local full_path = string.format("%s%s", self.path, filename)
	local rc, buf = STATIC_CACHE:get_file(full_path)
	if rc == 0 then
		local rc, mime_type = self:get_mime()
		if rc == 0 then
			self:set_header("Content-Type", mime_type)
		end
		self:set_header("Content-Length", buf:len())
	else
		error(web.HTTPError(404)) -- Not found
	end
end


--[[ Class to handout HTTP errors.  ]]
web.ErrorHandler = class("ErrorHandler", web.RequestHandler)

function web.ErrorHandler:init(app, request, code, message)
	web.RequestHandler:init(app, request)
	if (message) then 
		self:write(message)
	else
		self:write(response_codes[code])
	end
	self:set_status(code)
	self:finish()
end

--[[ HTTPError exception class. Raisable from RequestHandler instances. Provide code and optional message.  ]]
web.HTTPError = class("HTTPError")
function web.HTTPError:init(code, message)
	assert(type(code) == "number", "HTTPError code argument must be number.")
	self.code = code
	self.message = message and message or response_codes[code]
end




web.Application = class("Application")

function web.Application:init(handlers, default_host)
	self.handlers = handlers
	self.default_host = default_host
	self.application_name = "Nonsence v1.0"
end

--[[ Sets the server name.     ]]
function web.Application:set_server_name(name) self.application_name = name end

--[[ Returns the server name.   ]]
function web.Application:get_server_name(name) return self.application_name end

--[[ Starts the HTTP server for this application on the given port. ]]
function web.Application:listen(port, address, kwargs)
	local httpserver = pcall(require, 'httpserver') and require('httpserver') or 
		error('Missing module httpserver')
	local server = httpserver.HTTPServer:new(self, kwargs)
	server:listen(port, address)
end


local function pack(...)
	return arg
end
--[[ Find a matching request handler for the request object.
Simply match the URI against the pattern matches supplied
to the Application class.   ]]
function web.Application:_get_request_handlers(request)
	local path = request._request.path and request._request.path:lower()
	if not path then 
		path = "/"
	end
	
	local handlers_sz = #self.handlers
	for i = 1, handlers_sz do 
		local handler = self.handlers[i]
		local pattern = handler[1]
		if path:match(pattern) then
			local args = {path:match(pattern)}
			return handler[2], args, handler[3]
		end
	end
end

function web.Application:__call(request)
	-- Handler for HTTP request.

	local handler
	local handlers, args, options = self:_get_request_handlers(request)
	
	if handlers then	
		handler = handlers:new(self, request, args, options)
		local status, err = pcall(function() handler:_execute() end)
		if err then

			if instanceOf(web.HTTPError, err) then
				handler = web.ErrorHandler:new(self, request, err.code, err.message)
			else 
				local trace = debug.traceback()
				log.error("[web.lua] " .. err)
				log.stacktrace(trace)
				handler = web.ErrorHandler:new(self, request, 500, string.format("<pre>%s\n%s\n</pre>", err, trace))
			end
		end
		
	elseif not handlers and self.default_host then 
		handler = web.RedirectHandler:new("http://" + self.default_host + "/")
		
	else
		handler = web.ErrorHandler:new(self, request, 404)
	end

	return handler
end

return web
