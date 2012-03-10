--[[
	
	Nonsence Asynchronous event based Lua Web server.
	Author: John Abrahamsen < JhnAbrhmsn@gmail.com >
	
	This module "httputil" is a part of the Nonsence Web server.
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
local status_codes = assert(require('http_response_codes'),
	[[Missing http_status_codes module]])
local deque = assert(require('deque'), 
	[[Missing required module: deque]])
assert(require('middleclass'), 
	[[Missing required module: MiddleClass 
	https://github.com/kikito/middleclass]])
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- Speeding up globals access with locals :>
--
local status_codes, time, date, insert, type, char, gsub, byte, 
ipairs, format = status_codes, os.time, os.date, table.insert, type, 
string.char, string.gsub, string.byte, ipairs, string.format
-------------------------------------------------------------------------
-- Table to return on require.
local httputil = {}
-------------------------------------------------------------------------

--[[

	HTTPHeaders Class
	
	Class for creation and parsing of HTTP headers.
	
	Methods:
	set_status_code(code)		Set the HTTP status code.
	get_status_code()		Get the current status code.
	add(key, value)			Add given key with value.
	remove(key)			Removes the given key.
	get(key)			Returns the given keys value.
	set_version(version)		Set the HTTP version.
	get_version()			Get the HTTP version.
	get_argument(key)		Get the argument by key.
	get_arguments()			Get all arguments.
	
	Metamethods:
	__tostring()			Stringify the HTTP Header.
	
--]]
httputil.HTTPHeaders = class("HTTPHeaders")

function httputil.HTTPHeaders:init(raw_request_headers)
	-- Init HTTPHeaders object.
	-- Pass headers as parameters to parse them into
	-- the returned object.
	
	self._raw_headers = raw_request_headers
	self.uri = nil
	self.url = nil
	self.method = nil
	self.version = nil
	self.status_code = nil
	self.version = nil
	self._arguments = {}
	self._header_table = {}
	if type(raw_request_headers) == "string" then
		self:update(raw_request_headers)
	end
end

function httputil.HTTPHeaders:set_version(version)
	-- Set the HTTP version.
	-- Applies most probably for response headers.
	
	assert(type(version) == "string", [[method set_version requires string.]])
	self.version = version
end

function httputil.HTTPHeaders:get_version()
	-- Get the current HTTP version.
	
	return self.version or nil
end
function httputil.HTTPHeaders:set_status_code(code)
	-- Set the status code.
	-- Applies most probably for response headers.
	
	assert(type(code) == "number", [[method set_status_code requires int.]])
	assert(status_codes[code], [[Invalid HTTP status code given: ]] .. code)
	self.status_code = code
end

function httputil.HTTPHeaders:get_status_code()
	-- Get the current status code.
	
	return self.status_code or nil, status_codes[self.status_code] or nil
end

function httputil.HTTPHeaders:_parse_line(line)
	-- Parse HTTP header line in the key, value
	-- section.
	
	assert(type(line) == "string", 
		[[method _parse_line expects string value.]])
	local key, value = line:match("([%a*%-*]+):[%s-](.+)")
	return key, value
end

function httputil.HTTPHeaders:_parse_method_uri(line)
	-- Parse HTTP header first line.
	
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

function httputil.HTTPHeaders:get_argument(argument)
	-- Get one argument of the header.
	
	return self._arguments[argument] or nil
end

function httputil.HTTPHeaders:get_arguments()
	-- Get all arguments of the header.
	
	return self._arguments or nil
end

function httputil.HTTPHeaders:get(key)
	-- Get given key from headers.
	
	return self._header_table[key] or nil
end

function httputil.HTTPHeaders:add(key, value)
	-- Add a key with value to the headers.

	assert(type(key) == "string", 
		[[method add key parameter must be a string.]])
	assert(type(value) == "string", 
		[[method add value parameters must be a string.]])
	self._header_table[key] = value
end

function httputil.HTTPHeaders:remove(key)
	-- Remove key from headers.

	assert(type(key) == "string", 
		[[method remove key parameter must be a string.]])
	self._header_table[key]  = nil
end

function httputil.HTTPHeaders:update(raw_headers)
	-- Update the header object with raw headers.
	-- Typically used when parsing a HTTP request header.
	
	-- Parse method, URI and HTTP version.
	local method, uri, url, version = self:_parse_method_uri(raw_headers:match("[^\r\n]+"))
	self.method = method
	self.uri = uri
	self:_parse_arguments(uri)
	self.url = url
	self.version = version
	
	-- Parse key, value section.
	for line in raw_headers:gmatch("[^\r\n]+") do
		local key, value = self:_parse_line(line)
		if key and value then
			self:add(key, value)
		end
	end
end

function httputil.HTTPHeaders:__tostring()
	-- Assembles HTTP headers based on the information
	-- in the object.
	
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
	return buffer:concat()
end

function httputil.parse_post_arguments(data)
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

return httputil
