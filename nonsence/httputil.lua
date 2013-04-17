--[[ Nonsence Asynchronous event based Lua Web server.
Author: John Abrahamsen < JhnAbrhmsn@gmail.com >

This module "httputil" is a part of the Nonsence Web server.
For the complete stack hereby called "software package" please see:

https://github.com/JohnAbrahamsen/nonsence-ng/

Many of the modules in the software package are derivatives of the 
Tornado web server. Tornado is licensed under Apache 2.0 license.
For more details on Tornado please see:

http://www.tornadoweb.org/

However, this module, httputil is not a derivate of Tornado and are
hereby licensed under the MIT license.

http://www.opensource.org/licenses/mit-license.php >:

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
SOFTWARE."             ]]

  
local log, status_codes, deque, escape = require('log'),
require('http_response_codes'),require('deque'), require('escape')

require('middleclass')

local status_codes, time, date, insert, type, char, gsub, byte, 
ipairs, format, strlower = status_codes, os.time, os.date, table.insert, type, 
string.char, string.gsub, string.byte, ipairs, string.format, string.lower

local httputil = {} -- httputil namespace


--[[ HTTPHeaders Class
Class for creation and parsing of HTTP headers.    --]]
httputil.HTTPHeaders = class("HTTPHeaders")

--[[ Pass headers as parameters to parse them into
the returned object.   ]]
function httputil.HTTPHeaders:init(raw_request_headers)	
	self._raw_headers = raw_request_headers
	self.uri = nil
	self.url = nil
	self.method = nil
	self.version = nil
	self.status_code = nil
	self.version = nil
        self.content_length = nil
	self._arguments = {}
	self._header_table = {}
	if type(raw_request_headers) == "string" then
		self:update(raw_request_headers)
	end
end

function httputil.HTTPHeaders:set_uri(uri)
        assert(type(uri) == "string", [[method set_url requires string, were: ]] .. type(uri))
        self.uri = uri
end

function httputil.HTTPHeaders:get_uri() return self.uri end

function httputil.HTTPHeaders:set_content_length(len)
    	assert(type(len) == "number", [[method set_content_length requires number, was: ]] .. type(len))
        self.content_length = len
end

function httputil.HTTPHeaders:get_content_length() return self.content_length end

function httputil.HTTPHeaders:set_method(method)
        assert(type(method) == "string", [[method set_method requires string, was: ]] .. type(method))
        self.method = method
end

function httputil.HTTPHeaders:get_method() return self.method end

--[[ Set the HTTP version.
Applies most probably for response headers.  ]]
function httputil.HTTPHeaders:set_version(version)
	assert(type(version) == "string", [[method set_version requires string, was: ]] .. type(version))
	self.version = version
end

--[[ Get the current HTTP version.   ]]
function httputil.HTTPHeaders:get_version() return self.version or nil end

--[[ Set the status code.
Applies most probably for response headers.      ]]
function httputil.HTTPHeaders:set_status_code(code)
	assert(type(code) == "number", [[method set_status_code requires int.]])
	assert(status_codes[code], [[Invalid HTTP status code given: ]] .. code)
	self.status_code = code
end

--[[ Get the current status code.    ]]
function httputil.HTTPHeaders:get_status_code()	
	return self.status_code or nil, status_codes[self.status_code] or nil
end

--[[ Parse HTTP header line in the key, value section.     ]]
function httputil.HTTPHeaders:_parse_line(line)	
	assert(type(line) == "string", 
		[[method _parse_line expects string value.]])
	local key, value = line:match("([%a*%-*]+):[%s-](.+)")
	return key, value
end

--[[ Parse HTTP header first line.   ]]
function httputil.HTTPHeaders:_parse_method_uri(line)	
	assert(type(line) == "string", 
		[[method _parse_line expects string value.]])
	local method, uri, version = line:match("([%a*]+)%s+(.+)%s+(.+)")
	local url = uri:match("(.-)%?")
	if not url then 
		url = uri 
	end
	return method, uri, url, version
end

function httputil.HTTPHeaders:_parse_arguments(uri)
	local arguments_string = uri:match("?(.+)")
	local arguments = {}
	local noDoS = 0;
	if not arguments_string then return end
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
	self._arguments = arguments
end

--[[ Get one argument of the header.  ]]
function httputil.HTTPHeaders:get_argument(argument)
	local arguments = self:get_arguments()
	if arguments then
		if type(arguments[argument]) == "table" then
			return arguments[argument]
		
		elseif type(arguments[argument]) == "string" then
			return { arguments[argument] }
			
		end
	end
end

--[[ Get all arguments of the header. ]]
function httputil.HTTPHeaders:get_arguments()
	return self._arguments or nil
end

--[[ Get given key from headers.	]]
function httputil.HTTPHeaders:get(key)
	return self._header_table[key] or nil
end

--[[ Add a key with value to the headers.     ]]
function httputil.HTTPHeaders:add(key, value)
	assert(type(key) == "string", 
		[[method add key parameter must be a string.]])
	assert((type(value) == "string" or type(value) == "number"), 
		[[method add value parameters must be a string.]])
	assert((not self._header_table[key]), 
		[[trying to add a value to a existing key]])
	self._header_table[key] = value
end


--[[ Set a key with value to the headers.
If key exists then the value is overwritten.
If key does not exists a new is created with its value.   ]]
function httputil.HTTPHeaders:set(key, value)	
	assert(type(key) == "string", 
		[[method add key parameter must be a string.]])
	assert((type(value) == "string" or type(value) == "number"), 
		[[method add value parameters must be a string.]])
	
	self._header_table[key]	= value
end

--[[ Remove key from headers.    ]]
function httputil.HTTPHeaders:remove(key)
	assert(type(key) == "string", 
		[[method remove key parameter must be a string.]])
	self._header_table[key]  = nil
end


--[[ Update the header object with raw headers.
Typically used when parsing a HTTP request header.	
Parse method, URI and HTTP version.         ]]
function httputil.HTTPHeaders:update(raw_headers)
	local method, uri, url, version = self:_parse_method_uri(raw_headers:match("[^\r\n]+"))
	self.method = method
	self.uri = uri
	self:_parse_arguments(uri)
	self.url = url
	self.version = version

	for line in raw_headers:gmatch("[^\r\n]+") do
		local key, value = self:_parse_line(line)
		if key and value then
			self:add(key, value)
		end
	end
end

--[[ Assembles HTTP headers based on the information in the object.  ]]
function httputil.HTTPHeaders:__tostring()	
	local buffer = deque:new()
	buffer:append(self.version .. " ")
	buffer:append(self.status_code .. " " .. status_codes[self.status_code])
	buffer:append("\r\n")
	if not self:get("Date") then
		self:add("Date", date("!%a, %d %b %Y %X GMT", time()))
	end
	for key, value in pairs(self._header_table) do
		buffer:append(key .. ": " .. value .. "\r\n")
	end
	buffer:append("\r\n")
	return buffer:concat()
end

function httputil.parse_post_arguments(data)
	assert(type(data) == "string", "data into _parse_post_arguments() not a string.")
	local arguments_string = data:match("?(.+)")
	local arguments = {}
	local noDoS = 0;
	for k, v in arguments_string:gmatch("([^&=]+)=([^&]+)") do
		noDoS = noDoS + 1;
		if (noDoS > 256) then break; end
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

--[[ Parse multipart form data.    ]]
function httputil.parse_multipart_data(data)  
	local arguments = {}
	local data = escape.unescape(data)
	
	for key, ctype, name, value in 
		data:gmatch("([^%c%s:]+):%s+([^;]+); name=\"([%w]+)\"%c+([^%c]+)") do
		
		if ctype == "form-data" then
			if arguments[name] then
				arguments[name][#arguments[name] +1] = value
			else
				arguments[name] = { value }
			end
		end
		
	end
	
	return arguments
end

return httputil
