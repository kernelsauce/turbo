--[[
	
	Nonsence Asynchronous event based Lua Web server.
	Author: John Abrahamsen < JhnAbrhmsn@gmail.com >
	
	This module "HTTPServer" is a part of the Nonsence Web server.
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
  
-------------------------------------------------------------------------
--
-- Load modules
--
local log = assert(require('log'), 
	[[Missing log module]])
local nixio = assert(require('nixio'),
	[[Missing required module: Nixio (https://github.com/Neopallium/nixio)]])
local tcpserver = assert(require('tcpserver'), 
	[[Missing tcpserver module]])
local httputil = assert(require('httputil'), 
	[[Missing httputil module]])
local ioloop = assert(require('ioloop'), 
	[[Missing ioloop module]])
local iostream = assert(require('iostream'), 
	[[Missing iostream module]])
assert(require('middleclass'), 
	[[Missing required module: MiddleClass 
	https://github.com/kikito/middleclass]])
-------------------------------------------------------------------------
-------------------------------------------------------------------------
-- Speeding up globals access with locals :>
-- 

-------------------------------------------------------------------------
-------------------------------------------------------------------------
-- Table to return on require.
local httpserver = {}
-------------------------------------------------------------------------

local function _parse_post_arguments(data)
	assert(type(data) == "string", "data into _parse_post_arguments() not a string.")
	local arguments_string = data:match("?(.+)")
	local arguments = {}
	local noDoS = 0;
	for k, v in arguments_string:gmatch("([^&=]+)=([^&]+)") do
		noDoS = noDoS + 1;
		if (noDoS > 256) then break; end -- hashing DoS attack ;O
		v = v:gsub("+", " "):gsub("%%(%w%w)", function(s) return char(tonumber(s,16)) end);
		if (not arguments[k]) then
			arguments[k] = v;
		else
			if ( type(arguments[k]) == "string") then
				local tmp = arguments[k];
				arguments[k] = {tmp};
			end
			insert(arguments[k], v);
		end
	end
	return arguments
end

httpserver.HTTPServer = class('HTTPServer', tcpserver.TCPServer)

function httpserver.HTTPServer:init(request_callback, no_keep_alive, io_loop, xheaders,
	ssl_options, kwargs)
	--[[ 
	
		HTTPServer with heritage from TCPServer.
		
	  ]]
	
	self.request_callback = request_callback
	self.no_keep_alive = no_keep_alive or false
	self.xheaders = xheaders or false
	-- Init superclass TCPServer.
	tcpserver.TCPServer:init(io_loop, ssl_options, kwargs)
end

function httpserver.HTTPServer:handle_stream(stream, address)
	-- Redefine handle_stream method from super class TCPServer
	
	httpserver.HTTPConnection:new(stream, address, self.request_callback,
		self.no_keep_alive, self.xheaders)
end

httpserver.HTTPConnection = class('HTTPConnection')

function httpserver.HTTPConnection:init(stream, address, request_callback,
	no_keep_alive, xheaders)

	self.stream = stream
	self.address = address
	local function _wrapped_request_callback(data)
		-- This is needed to retain the context.
		request_callback(data)
	end
	self.request_callback = _wrapped_request_callback
	self.no_keep_alive = no_keep_alive or false
	self.xheaders = xheaders or false
	self._request = nil
	self._request_finished = false
	local function _wrapped_header_callback(data)
		-- This is needed to retain the context.
		self:_on_headers(data)
	end
	self._header_callback = _wrapped_header_callback
	self.stream:read_until("\r\n\r\n", self._header_callback)
	self._write_callback = nil
end

function httpserver.HTTPConnection:write(chunk, callback)
	-- Writes a chunk of output to the stream.
	
	local callback = callback
	assert(self._request, "Request closed")

	if not self.stream:closed() then
		self._write_callback = callback
		local function _on_write_complete_wrap()
			self:_on_write_complete()
		end
		self.stream:write(chunk, _on_write_complete_wrap)
	end
end

function httpserver.HTTPConnection:finish()
	-- Finishes the request
	assert(self._request, "Request closed")
	self._request_finished = true
	if not self.stream:writing() then
		self:_finish_request()
	end
end

function httpserver.HTTPConnection:_on_write_complete()
	-- Run callback on complete.

	if self._write_callback then
		local callback = self._write_callback
		self._write_callback = nil
		callback()
	end
	if self._request_finished and not self.stream:writing() then
		self:_finish_request()
	end
end

function httpserver.HTTPConnection:_finish_request()
	-- Finish request.
	
	local disconnect = false
	
	if self.no_keep_alive then
		disconnect = true
	else
		local connection_header = self._request.headers:get("Connection")
		if connection_header then
			connection_header = connection_header:lower()
		end
		if self._request:supports_http_1_1() then
			disconnect = connection_header == "close"
		elseif self._request.headers:get("Content-Length") or
			self._request.headers.method == "HEAD" or
				self._request.method == "GET" then
			disconnect = connection_header ~= "keep-alive"
		else
			disconnect = true
		end
	end
	self._request = nil
	self._request_finished = false
	if disconnect then
		self.stream:close()
		return
	end
	self.stream:read_until("\r\n\r\n", self._header_callback)
end

function httpserver.HTTPConnection:_on_headers(data)
	local headers = httputil.HTTPHeaders:new(data)
	self._request = httpserver.HTTPRequest:new(headers.method, headers.uri, {
		version = headers.version,
		connection = self,
		headers = headers,
		remote_ip = self.address})
	local content_length = headers:get("Content-Length")
	if content_length then
		content_length = tonumber(content_length)
		if content_length > self.stream.max_buffer_size then
			log.error("Content-Length too long")
			self.stream:close()
		end
		if headers:get("Expect") == "100-continue" then 
			self.stream:write("HTTP/1.1 100 (Continue)\r\n\r\n")
		end
		self.stream:read_bytes(content_length, self._on_request_body)
		return
	end
	
	self:request_callback(self._request)
	-- TODO we need error handling here??
end

function httpserver.HTTPConnection:_on_request_body(data)
	self._request.body = data
	local content_type = self._request.headers:get("Content-Type")
	if content_type:match("application/x-www-form-urlencoded") then
		local arguments = _parse_post_arguments(self._request.body)
		if #arguments > 0 then
			self._request.arguments = arguments
		end
	elseif content_type:match("multipart/form-data") then
		-- TODO parse multipart data.
	end
	
	self:request_callback(self._request)
end

httpserver.HTTPRequest = class('HTTPRequest')

function httpserver.HTTPRequest:init(method, uri, args)
	
	local headers, body, remote_ip, protocol, host, files, 
	version, connection = nil, nil, nil, nil, nil, nil, "HTTP/1.0",
	nil

	if type(args) == "table" then
		version = args.version or version
		headers = args.headers
		body = args.body
		remote_ip = args.remote_ip
		protocol = args.protocol
		host = args.host
		files = args.files
		connection = args.connection
	end
	
	self.method = method
	self.uri = uri
	self.version = args.version or version
	self.headers = headers or httputil.HTTPHeaders:new()	
	self.body = body or ""

	if connection and connection.xheaders then
		self.remote_ip = self.headers:get("X-Real-Ip") or
			self.headers:get("X-Forwarded-For")
		if not self:_valid_ip(self.remote_ip) then
			self.remote_ip = remote_ip
		end
		self.protocol = self.headers:get("X-Scheme") or
			self.headers:get("X-Forwarded-Proto")
		if self.protocol ~= "http" or self.protocol ~= "https" then
			self.protocol = "http"
		end
	else
		self.remote_ip = remote_ip
		if protocol then
			self.protocol = protocol
		elseif connection and 
			instanceOf(connection.stream, iostream.SSLIOStream) then
			self.protocol = "https"
		else
			self.protocol = "http"
		end
	end
	
	self.host = host or self.headers:get("Host") or "127.0.0.1"
	self.files = files or {}
	self.connection = connection 
	self._start_time = os.time()
	self._finish_time = nil
	self.path = self.headers.url
	self.arguments = self.headers:get_arguments()
end

-- TODO: implement cookies() method

function httpserver.HTTPRequest:supports_http_1_1()
	return self.version == "HTTP/1.1"
end

function httpserver.HTTPRequest:write(chunk, callback)
	local callback = callback
	assert(type(chunk) == "string")
	self.connection:write(chunk, callback)
end

function httpserver.HTTPRequest:finish()
	self.connection:finish()
	self._finish_time = os.time()
end

function httpserver.HTTPRequest:full_url()
	return self.protocol .. "://" .. self.host .. self.uri
end

function httpserver.HTTPRequest:request_time()
	if not self._finish_time then
		return os.time() - self._start_time
	else
		return self._finish_time - self._start_time
	end
end

function httpserver.HTTPRequest:_valid_ip(ip)
	local ip = ip or ''
	return ip:find("[%d+%.]+") or nil
end

return httpserver
