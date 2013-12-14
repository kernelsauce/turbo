--- Turbo.lua Web Framework module.
-- API for asynchronous web services.
--
-- The Turbo.lua Web framework is modeled after the framework offered by
-- Tornado, which again is based on web.py (http://webpy.org/) and 
-- Google's webapp (http://code.google.com/appengine/docs/python/tools/webapp/)
-- Some modifications has been made to make it fit better into the Lua
-- eco system.
--
-- Copyright 2011, 2012, 2013 John Abrahamsen
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local log =             require "turbo.log"
local httputil =        require "turbo.httputil"
local httpserver =      require "turbo.httpserver"
local buffer =          require "turbo.structs.buffer"
local escape =          require "turbo.escape"
local response_codes =  require "turbo.http_response_codes"
local mime_types =      require "turbo.mime_types"
local util =            require "turbo.util"
local hash =            require "turbo.hash"
require('turbo.3rdparty.middleclass')

-- Use funpack instead of native as the native is not implemented in the 
-- LuaJIT compiler. Traces abort in a bad spot if not used.
local unpack = util.funpack 
local is_in = util.is_in

local web = {} -- web namespace
web.Mustache = require "turbo.mustache" -- include the Mustache templater.

--- Base RequestHandler class. The heart of Turbo.lua.
-- The usual flow of using Turbo.lua is sub-classing the RequestHandler
-- class and implementing the HTTP request methods described in 
-- self.SUPPORTED_METHODS. The main goal of this class is to wrap a HTTP
-- request and offer utilities to respond to the request. Requests are 
-- deligated to RequestHandler's by the Application class.
web.RequestHandler = class("RequestHandler")

--- Initialize a new RequestHandler class instance.
-- Normally a user is not the one to initialize this, but rather a Application
-- class instance which has recieved a HTTP request. Normal there should not be
-- a need for you to redefine this initializer,  instead look at the different
-- entry points given longer down.
-- @param application (Application instance) The calling application should
-- leave a self reference.
-- @param request (HTTPRequest instance) The request.
-- @param url_args (Table) Table of arguments to call matching method with.
-- These arguments are normally captured by the pattern given on initializing
-- of a Application class.
-- @param options (Table) 3rd argument given in Application class route table.
function web.RequestHandler:initialize(application, request, url_args, options)
    self.SUPPORTED_METHODS = {"GET", "HEAD", "POST", "DELETE", "PUT", "OPTIONS"}
    self.application = application
    self.request = request
    self._headers_written = false
    self._finished = false
    self._auto_finish = true
    self._url_args = url_args
    self._set_cookie = {}
    -- Set standard headers by calling the clear method.
    self:clear() 
    if self.request.headers:get("Connection") then
        self.request.connection.stream:set_close_callback(self.on_connection_close, self)
    end
    self.options = options
    self:on_create(self.options)
end

--- Get the applications settings.
-- @return Applications settings.
function web.RequestHandler:settings() return self.application.settings end

--*************** Entry points ***************

--- Redefine this method if you want to do something after the class has been
-- initialized. This method unlike on_create, is only called if the method has
-- been found to be supported.
function web.RequestHandler:prepare() end

--- Redefine this method if you want to do something straight after the class 
-- has been initialized. This is called after a request has been 
-- recieved, and before the HTTP method has been verified against supported
-- methods. So if a not supported method is requested, this method is still 
-- called.
function web.RequestHandler:on_create(kwargs) end

--- Redefine this method after your likings. Called after the end of a request.
-- Usage of this method could be something like a clean up etc.
function web.RequestHandler:on_finish() end

--- Redefine this method to set HTTP headers at the beginning of all the 
-- request recieved by the RequestHandler. For example setting some kind 
-- of cookie or adjusting the Server key in the headers would be sensible
-- to do in this method.
function web.RequestHandler:set_default_headers() end

--- Standard methods for RequestHandler class. 
-- Subclass RequestHandler and implement any of the following methods to handle
-- the corresponding HTTP request.
-- If not implemented they will provide a 405 (Method Not Allowed).
-- These methods recieve variable arguments, depending on what the Application
-- instance calling them has captured from the pattern matching of the request
-- URL. The methods are run protected, so they are error safe. When a error
-- occurs in the execution of these methods the request is given a 
-- 500 Internal Server Error response. In debug mode, the stack trace leading
-- to the crash is also a part of the response. If not debug mode is set, then
-- only the status code is set.
function web.RequestHandler:head(...) error(web.HTTPError:new(405)) end
function web.RequestHandler:get(...) error(web.HTTPError:new(405)) end
function web.RequestHandler:post(...) error(web.HTTPError:new(405)) end
function web.RequestHandler:delete(...) error(web.HTTPError:new(405)) end
function web.RequestHandler:put(...) error(web.HTTPError:new(405)) end
function web.RequestHandler:options(...) error(web.HTTPError:new(405)) end

--*************** Input ***************

--- Returns the value of the argument with the given name.
-- If default value is not given the argument is considered to be required and 
-- will result in a raise of a HTTPError 400 Bad Request if the argument does 
-- not exist.
-- @param name (String) Name of the argument to get.
-- @param default (String) Optional fallback value in case argument is not set.
-- @param strip (Boolean) Remove whitespace from head and tail of string.
-- @return Value of argument if set.
function web.RequestHandler:get_argument(name, default, strip)  
    local args = self:get_arguments(name, strip)
    if type(args) == "string" then
        return args
    elseif type(args) == "table" and #args > 0 then 
        return args[1]
    elseif default ~= nil then
        return default
    else
        error(web.HTTPError:new(400))
    end
end

--- Returns the values of the argument with the given name.
-- Will return a empty table if argument does not exist.
-- @param name (String) Name of the argument to get.
-- @param strip (Boolean) Remove whitespace from head and tail of string.
-- @return (Table) Argument values.
function web.RequestHandler:get_arguments(name, strip)
    local values
    local n = 0
    local url_args = self.request.arguments
    local form_args = self.request.connection.arguments

    -- Combine argument lists from HTTPConnection and HTTPRequest.
    if not url_args and not form_args then
        return
    end
    if url_args and url_args[name] then
        values = url_args[name]
        if type(values) == "table" then
            n = #values
        else
            n = 1
        end
    end
    if form_args and form_args[name] then
        if n == 0 then
            values = form_args[name]
        elseif n > 0 then
            if n == 1 then
                values = {values}    
            end
            for i = 1, #form_args[name] do
                values[#values+1] = form_args[name][i]
            end
        end
    end
    if strip then
        if type(values) == "string" then
            values = escape.trim(values)
        elseif type(values) == "table" then
            for i = 1, #values do 
                values[i] = escape.trim(values[i])
            end
        end
    end
    return values
end

--- Returns JSON request data as a table. By default, it only parses json
-- mimetype. It will return an empty table if request data is empty.
-- @param force (Boolean) if set to true, mimetype will be ignored.
-- @return (Table) parsed from request data, return nil if mimetype is not
-- json and force option is not set.
function web.RequestHandler:get_json(force)
    local content_type = self.request.headers:get("content-type", true)
    if not content_type then
        content_type = ""
    end
    if force ~= true and not content_type:find("application/json", 1, true) then
        return nil
    end
    return escape.json_decode(self.request.body)
end

--*************** Output ***************

--- Reset all headers and content for this request. Run on class initialization.
function web.RequestHandler:clear()
    self.headers = httputil.HTTPHeaders:new()
    self:set_default_headers()
    self:add_header("Server", self.application.application_name)
    if not self.request:supports_http_1_1() then
        local con = self.request.headers:get("Connection")
        if con == "Keep-Alive" or con == "keep-alive" then
            self:add_header("Connection", "Keep-Alive")
        end
    end
    self._write_buffer = buffer:new()
    self._status_code = 200
end

--- Add the given name and value pair to the HTTP response headers.
-- To overwite use the set_header method instead.
-- @param name (String) Key string for header field.
-- @param value (String or number) Value for header field.
function web.RequestHandler:add_header(name, value) 
    self.headers:add(name, value) 
end

--- Set the given name and value pair to the HTTP response headers.
-- Difference from add_header that set_header will overwrite existing header 
-- key.
-- @param name (String) Key string for header field.
-- @param value (String or number) Value for header field.
function web.RequestHandler:set_header(name, value) 
    self.headers:set(name, value) 
end

--- Returns the current value set to given key.
-- @param name (String) Key string for header field.
-- @return Value of header field or nil if not set, may return a table
-- if multiple values with same key exists.
function web.RequestHandler:get_header(key) 
    return self.headers:get(key) 
end

--- Sets the HTTP status code for our response. 
-- @param status_code The status code to set. Must be number or a error is 
-- raised.
function web.RequestHandler:set_status(status_code)
    if type(status_code) ~= "number" then
        error("set_status method requires number.")
    end
    self._status_code = status_code
end

---  Get the curent status code of the HTTP response headers.
-- @return (Number) Current HTTP status code.
function web.RequestHandler:get_status() return self._status_code end

--- Redirect client to another URL. Sets headers and finish request.   
-- User can not send data after this.
-- @note Finishes request, no further operations can be done
-- @param url (String) The URL to redirect to.
-- @param permanent (Boolean) Browser hint that says the redirect is
-- permanent.
function web.RequestHandler:redirect(url, permanent)
    if self._headers_written then
        error("Cannot redirect after headers have been written")
    end
    local status = permanent and 302 or 301
    self:set_status(status)
    self:add_header("Location", url)
    self:finish()
end

--- Get cookie value from incoming request.
-- @param name The name of the cookie to get.
-- @param default A default value if no cookie is found.
-- @return Cookie or the default value.
function web.RequestHandler:get_cookie(name, default)
    if not self._cookies_parsed then
        self:_parse_cookies()
    end
    if not self._cookies[name] then
        return default
    else
        return self._cookies[name]
    end
end

--- Get a signed cookie value from incoming request.
-- If the cookie can not be validated, then an error with a string error 
-- is raised.
-- Hash-based message authentication code (HMAC) is used to be able to verify
-- that the cookie has been created with the "cookie_secret" set in the 
-- Application class kwargs. This is simply verifing that the cookie has been 
-- signed by your key, IT IS NOT ENCRYPTING DATA.
-- @param name The name of the cookie to get.
-- @param default A default value if no cookie is found.
-- @param max_age Timestamp used to sign cookie must be not be older than this
-- value in seconds.
-- @return Cookie or the default value.
function web.RequestHandler:get_secure_cookie(name, default, max_age)
    local cookie = self:get_cookie(name)
    if not cookie then
        return default
    end
    local len, hmac, timestamp, value = cookie:match("(%d*)|(%w*)|(%d*)|(.*)")
    assert(tonumber(len) == value:len(), "Cookie value length has changed!")
    assert(hmac:len() == 40, "Could not get secure cookie. Hash to short.")
    if max_age then
        max_age = max_age * 1000 -- Get milliseconds.
        local cookietime = tonumber(timestamp)
        assert(util.getimeofday() - timestamp < max_age, "Cookie has expired.")
    end
    local hmac_cmp = hash.HMAC(self.application.kwargs.cookie_secret,
                               string.format("%d|%s", timestamp, value))
    assert(hmac == hmac_cmp, "Secure cookie does not match hash. \
                              Either the cookie is forged or the cookie secret \
                              has been changed")
    return value
end

--- Set a cookie with value to response.
-- @param name The name of the cookie to set.
-- @param value The value of the cookie.
-- @param domain The domain to apply cookie for.
-- @param expire_hours Set cookie to expire in given amount of hours.
-- @note Expiring relies on the requesting browser and may or may not be
-- respected. Also keep in mind that the servers time is used to calculate
-- expiry date, so the server should ideally be set up with NTP server.
function web.RequestHandler:set_cookie(name, value, domain, expire_hours)     
    self._set_cookie[#self._set_cookie+1] = {
        name = name,
        value = value,
        domain = domain,
        expire_hours = expire_hours or 1
    }
end

--- Set a signed cookie value to response.
-- Hash-based message authentication code (HMAC) is used to be able to verify
-- that the cookie has been created with the "cookie_secret" set in the 
-- Application class kwargs. This is simply verifing that the cookie has been 
-- signed by your key, IT IS NOT ENCRYPTING DATA.
-- @param name The name of the cookie to set.
-- @param value The value of the cookie.
-- @param domain The domain to apply cookie for.
-- @param expire_hours Set cookie to expire in given amount of hours.
-- @note Expiring relies on the requesting browser and may or may not be
-- respected. Also keep in mind that the servers time is used to calculate
-- expiry date, so the server should ideally be set up with NTP server.
function web.RequestHandler:set_secure_cookie(name, value, domain, expire_hours)
    -- The secure cookie format is as follows:
    -- Each column is separated by a pipe.
    -- value length | HMAC hash | timestamp | value
    -- timestamp and value separated by a pipe char is what is being hashed.
    assert(type(self.application.kwargs.cookie_secret) == "string", 
           "No cookie secret has been set in the Application class.")
    value = tostring(value)
    local to_hash = string.format("%d|%s", util.gettimeofday(), value)
    local cookie = string.format("%d|%s|%s", 
                                 value:len(),
                                 hash.HMAC(
                                    self.application.kwargs.cookie_secret,
                                    to_hash),
                                 to_hash)
    return self:set_cookie(name, cookie, domain, expire_hours)
end

--- Clear a cookie.
-- @param name The name of the cookie to clear.
-- @note Expiring relies on the requesting browser and may or may not be
-- respected.
function web.RequestHandler:clear_cookie(name)
    -- Clear cookie by setting expiry date to 0 and
    -- empty values...
    self:set_cookie(name, "", nil, 0)
end

--- Set handler to not call finish() when request method has been called and
-- returned. Default is false. When set to true, the user must explicitly call
-- finish.
-- @param bool (Boolean)
function web.RequestHandler:set_async(bool)
    if type(bool) ~= "boolean" then
        error("bool must be boolean!")
    end
    self._auto_finish = bool == false
end

--- Use chunked encoding on writes. Must be written before :flush() is called.
-- Once set, the mode is irreversible. Modifying the flag manually will cause
-- undefined behaviour. Call :write() as usual, and when ready to send one 
-- chunk call :flush(). finish() must be called to signal the end of the stream.
function web.RequestHandler:set_chunked_write()
    if self._headers_written == true then
        error("Headers already written, can not switch to chunked write.")
    elseif self.request.headers.method == "HEAD" then
        error("Chunked write gives no meaning for HEAD requests.")
    end
    self.chunked = true
    self:add_header("Transfer-Encoding", "chunked")
end

--- Writes the given chunk to the output buffer.            
-- To write the output to the network, use the flush() method.
-- If the given chunk is a Lua table, it will be automatically
-- stringifed to JSON.
-- @param chunk (String) Data chunk to write to underlying connection.
function web.RequestHandler:write(chunk)
    if self._finished then
        error("write() method was called after finish().")
    end
    local t = type(chunk)
    if t == "nil" then
        -- Accept writing empty blocks.
        return
    elseif t == "string" and chunk:len() == 0 then
        return
    elseif t == "table" then
        self:add_header("Content-Type", "application/json; charset=UTF-8")
        chunk = escape.json_encode(chunk)
    elseif t ~= "string" and t ~= "table" then
        error("Unsupported type written as response; "..t)
    end
    self._write_buffer:append_luastr_right(chunk)
end

--- Flushes the current output buffer to the IO stream.
-- If callback is given it will be run when the buffer has been written to the
-- socket. Note that only one callback flush callback can be present per 
-- request. Giving a new callback before the pending has been run leads to 
-- discarding of the current pending callback. For HEAD method request the 
-- chunk is ignored and only headers are written to the socket.
-- @param callback (Function) Callback function.
function web.RequestHandler:flush(callback, arg)
    local headers
    if not self._headers_written then
        self._headers_written = true
        headers = self:_gen_headers()
    end
    local chunk = tostring(self._write_buffer)
    self._write_buffer:clear()
    -- Lines below uses multiple calls to write to avoid creating new
    -- temporary strings. The write will essentially just be appended
    -- to the IOStream class, which will actually not perform any writes
    -- until the calling function returns to IOLoop. 
    if self.chunked then
        -- Transfer-Encoding: chunked support.
        if headers then
            if chunk:len() ~= 0 then
                self.request:write(headers)
                self.request:write("\r\n")
                self.request:write(util.hex(chunk:len()))
                self.request:write("\r\n")
                self.request:write(chunk)
                self.request:write("\r\n", callback, arg)
            else
                self.request:write(headers)
                self.request:write("\r\n", callback, arg)
            end
        elseif chunk:len() ~= 0 then
            self.request:write(util.hex(chunk:len()))
            self.request:write("\r\n")
            self.request:write(chunk)
            self.request:write("\r\n")
        end
    else
        -- Not chunked with Content-Length set.
        if headers then
            if self.request.headers.method == "HEAD" then
                self.request:write(headers, callback, arg)
            elseif chunk:len() ~= 0 then
                self.request:write(headers)
                self.request:write("\r\n")
                self.request:write(chunk, callback, arg)
            else
                self.request:write(headers)
                self.request:write("\r\n", callback, arg)
            end
        elseif chunk:len() ~= 0 then
            self.request:write(chunk, callback, arg)
        end
    end
end

function web.RequestHandler:_gen_headers()
    if not self:get_header("Content-Type") then
        -- No content type is set, assume that it is text/html.
        -- This might not be preferable in all cases.
        self:add_header("Content-Type", "text/html; charset=UTF-8")
    end
    if not self:get_header("Content-Length") and not self.chunked then
        -- No length is set, add current write buffer size.
        self:add_header("Content-Length", 
            tonumber(self._write_buffer:len()))
    end
    self.headers:set_status_code(self._status_code)
    self.headers:set_version("HTTP/1.1")
    if #self._set_cookie ~= 0 then
        local c = self._set_cookie
        for i = 1, #c do
            local expire_time 
            if c[i].expire_hours == 0 then
                expire_time = 0
            else
                expire_time = os.time() + (c[i].expire_hours*60*60)
            end
            local expire_str = util.time_format_cookie(expire_time)
            local cookie = string.format("%s=%s; path=%s; expires=%s",
                escape.escape(c[i].name),
                escape.escape(c[i].value or ""),
                c[i].domain or "/",
                expire_str)
            self:add_header("Set-Cookie", cookie)
        end
    end
    return self.headers:stringify_as_response()
end

--- Finishes the HTTP request. This method can only be called once for each
-- request. This method flushes all data in the write buffer.
-- @param chunk (String) Final data to write to stream before finishing.
function web.RequestHandler:finish(chunk)   
    if self._finished then
        error("finish() called twice. Something terrible has happened")
    end
    self._finished = true
    if chunk then
        self:write(chunk)
    end
    self:flush() -- Make sure everything in buffers are flushed to IOStream.
    if self.chunked then
        self.request:write("0\r\n\r\n", self._finish, self)
        return
    end
    self:_finish()
end

function web.RequestHandler:_parse_cookies()
    local cookies = {}
    local cookie_str, cnt = self.request.headers:get("Cookie")
    self._cookies_parsed = true
    self._cookies = cookies
    if cnt == 0 then
        return
    elseif cnt == 1 then
        for key, value in cookie_str:gmatch("([%a%c%w%p]+)=([%a%c%w%p]+);") do
            cookies[escape.unescape(key)] = escape.unescape(value)        
        end
    elseif cnt > 1 then
        for i = 1, cnt do
            for key, value in 
                cookie_str[i]:gmatch("([%a%c%w%p]+)=([%a%c%w%p]+);") do
                cookies[escape.unescape(key)] = escape.unescape(value)        
            end
        end
    end
end

function web.RequestHandler:_finish()
    if self._status_code == 200 then
        log.success(string.format([[[web.lua] %d %s %s %s (%s) %dms]], 
            self._status_code, 
            response_codes[self._status_code],
            self.request.headers:get_method(),
            self.request.headers:get_url(),
            self.request.remote_ip,
            self.request:request_time()))
    else
        log.warning(string.format([[[web.lua] %d %s %s %s (%s) %dms]], 
            self._status_code, 
            response_codes[self._status_code],
            self.request.headers:get_method(),
            self.request.headers:get_url(),
            self.request.remote_ip,
            self.request:request_time()))
    end
    self.request:finish()
    self:on_finish()
end

--- Called in asynchronous handlers when the connection is closed.
function web.RequestHandler:on_connection_close() end


--- Main entry point for the Application class.
function web.RequestHandler:_execute()
    -- Supported methods can be extended in inheriting classes by setting the
    -- self.SUPPORT_METHODS table.
    if not is_in(self.request.method, self.SUPPORTED_METHODS) then
        error(web.HTTPError:new(405))
    end
    self:prepare()
    if not self._finished then
        self[self.request.method:lower()](self, unpack(self._url_args))
        if self._auto_finish and not self._finished then
            self:finish()
        end
    end
end

--- Static files cache class. 
-- Files that does not exist in cache are added to cache on first read.
web._StaticWebCache = class("_StaticWebCache")
function web._StaticWebCache:initialize()
    self.files = {}
end

--- Read complete file.
-- @param path (String) Path to file.
-- @return 0 + buffer (String) on success, else -1.
function web._StaticWebCache:read_file(path)
    local fd = io.open(path, "r")
    if not fd then
        return -1, nil
    end
    local file = fd:read("*all")
    if not file then 
        return -1, nil
    end
    local sz = file:len()
    local buf = buffer(sz)
    buf:append_right(file, sz)
    return 0, buf
end

--- Get file. If not in cache, it is read and put in the global _StaticWebCache
-- class.
-- @path (String) Path to file.
-- @return 0 + buffer (String) on success, else -1.
function web._StaticWebCache:get_file(path)
    local cached_file = self.files[path]
    if cached_file then
        -- index 1 = buf
        -- index 2 = mime string
        return 0, cached_file[1], cached_file[2]
    end
    -- Fallthrough, read from disk.
    local rc, buf = self:read_file(path)
    if rc == 0 then
        local rc, mime = self:get_mime(path)
        if rc == 0 then
            self.files[path] = {buf, mime}
        else
            self.files[path] = {buf}
        end
        log.notice(string.format(
            "[web.lua] Added %s (%d bytes) to static file cache. ", 
            path, 
            tonumber(buf:len())))
        return 0, buf, mime
    else
        return -1, nil
    end

end

--- Determine MIME type according to file exstension.
-- @error If no filename is set, a error is raised.
-- @return 0 + MIME (String) on success, else -1.
function web._StaticWebCache:get_mime(path)
    if not path then
        error("No filename suplied to get_mime()")
    end
    local parts = path:split(".")
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

STATIC_CACHE = web._StaticWebCache:new() -- Global cache.
web.STATIC_CACHE = STATIC_CACHE

--- Simple static file handler class.  
-- File system path is provided in the Application class.
-- If you are planning to serve big files, then it is recommended to use a
-- proper static file web server instead. For small files that can be kept 
-- in memory it is ok.
web.StaticFileHandler = class("StaticFileHandler", web.RequestHandler)
function web.StaticFileHandler:initialize(app, request, args, options)
    web.RequestHandler.initialize(self, app, request, args) 
    if not options or type(options) ~= "string" then
        error("StaticFileHandler not initialized with correct parameters.")
    end
    self.path = options
    -- Check if this is a single file or directory.
    local last_char = self.path:sub(self.path:len())
    if self.path:sub(self.path:len()) ~= "/" then
        self.file = true
    end
end

--- Determine MIME type according to file exstension.
-- @error If no filename is set, a error is raised.
-- @return 0 + MIME (String) on success, else -1.
function web.StaticFileHandler:get_mime()
    local filename = self._url_args[1]
    if not filename then
        error("No filename suplied to get_mime()")
    end
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

function web.StaticFileHandler:_headers_flushed_cb()
    self.request:write_zero_copy(
        self._static_buffer, 
        self.finish, 
        self)
end

--- GET method for static file handling.
-- @param path The path captured from request.
function web.StaticFileHandler:get(path)
    local full_path
    if not self.file then
        if #self._url_args == 0 or self._url_args[1]:len() == 0 then
            error(web.HTTPError(404))
        end
        local filename = escape.unescape(self._url_args[1])
        if filename:match("%.%.", 0, true) then -- Prevent dir traversing.
            error(web.HTTPError(401))
        end
        full_path = string.format("%s%s", self.path, filename)
    else
        full_path = self.path
    end

    local rc, buf, mime = STATIC_CACHE:get_file(full_path)
    if rc == 0 then
        self:set_async(true)
        self._static_buffer = buf
        if mime then
            self:add_header("Content-Type", mime)
        end
        self.headers:set_status_code(200)
        self.headers:set_version("HTTP/1.1")
        self:add_header("Content-Length", tonumber(buf:len()))
        self:add_header("Cache-Control", "max-age=604800")
        self:add_header("Expires", os.date("!%a, %d %b %Y %X GMT", 
            (self.request._start_time / 1000) + 60*60*24*7))
        self:flush(web.StaticFileHandler._headers_flushed_cb, self)
    else
        error(web.HTTPError(404)) -- Not found
    end
end

--- HEAD method for static file handling.
-- @param path The path captured from request.
function web.StaticFileHandler:head(path)
    if #self._url_args == 0 or self._url_args[1]:len() == 0 then
        error(web.HTTPError(404))
    end
    local filename = self._url_args[1]
    if filename:match("%.%.", 0, true) then -- Prevent dir traversing.
        error(web.HTTPError(401))
    end
    local full_path = string.format("%s%s", self.path, 
        escape.unescape(filename))
    local rc, buf, mime = STATIC_CACHE:get_file(full_path)
    if rc == 0 then
        if mime then
            self:add_header("Content-Type", mime_type)
        end
        self:add_header("Content-Length", tonumber(buf:len()))
    else
        error(web.HTTPError(404)) -- Not found
    end
end

--- HTTPError class. 
-- This error is raisable from RequestHandler instances. It provides a 
-- convinent and safe way to handle errors in handlers. E.g it is allowed to
-- do this:
-- function MyHandler:get()
--      local item = self:get_argument("item")
--      if not find_in_store(item) then
--          error(turbo.web.HTTPError(400, "Could not find item in store"))
--      end
--      ...
-- end
-- The result is that the status code is set to 400 and the message is sent as
-- the body of the request. The request is always finished on error. 
web.HTTPError = class("HTTPError")
function web.HTTPError:initialize(code, message)
    if type(code) ~= "number" then
        error("HTTPError code argument must be number.")
    end
    self.code = code
    self.message = message and message or response_codes[code]
end

--- Class to handout HTTP errors.
-- Internal class to produce sensible error output.
web.ErrorHandler = class("ErrorHandler", web.RequestHandler)

function web.ErrorHandler:initialize(app, request, code, message)
    web.RequestHandler.initialize(self, app, request)
    if (message) then 
        self:write(message)
    else
        self:write(response_codes[code])
    end
    self:set_status(code)
    self:finish()
end

--- Static redirect handler that simple redirect the client to the given
-- URL in 3rd argument of a entry in the Application class's routing table.
-- Example:
-- local application = turbo.web.Application({
--      {"^/redirector$", turbo.web.RedirectHandler, "http://turbolua.org"}
-- })
web.RedirectHandler = class("RedirectHandler", web.RequestHandler)
function web.RedirectHandler:on_create(url)
    if not url or type(url) ~= "string" then
        error(web.HTTPError(500, 
            "RedirectHandler executed without URL argument."))
    end
    self:redirect(url, true)
end

--- The Application class is a collection of request handler classes that make 
-- together up a web application. Example:
-- local application = turbo.web.Application({
--      {"^/static/(.*)$", turbo.web.StaticFileHandler, "/var/www/"},
--      {"^/$", ExampleHandler},
--      {"^/item/(%d*)", ItemHandler}
-- })
-- The constructor of this class takes a “map” of URL patterns and their 
-- respective handlers. The third element in the table are optional parameters 
-- the handler class might have. This could be a single value or a table. 
-- E.g the turbo.web.StaticFileHandler class takes the root path for your 
-- static handler.
-- The first element in the table is the URL that the application class matches 
-- incoming request with to determine which handler it should be sent to. These 
-- URLs simply be a URL or a any kind of Lua pattern. The ItemHandler URL 
-- pattern is an example on how to map numbers from URL to your handlers. 
-- Pattern encased in parantheses are used as parameters when calling the 
-- request methods in Request handlers.
web.Application = class("Application")

--- Initialize a new Application class instance.
-- @param handlers (Table) As described above.
-- @param kwargs (Table) Key word arguments.
-- Key word arguments supported:
-- "default_host" = Redirect to this URL if no matching handler is found.
-- "cookie_secret" = Sequence of bytes used for to sign cookies.
function web.Application:initialize(handlers, kwargs)
    self.handlers = handlers or {}
    self.kwargs = kwargs or {}
    self.default_host = self.kwargs.default_host
    self.application_name = self.kwargs.application_name or "Turbo.lua 1.0"
end

--- Sets the server name.
-- @param name (String) Set the server name of the Application.
function web.Application:set_server_name(name) 
    self.application_name = name 
end

--- Returns the server name.
-- @return (String) Server name.
function web.Application:get_server_name() return self.application_name end

--- Add handler to Application.
-- @param pattern (String) Lua pattern string.
-- @param handler (RequestHandler class)
-- @param arg Argument for handler.
function web.Application:add_handler(pattern, handler, arg)
    self.handler[#self.handler + 1] = {pattern, handler, arg}
end

--- Starts an HTTP server for this application on the given port.
-- This is really just a convinence method. The same effect can be achieved
-- by creating a HTTPServer class instance and assigning the Application to 
-- instance to its request_callback parameter and calling its listen() 
-- method.
-- @param port (Number) The port number to bind to.
-- @param address (Number) The address to bind to in unsigned integer hostlong
-- format. 0 = all addresses available.
function web.Application:listen(port, address, kwargs)
    -- Key word arguments supported:
    -- ** SSL Options **
    -- To enable SSL remember to set the _G.TURBO_SSL global.
    -- "key_file" = SSL key file if a SSL enabled server is wanted.
    -- "cert_file" = Certificate file. key_file must also be set.
    local server = httpserver.HTTPServer:new(self, nil, nil, nil, kwargs)
    server:listen(port, address)
end

--- Find a matching request handler for the request object.
-- Simply match the URI against the pattern matches supplied to the Application
-- class.
-- @param request (HTTPRequest instance)
function web.Application:_get_request_handlers(request)
    local path = request.path and request.path:lower()
    if not path then 
        path = "/"
    end
    local handlers_sz = #self.handlers
    for i = 1, handlers_sz do 
        local handler = self.handlers[i]
        local pattern = handler[1]
        local match = {path:match(pattern)}
        if #match > 0 then
            return handler[2], match, handler[3]
        end
    end
end

--- Entry point for requests recieved by HTTPServer.
-- @param request (HTTPRequest instance)
function web.Application:__call(request)
    local handler = nil
    local handlers, args, options = self:_get_request_handlers(request)
    if handlers then    
        handler = handlers(self, request, args, options)
        local status, err = pcall(handler._execute, handler)
        if err then
            if instanceOf(web.HTTPError, err) then
                handler = web.ErrorHandler:new(self, 
                    request, 
                    err.code, 
                    err.message)
            else 
                local trace = debug.traceback()
                log.error("[web.lua] " .. err)
                log.stacktrace(trace)
                handler = web.ErrorHandler:new(self, 
                    request, 
                    500, 
                    string.format("<pre>%s\n%s\n</pre>", err, trace))
            end
        end
    elseif not handlers and self.default_host then 
        handler = web.RedirectHandler:new(self.default_host)
    else
        handler = web.ErrorHandler:new(self, request, 404)
    end
end

return web
