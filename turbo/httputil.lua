--[[ Turbo HTTPUtil module

Copyright John Abrahamsen 2011, 2012, 2013 < JhnAbrhmsn@gmail.com >

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


local log = 		require "turbo.log"
local status_codes = 	require "turbo.http_response_codes"
local deque = 		require "turbo.structs.deque"
local escape = 		require "turbo.escape"
local util = 		require "turbo.util"
local ffi = 		require "ffi"
local libturbo_parser = ffi.load "libturbo_parser"
require "turbo.3rdparty.middleclass"

local fast_assert = util.fast_assert
local b = string.byte


local httputil = {} -- httputil namespace

if not _G.HTTP_PARSER_H then
    _G.HTTP_PARSER_H = 1
    ffi.cdef[[
    
    enum http_parser_url_fields
    { UF_SCHEMA           = 0
    , UF_HOST             = 1
    , UF_PORT             = 2
    , UF_PATH             = 3
    , UF_QUERY            = 4
    , UF_FRAGMENT         = 5
    , UF_USERINFO         = 6
    , UF_MAX              = 7
    };
    
    struct http_parser {
    /** PRIVATE **/
    unsigned char type : 2;     /* enum http_parser_type */
    unsigned char flags : 6;    /* F_* values from 'flags' enum; semi-public */
    unsigned char state;        /* enum state from http_parser.c */
    unsigned char header_state; /* enum header_state from http_parser.c */
    unsigned char index;        /* index into current matcher */
  
    uint32_t nread;          /* # bytes read in various scenarios */
    uint64_t content_length; /* # bytes in body (0 if no Content-Length header) */
  
    /** READ-ONLY **/
    unsigned short http_major;
    unsigned short http_minor;
    unsigned short status_code; /* responses only */
    unsigned char method;       /* requests only */
    unsigned char http_errno : 7;
    
    /* 1 = Upgrade header was present and the parser has exited because of that.
     * 0 = No upgrade header present.
     * Should be checked when http_parser_execute() returns in addition to
     * error checking.
     */
    unsigned char upgrade : 1;
  
    /** PUBLIC **/
    void *data; /* A pointer to get hook to the "connection" or "socket" object */
    };
      
    struct http_parser_url {
      uint16_t field_set;           /* Bitmask of (1 << UF_*) values */
      uint16_t port;                /* Converted UF_PORT string */
    
      struct {
        uint16_t off;               /* Offset into buffer in which field starts */
        uint16_t len;               /* Length of run in buffer */
      } field_data[7];
    };
    
    struct turbo_key_value_field{
        char *key; ///< Header key.
        char *value; ///< Value corresponding to key.
    };
    
    /** Used internally  */
    enum header_state{
        NOTHING,
        FIELD,
        VALUE
    };
    
    /** Wrapper struct for http_parser.c to avoid using callback approach.   */
    struct turbo_parser_wrapper{
        struct http_parser parser;
        int32_t http_parsed_with_rc;
        struct http_parser_url url;
    
        bool finished; ///< Set on headers completely parsed, should always be true.
        char *url_str;
        char *body;
        const char *data; ///< Used internally.
    
        bool headers_complete;
        enum header_state header_state; ///< Used internally.
        int32_t header_key_values_sz; ///< Size of key values in header that is in header_key_values member.
        struct turbo_key_value_field **header_key_values;
    
    };
    
    extern size_t turbo_parser_wrapper_init(struct turbo_parser_wrapper *dest, const char* data, size_t len, int32_t type);
    /** Free memory and memset 0 if PARANOID is defined.   */
    extern void turbo_parser_wrapper_exit(struct turbo_parser_wrapper *src);
    
    int32_t http_parser_parse_url(const char *buf, size_t buflen, int32_t is_connect, struct http_parser_url *u);
    /** Check if a given field is set in http_parser_url  */
    extern bool url_field_is_set(const struct http_parser_url *url, enum http_parser_url_fields prop);
    extern char *url_field(const char *url_str, const struct http_parser_url *url, enum http_parser_url_fields prop);
    /* Return a string name of the given error */
    const char *http_errno_name(int32_t err);
    /* Return a string description of the given error */
    const char *http_errno_description(int32_t err);
    
    void free(void* ptr);
    ]]
end


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


local function parse_url_part(uri_str, http_parser_url, UF_prop)
    if (libturbo_parser.url_field_is_set(http_parser_url, UF_prop) == true) then
        local field = libturbo_parser.url_field(uri_str, http_parser_url, UF_prop)
        local field_lua = ffi.string(field)
        ffi.C.free(field)
        return field_lua
    end
    return -1 
end


local function parse_arguments(uri)
    local arguments = {}
    local elements = 0;
    if (uri == -1) then
	return {}
    end
    
    for k, v in uri:gmatch("([^&=]+)=([^&]+)") do
	elements = elements + 1;
	if (elements > 256) then break end
	v = v:gsub("+", " "):gsub("%%(%w%w)", function(s) return char(tonumber(s,16)) end);
	if (not arguments[k]) then
	    arguments[k] = v;
	else
	    if ( type(arguments[k]) == "string") then
		local tmp = arguments[k];
		arguments[k] = {tmp};
	    end
	    table.insert(arguments[k], v);
	end
    end

    return arguments
end

--[[ HTTPHeaders Class
Class for creation and parsing of HTTP headers.    --]]
httputil.HTTPHeaders = class("HTTPHeaders")

--[[ Pass headers as parameters to parse them into
the returned object.   ]]
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
    self._header_table = {}
    self._arguments_parsed = false
    if type(raw_request_headers) == "string" then
	local rc, httperrno, errnoname, errnodesc = self:parse_request_header(raw_request_headers)
	if (rc == -1) then
	    error(string.format("Malformed HTTP headers. %s, %s", errnoname, errnodesc))
	end
    end
end

function httputil.HTTPHeaders:parse_url(url)
    local http_parser_url = ffi.new("struct http_parser_url")
    local rc = libturbo_parser.http_parser_parse_url(url, url:len(), 0, http_parser_url)
    if (rc ~= 0) then
	return -1
    else
	self.http_parser_url = http_parser_url
	self:set_uri(url)
	return 0
    end
end

function httputil.HTTPHeaders:get_url_field(UF_prop)
    fast_assert(self.http_parser_url, "parse_request_header() or parse_url() has not been used to parse the URL, get_url_field is not supported.")
    return parse_url_part(self.uri, self.http_parser_url, UF_prop)
end

function httputil.HTTPHeaders:set_uri(uri)
    fast_assert(type(uri) == "string", [[method set_url requires string, were: %s]], type(uri))
    self.uri = uri
end

function httputil.HTTPHeaders:get_uri() return self.uri end

function httputil.HTTPHeaders:set_content_length(len)
    fast_assert(type(len) == "number", [[method set_content_length requires number, was: %s]], type(len))
    self.content_length = len
end

function httputil.HTTPHeaders:get_content_length() return self.content_length end

function httputil.HTTPHeaders:set_method(method)
    fast_assert(type(method) == "string", [[method set_method requires string, was: %s]], type(method))
    self.method = method
end

function httputil.HTTPHeaders:get_method() return self.method end

--[[ Set the HTTP version.
Applies most probably for response headers.  ]]
function httputil.HTTPHeaders:set_version(version)
    fast_assert(type(version) == "string", [[method set_version requires string, was: %s]], type(version))
    self.version = version
end

--[[ Get the current HTTP version.   ]]
function httputil.HTTPHeaders:get_version() return self.version or nil end

--[[ Set the status code.
Applies most probably for response headers.      ]]
function httputil.HTTPHeaders:set_status_code(code)
    fast_assert(type(code) == "number", [[method set_status_code requires int.]])
    fast_assert(status_codes[code], [[Invalid HTTP status code given: %d]], code)
    self.status_code = code
end

--[[ Get the current status code.    ]]
function httputil.HTTPHeaders:get_status_code()	
    return self.status_code, status_codes[self.status_code]
end


--[[ Get one argument of the header.  ]]
function httputil.HTTPHeaders:get_argument(argument)
        if not self._arguments_parsed then
            self._arguments = parse_arguments(self:get_url_field(httputil.UF.QUERY))
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

--[[ Get all arguments of the header. ]]
function httputil.HTTPHeaders:get_arguments()
        if not self._arguments_parsed then
            self._arguments = parse_arguments(self:get_url_field(httputil.UF.QUERY))
            self._arguments_parsed = true
        end
	return self._arguments or nil
end

--[[ Get given key from headers.	]]
function httputil.HTTPHeaders:get(key, caseinsensitive)
    local fast_path = self._header_table[key]
    if (fast_path) then
	return fast_path
    elseif (caseinsensitive) then
	-- Slow path, match against lowered chars.
	local match_key = key:lower()
	for key, value in pairs(self._header_table) do
	    local lowerkey = key:lower()
	    if (lowerkey == match_key) then
		return value
	    end
	end
    end
    return nil
end

--[[ Add a key with value to the headers.     ]]
function httputil.HTTPHeaders:add(key, value)
	fast_assert(type(key) == "string", [[method add key parameter must be a string.]])
	fast_assert((type(value) == "string" or type(value) == "number"), [[method add value parameters must be a string or number.]])
	fast_assert((not self._header_table[key]), [[trying to add a value to a existing key]])
	self._header_table[key] = value
end


--[[ Set a key with value to the headers.
If key exists then the value is overwritten.
If key does not exists a new is created with its value.   ]]
function httputil.HTTPHeaders:set(key, value)	
	fast_assert(type(key) == "string", [[method add key parameter must be a string.]])
	fast_assert((type(value) == "string" or type(value) == "number"), [[method add value parameters must be a string or number.]])	
	self._header_table[key]	= value
end

--[[ Remove key from headers.    ]]
function httputil.HTTPHeaders:remove(key)
    fast_assert(type(key) == "string", "method remove key parameter must be a string.")
    self._header_table[key]  = nil
end

function httputil.HTTPHeaders:get_errno() return self.errno end


function httputil.HTTPHeaders:parse_response_header(raw_headers)
    local nw = ffi.new("struct turbo_parser_wrapper")
    local sz = libturbo_parser.turbo_parser_wrapper_init(nw, raw_headers, raw_headers:len(), 1)
    
    self.errno = tonumber(nw.parser.http_errno)
    if (self.errno ~= 0) then
        local errno_name = libturbo_parser.http_errno_name(self.errno)
        local errno_desc = libturbo_parser.http_errno_description(self.errno)
        libturbo_parser.turbo_parser_wrapper_exit(nw)
        return -1, self.errno, ffi.string(errno_name), ffi.string(errno_desc)
    end
    
    local major_version = nw.parser.http_major
    local minor_version = nw.parser.http_minor
    local version_str = string.format("HTTP/%d.%d", major_version, minor_version)
    self:set_status_code(nw.parser.status_code)
    local keyvalue_sz = tonumber(nw.header_key_values_sz) - 1
    for i = 0, keyvalue_sz, 1 do
        local key = ffi.string(nw.header_key_values[i].key)
        local value = ffi.string(nw.header_key_values[i].value)
        self:set(key, value)
    end
    
    libturbo_parser.turbo_parser_wrapper_exit(nw)
    return sz
end

function httputil.HTTPHeaders:parse_request_header(raw_headers)
    local nw = ffi.new("struct turbo_parser_wrapper")
    local sz = libturbo_parser.turbo_parser_wrapper_init(nw, raw_headers, raw_headers:len(), 0)
    ffi.gc(nw, libturbo_parser.turbo_parser_wrapper_exit)
    
    self.errno = tonumber(nw.parser.http_errno)
    if (self.errno ~= 0) then
        local errno_name = libturbo_parser.http_errno_name(self.errno)
        local errno_desc = libturbo_parser.http_errno_description(self.errno)
        return -1, self.errno, ffi.string(errno_name), ffi.string(errno_desc)
    end
    
    if (sz > 0) then      
        local major_version = nw.parser.http_major
        local minor_version = nw.parser.http_minor
        local version_str = string.format("HTTP/%d.%d", major_version, minor_version)
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
            self:set(key, value)
        end        
    end
    
    return sz;
end


function httputil.HTTPHeaders:stringify_as_request()
    local buffer = deque:new()
    for key, value in pairs(self._header_table) do
            buffer:append(string.format("%s: %s\r\n", key , value));
    end
    return string.format("%s %s %s\r\n%s\r\n",
                         self.method,
                         self.uri,
                         self.version,
                         buffer:concat())
end

function httputil.HTTPHeaders:stringify_as_response()
    local buffer = deque:new()
    if not self:get("Date") then
            self:add("Date", os.date("!%a, %d %b %Y %X GMT", os.time()))
    end
    for key, value in pairs(self._header_table) do
            buffer:append(string.format("%s: %s\r\n", key , value));
    end
    return string.format("%s %d %s\r\n%s\r\n",
                         self.version,
                         self.status_code,
                         status_codes[self.status_code],
                         buffer:concat())    
end

--[[ Assembles HTTP headers based on the information in the object.  ]]
function httputil.HTTPHeaders:__tostring() return self:stringify_as_response() end


function httputil.parse_post_arguments(data)
    fast_assert(type(data) == "string", "data into _parse_post_arguments() not a string.")
    local arguments_string = data:match("?(.+)")
    local arguments = {}
    local elements = 0;
    for k, v in arguments_string:gmatch("([^&=]+)=([^&]+)") do
	elements = elements + 1;
	if (elements > 256) then
	    break
	end
	v = v:gsub("+", " "):gsub("%%(%w%w)", function(s) return char(tonumber(s,16)) end);
	if (not arguments[k]) then
		arguments[k] = v;
	else
	    if (type(arguments[k]) == "string") then
	        local tmp = arguments[k];
		arguments[k] = {tmp};
	    end
	    table.insert(arguments[k], v);
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
