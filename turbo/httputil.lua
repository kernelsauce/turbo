--- Turbo.lua HTTP Utilities module
-- Contains the HTTPHeaders class, which parses request and response headers,
-- via the node.js HTTP parser, which is based on http-parser.c. The class
-- also allows the user to build up HTTP headers programtically with the same
-- API. 
--
-- Also offers a few functions for parsing GET URL parameters, and different 
-- POST data types.
--
-- Copyright John Abrahamsen 2011, 2012, 2013 < JhnAbrhmsn@gmail.com >
--
-- "Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE."

local log = 		require "turbo.log"
local status_codes = require "turbo.http_response_codes"
local deque = 		require "turbo.structs.deque"
local escape = 		require "turbo.escape"
local util = 		require "turbo.util"
local ffi = 		require "ffi"
local ltp_loaded, libturbo_parser = pcall(ffi.load, "tffi_wrap")
if not ltp_loaded then
    -- Check /usr/local/lib explicitly also.
    ltp_loaded, libturbo_parser = 
        pcall(ffi.load, "/usr/local/lib/libtffi_wrap.so")
    if not ltp_loaded then 
        error("Could not load libtffi_wrap.so. \
            Please run makefile and ensure that installation is done correct.")
    end
end

require "turbo.cdef"
require "turbo.3rdparty.middleclass"

local fast_assert = util.fast_assert
local b = string.byte

local httputil = {} -- httputil namespace

local method_map = {
    [0] = "DELETE",
    "GET",
    "HEAD",
    "POST",
    "PUT",
    "CONNECT",
    "OPTIONS",
    "TRACE",
    "COPY",
    "LOCK",
    "MKCOL",
    "MOVE",
    "PROPFIND",
    "PROPPATCH",
    "SEARCH",
    "UNLOCK",
    "REPORT",
    "MKACTIVITY",
    "CHECKOUT",
    "MERGE",
    "MSEARCH",
    "NOTIFY",
    "SUBSCRIBE",
    "UNSUBSCRIBE",
    "PATCH",
    "PURGE"
}

httputil.UF = {
    SCHEMA           = 0
  , HOST             = 1
  , PORT             = 2
  , PATH             = 3
  , QUERY            = 4
  , FRAGMENT         = 5
  , USERINFO         = 6
}

--- HTTPHeaders Class
-- Class for creation and parsing of HTTP headers.
httputil.HTTPHeaders = class("HTTPHeaders")

--- Pass request headers as parameters to parse them into
-- the returned object. 
function httputil.HTTPHeaders:initialize(raw_request_headers)	
    self._raw_headers = nil
    self.uri = nil
    self.url = nil
    self.method = nil
    self.version = nil
    self.status_code = nil
    self.content_length = nil
    self.http_parser_url = nil -- for http_wrapper.c
    self._arguments = {}
    self._fields = {}
    self._arguments_parsed = false
    if type(raw_request_headers) == "string" then
    	local rc, httperrno, errnoname, errnodesc = 
            self:parse_request_header(raw_request_headers)
    	if rc == -1 then
    	    error(string.format(
                "Malformed HTTP headers. %s, %s", 
                errnoname, 
                errnodesc))
    	end
    end
end

local _http_parser_url = ffi.new("struct http_parser_url")
--- Parse standalone URL and populate class instance with values. 
-- @param url (String) URL string.
-- @return -1 on error, else 0 and HTTPHeaders:get_url_field must be used
-- to read out values.
function httputil.HTTPHeaders:parse_url(url)
    local rc = libturbo_parser.http_parser_parse_url(
        url, 
        url:len(), 
        0, 
        _http_parser_url)
    if rc ~= 0 then
	   return -1
    else
	   self.http_parser_url = _http_parser_url
	   self:set_uri(url)
	   return 0
    end
end

--- Get a URL field. 
-- The URL must have been parsed by the class first, either with 
-- HTTPHeader:parse_url or the HTTPHeader:parse_*_headers
-- @param UF_prop (Number) Available fields described in the httputil.UF table.
-- @return -1 if not found, else the string value is returned.
function httputil.HTTPHeaders:get_url_field(UF_prop)
    if not self.http_parser_url then
	   error("parse_request_header() or parse_url() has not been used to parse \
            the URL, get_url_field is not supported.")
    end
    -- Use the http-parser.c functions.
    if libturbo_parser.url_field_is_set(
        self.http_parser_url, UF_prop) == true then
        local field = libturbo_parser.url_field(self.uri, 
            self.http_parser_url, 
            UF_prop)
        local field_lua = ffi.string(field)
        ffi.C.free(field)
        return field_lua
    end
    -- Field is not set.
    return -1
end

--- Set URI. Mostly usefull when building up request headers, NOT when parsing
-- response headers. Parsing should be done with HTTPHeaders:parse_url.
-- @param uri (String)
function httputil.HTTPHeaders:set_uri(uri)
    if type(uri) ~= "string" then
        error("argument #1 not a string.")
    end
    self.uri = uri
end

--- Get current URI.
-- @return Currently set URI or nil if not set.
function httputil.HTTPHeaders:get_uri() return self.uri end

--- Set Content-Length attribute.
-- @param len (Number) Must be number, or error is raised.
function httputil.HTTPHeaders:set_content_length(len)
    if type(len) ~= "number" then
        error("argument #1 not a number.")
    end
    self.content_length = len
end

--- Get Content-Length attribute.
-- @return Current length as number, or nil if not set.
function httputil.HTTPHeaders:get_content_length() return self.content_length end

--- Set HTTP method.
-- @param method (String) Must be string, or error is raised.
function httputil.HTTPHeaders:set_method(method)
    if type(method) ~= "string" then
        error("argument #1 not a string.")
    end
    self.method = method
end

--- Get HTTP method
-- @return Current method as string or nil if not set.
function httputil.HTTPHeaders:get_method() return self.method end

--- Set the HTTP version.
-- Applies when building response headers only.
-- @param version (String) Version in string form, e.g "1.1" or "1.0"
-- Must be string or error is raised.
function httputil.HTTPHeaders:set_version(version)
    if type(version) ~= "string" then
	   error("argument #1 not a string.")
    end
    self.version = version
end

--- Get the current HTTP version. 
-- @return Currently set version as string or nil if not set.
function httputil.HTTPHeaders:get_version() return self.version end

--- Set the status code.
-- Applies when building response headers.
-- @param code (Number) HTTP status code to set. Must be number or
-- error is raised.
function httputil.HTTPHeaders:set_status_code(code)
    if type(code) ~= "number" then
	   error("argument #1 not a number.")
    end
    if not status_codes[code] then
	   error(string.format("Invalid HTTP status code given: %d", code))
    end
    self.status_code = code
end

--- Get the current status code.
-- @return Status code and status code message if set, else nil.
function httputil.HTTPHeaders:get_status_code()	
    return self.status_code, status_codes[self.status_code]
end

function _unescape(s) return string.char(tonumber(s,16)) end
--- Internal function to parse ? and & separated key value fields.
-- @param uri (String) 
local function _parse_arguments(uri)
    local arguments = {}
    local elements = 0;
    if (uri == -1) then
        return {}
    end
    
    for k, v in uri:gmatch("([^&=]+)=([^&]+)") do
        elements = elements + 1;
        if (elements > 256) then 
            -- Limit to 256 elements, which "should be enough for everyone".
            break 
        end
        v = v:gsub("+", " "):gsub("%%(%w%w)", _unescape);
        if not arguments[k] then
            arguments[k] = v;
        else
            if type(arguments[k]) == "string" then
                local tmp = arguments[k];
                arguments[k] = {tmp};
            end
            table.insert(arguments[k], v);
        end
    end
    return arguments
end

--- Get URL argument of the header.
-- @param argument Key of argument to get value of.
-- @return If argument exists then the argument is either returned
-- as a table if multiple values is given the same key, or as a string if the 
-- key only has one value. If argument does not exist, nil is returned.
function httputil.HTTPHeaders:get_argument(argument)
    if not self._arguments_parsed then
    	self._arguments = _parse_arguments(self:get_url_field(httputil.UF.QUERY))
    	self._arguments_parsed = true
    end
    local arguments = self:get_arguments()
    if arguments then
    	if type(arguments[argument]) == "table" then
    	    return arguments[argument]
    	elseif type(arguments[argument]) == "string" then
    	    return { arguments[argument] }
    	end
    end
end

--- Get all arguments of the header as a table. 
-- @return (Table) Table with keys and values.
function httputil.HTTPHeaders:get_arguments()
    if not self._arguments_parsed then
    	self._arguments = _parse_arguments(self:get_url_field(httputil.UF.QUERY))
    	self._arguments_parsed = true
    end
    return self._arguments
end

--- Get given key from header key value section.
-- @param key (String) The key to get.
-- @param caseinsensitive (Boolean) If true then the key will be matched without
-- regard for case sensitivity.
-- @return The value of the key, or nil if not existing. May return a table if 
-- multiple keys are set.
function httputil.HTTPHeaders:get(key, caseinsensitive)
    local value
    local cnt = 0
    if caseinsensitive == true then
        key = key:lower()
        for i = 1, #self._fields do
            if self._fields[i] and self._fields[i][1]:lower() == key then
                if cnt == 0 then
                    value = self._fields[i][2]
                    cnt = 1
                elseif cnt == 1 then
                    value = {value, self._fields[i][2]}
                    cnt = 2
                else
                    value[#value + 1] = self._fields[i][2]
                    cnt = cnt + 1
                end
            end
        end      
    else
        for i = 1, #self._fields do
            if self._fields[i] and self._fields[i][1] == key then
                if cnt == 0 then
                    value = self._fields[i][2]
                    cnt = 1
                elseif cnt == 1 then
                    value = {value, self._fields[i][2]}
                    cnt = 2
                else
                    value[#value + 1] = self._fields[i][2]
                    cnt = cnt + 1
                end
            end
        end
    end
    return value, cnt
end

--- Add a key with value to the headers. Supports adding multiple values to 
-- one key. E.g mutiple "Set-Cookie" header fields.
-- @param key (String) Key to add to headers. Must be string or error is raised.
-- @param value (String or Number) Value to associate with the key. 
function httputil.HTTPHeaders:add(key, value)
    if type(key) ~= "string" then
	   error([[method add key parameter must be a string.]])
    elseif not (type(value) == "string" or type(value) == "number") then
	   error([[method add value parameters must be a string or number.]])
    end
    self._fields[#self._fields + 1] = {key, value}
end


--- Set a key with value to the headers. Overwiting existing key.
-- @param key (String) Key to set to headers. Must be string or error is raised.
-- @param value (String) Value to associate with the key.
function httputil.HTTPHeaders:set(key, value, caseinsensitive)	
    if type(key) ~= "string" then
	   error([[method add key parameter must be a string.]])
    elseif not (type(value) == "string" or type(value) == "number") then
	   error([[method add value parameters must be a string or number.]])
    end
    self:remove(key, caseinsensitive)
    self:add(key, value)
end

--- Remove key from headers.
-- @param key (String) Key to remove from headers. Must be string or error is raised.
-- @param caseinsensitive (Boolean) If true then the key will be matched without
-- regard for case sensitivity.
function httputil.HTTPHeaders:remove(key, caseinsensitive)
    if type(key) ~= "string" then
	   error("method remove key parameter must be a string.")
    end
    if caseinsensitive == false then
        for i = 1, #self._fields do
            if self._fields[i] and self._fields[i][1] == key then
                self._fields[i] = nil
            end
        end
    else
        key = key:lower()
        for i = 1, #self._fields do
            if self._fields[i] and self._fields[i][1]:lower() == key then
                self._fields[i] = nil
            end
        end       
    end
end

--- Internal method to get errno returned by http-parser.c.
function httputil.HTTPHeaders:get_errno() return self.errno end


local nw = ffi.new("struct turbo_parser_wrapper") 
--- Parse HTTP response headers.
-- Populates the class with all data in headers.
-- @param raw_headers (String) HTTP header string.
-- @return -1 on error or parsed bytes on success.
function httputil.HTTPHeaders:parse_response_header(raw_headers)
    local sz = libturbo_parser.turbo_parser_wrapper_init(nw, raw_headers, raw_headers:len(), 1)
    
    self.errno = tonumber(nw.parser.http_errno)
    if (self.errno ~= 0) then
       local errno_name = ffi.string(libturbo_parser.http_errno_name(self.errno))
       local errno_desc = ffi.string(libturbo_parser.http_errno_description(self.errno))
	   libturbo_parser.turbo_parser_wrapper_exit(nw)
       return -1, self.errno, errno_name, errno_desc
    end
    local major_version = nw.parser.http_major
    local minor_version = nw.parser.http_minor
    local version_str = string.format("HTTP/%d.%d", major_version, minor_version)
    self:set_status_code(nw.parser.status_code)
    local keyvalue_sz = tonumber(nw.header_key_values_sz) - 1
    for i = 0, keyvalue_sz, 1 do
        local key = ffi.string(nw.header_key_values[i].key)
        local value = ffi.string(nw.header_key_values[i].value)
        self:add(key, value)
    end
    libturbo_parser.turbo_parser_wrapper_exit(nw)
    return sz
end

--- Parse HTTP request headers.
-- Populates the class with all data in headers.
-- @param raw_headers (String) HTTP header string.
-- @return -1 on error or parsed bytes on success.
function httputil.HTTPHeaders:parse_request_header(raw_headers)
    local sz = libturbo_parser.turbo_parser_wrapper_init(
        nw, 
        raw_headers, 
        raw_headers:len(), 
        0)
    
    self.errno = tonumber(nw.parser.http_errno)
    if (self.errno ~= 0) then
       local errno_name = ffi.string(
            libturbo_parser.http_errno_name(self.errno))
       local errno_desc = ffi.string(
            libturbo_parser.http_errno_description(self.errno))
	   libturbo_parser.turbo_parser_wrapper_exit(nw)
       return -1, self.errno, errno_name, errno_desc
    end
    if sz > 0 then      
        local major_version = nw.parser.http_major
        local minor_version = nw.parser.http_minor
        local version_str = string.format(
            "HTTP/%d.%d", 
            major_version, 
            minor_version)
        self._raw_headers = raw_headers
        self:set_version(version_str)
        self:set_uri(ffi.string(nw.url_str))
        self:set_method(method_map[tonumber(nw.parser.method)])
        self.http_parser_url = nw.url
        self.url = self:get_url_field(httputil.UF.PATH) 
        local keyvalue_sz = tonumber(nw.header_key_values_sz) - 1
        for i = 0, keyvalue_sz, 1 do
            local key = ffi.string(nw.header_key_values[i].key)
            local value = ffi.string(nw.header_key_values[i].value)
            self:add(key, value)
        end        
    end
    libturbo_parser.turbo_parser_wrapper_exit(nw)
    return sz;
end

--- Stringify data set in class as a HTTP request header.
-- @return (String) HTTP header string excluding final delimiter.
function httputil.HTTPHeaders:stringify_as_request()
    local buffer = deque:new()
    for i = 1, #self._fields do
        if self._fields[i] then
            buffer:append(string.format("%s: %s\r\n", 
                self._fields[i][1], self._fields[i][2]));    
        end
    end
    return string.format("%s %s %s\r\n%s\r\n",
        self.method,
        self.uri,
        self.version,
        buffer:concat())
end

local _time_str_buf = ffi.new("char[2048]")
local _time_t_headers = ffi.new("time_t[1]")
--- Stringify data set in class as a HTTP response header.
-- If not "Date" field is set, it will be generated automatically.
-- @return (String) HTTP header string excluding final delimiter.
function httputil.HTTPHeaders:stringify_as_response()
    local buffer = deque:new()
    if not self:get("Date") then
        ffi.C.time(_time_t_headers)
        local tm = ffi.C.gmtime(_time_t_headers)
        local sz = ffi.C.strftime(
            _time_str_buf, 
            2048, 
            "%a, %d %b %Y %H:%M:%S GMT", 
            tm)
        self:add("Date", ffi.string(_time_str_buf, sz))
    end
    for i = 1 , #self._fields do
        if self._fields[i] then
            buffer:append(string.format("%s: %s\r\n", 
                self._fields[i][1], self._fields[i][2]));    
        end
    end
    return string.format("%s %d %s\r\n%s\r\n",
        self.version,
        self.status_code,
        status_codes[self.status_code],
        buffer:concat())    
end

--- Convinience method to return HTTPHeaders:stringify_as_response on string
-- conversion.
function httputil.HTTPHeaders:__tostring() 
    return self:stringify_as_response() 
end

--- Parse HTTP post arguments.
function httputil.parse_post_arguments(data)
    if type(data) ~= "string" then
		error("data argument not a string.")
    end
	return _parse_arguments(data)
end

--- Parse multipart form data.
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
