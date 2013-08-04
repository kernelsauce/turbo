--- Turbo.lua Asynchronous builtins module
-- Builtin async features of Turbo.lua:
-- * HTTP Client
--
-- Copyright 2013 John Abrahamsen
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

local iostream =            require "turbo.iostream"
local ioloop =              require "turbo.ioloop"
local httputil =            require "turbo.httputil"
local util =                require "turbo.util"
local socket =              require "turbo.socket_ffi"
local log =                 require "turbo.log"
local http_response_codes = require "turbo.http_response_codes"
local coctx =               require "turbo.coctx"
local deque =               require "turbo.structs.deque"
local escape =              require "turbo.escape"
local crypto =              _G.TURBO_SSL and require "turbo.crypto"
require "turbo.3rdparty.middleclass"

local fassert = util.fast_assert
local AF_INET = socket.AF_INET

local async = {} -- async namespace

--- HTTPClient class
-- Based on the IOStream/SSLIOStream and IOLoop classes.
-- Designed to asynchronously communicate with a HTTP server via the Turbo I/O 
-- Loop. The user MUST use Lua's builtin coroutines to manage yielding, after 
-- doing a request. The aim for the client is to support as many standards of 
-- HTTP as possible. However there may be some artifacts as there usually are 
-- many compability fixes in equivalent software such as curl.
-- Websockets are not handled by this class. It is the users responsibility to 
-- check the returned values for errors before usage.
--
-- When using this class, keep in mind that it is not supported to launch 
-- muliple :fetch()'s with the same class instance. If the instance is already 
-- in use then it will return a error.
--
-- Note: Do not throw errors in this class. The caller will not recieve them as
-- all the code is done outside the yielding coroutines call stack, except for 
-- calls to fetch(). But for the sake of continuity, there are no raw errors 
-- thrown from this method either.
--
-- Simple usage:
-- local res = coroutine.yield(
--    turbo.async.HTTPClient:new():fetch("http://search.twitter.com/search.json",
--    {params = { q=search, result_type="mixed"}
-- }))
--
-- The res variable will contain a HTTPResponse class instance. This class has 
-- a few attributes.
-- self.request = (HTTPHeaders class instance) The request header sent to 
--  the server.
-- self.code = (Number) The response code
-- self.headers = (HTTPHeader class instance) Response headers recieved from 
--  the server.
-- self.body = (String) Body of response
-- self.error = (Table) Table with code and message members. Possible codes is
--  defined in async.errors.
-- self.request_time = (Number) msec used to process request.
--
-- It is allways a good idea to first check if the self.error member is set
-- before, using the response. If it is set, this means that most of the other
-- members is not available. The request were not successfull.
--
-- Also remember that HTTPClient:fetch must be called from within the IOLoop
-- as a callback. Using it directly in a RequestHandler method is fine as that
-- is handled inside the IOLoop, however using the class standalone it would 
-- be required that you use IOLoop:add_callback to place a function on the 
-- IOLoop and yield from within that function.
async.HTTPClient = class("HTTPClient")


--- Create a new HTTPClient class instance.
-- One instance can serve 1 request at a time. If multiple request should be
-- sent then create multiple instances.
-- ssl_options kwargs:
-- "priv_file" SSL / HTTPS private key file.              
-- "cert_file" SSL / HTTPS certificate key file.          
-- "verify_ca" SSL / HTTPS verify servers certificate.    
-- "ca_path" SSL / HTTPS CA certificate verify location 
function async.HTTPClient:initialize(ssl_options, io_loop, max_buffer_size)
    self.family = AF_INET
    self.io_loop = io_loop or ioloop.instance()
    self.max_buffer_size = max_buffer_size
    self.ssl_options = ssl_options
end

--- Errors that can be set in the return object of fetch (HTTPResponse instance).
local errors = {
     INVALID_URL            = -1 -- URL could not be parsed.
    ,INVALID_SCHEMA         = -5 -- Invalid URL schema
    ,COULD_NOT_CONNECT      = -2 -- Could not connect, check message.
    ,PARSE_ERROR_HEADERS    = -3 -- Could not parse response headers.
    ,CONNECT_TIMEOUT        = -6 -- Connect timed out.
    ,REQUEST_TIMEOUT        = -7 -- Request timed out.
    ,NO_HEADERS             = -8 -- Shouldnt happen.
    ,REQUIRES_BODY          = -9 -- Expected a HTTP body, but none set.
    ,INVALID_BODY           = -10 -- Request body is not a string.
    ,SOCKET_ERROR           = -11 -- Socket error, check message.
    ,SSL_ERROR              = -12 -- SSL error, check message.
    ,BUSY                   = -13 -- Operation in progress.
}
async.errors = errors

--- Fetch a URL. 
-- @param url (String) URL to fetch.
-- @param kwargs (table) Optional keyword arguments
-- ** Available options **
-- "method" = The HTTP method to use. Default is "GET"
-- "params" = Provide parameters as table.
-- "cookie" = The cookie to use.
-- "http_version" = Set HTTP version. Default is HTTP1.1
-- "use_gzip" = Use gzip compression. Default is true.
-- "allow_redirects" = Allow or disallow redirects. Default is true.
-- "max_redirects" = Maximum redirections allowed. Default is 4.
-- "on_headers" = Callback to be called when assembling request headers. Called
--  with headers as argument.-- Default to port 80 if not specified in URL.
-- "body" = Request HTTP body in plain form.
-- "request_timeout" = Total timeout in seconds (including connect) for 
-- request. Default is 60 seconds.
-- "connect_timeout" = Timeout in seconds for connect. Default is 20 secs.
-- "auth_username" = Basic Auth user name.
-- "auth_password" = Basic Auth password.
-- "user_agent" = User Agent string used in request headers. Default 
-- is "Turbo Client vx.x.x"
function async.HTTPClient:fetch(url, kwargs)
    if self.in_progress then
        self._throw_error(errors.BUSY, "HTTPClient is busy.")
        -- This client is busy with another request.
        -- Do not overwrite the already existing co ctx.
        return coctx.CoroutineContext:new(self.io_loop)
    end
    self.coctx = coctx.CoroutineContext:new(self.io_loop)
    self.in_progress = true
    if type(url) ~= "string" then
        self._throw_error(errors.INVALID_URL, "URL must be string.")
        return self.coctx
    end
    self.start_time = util.gettimeofday()
    self.headers = httputil.HTTPHeaders:new()
    if self.headers:parse_url(url) ~= 0 then
        self:_throw_error(errors.INVALID_URL, "Invalid URL provided.")
        return self.coctx
    end
    self.hostname = self.headers:get_url_field(httputil.UF.HOST)
    self.port = tonumber(self.headers:get_url_field(httputil.UF.PORT))
    self.path = self.headers:get_url_field(httputil.UF.PATH)
    self.query = self.headers:get_url_field(httputil.UF.QUERY)
    self.schema = self.headers:get_url_field(httputil.UF.SCHEMA)
    local sock, msg = socket.new_nonblock_socket(self.family, 
        socket.SOCK_STREAM, 
        0)
    if sock == -1 then 
        -- Could not create a new socket. Highly unlikely case.
        self:_throw_error(errors.SOCKET_ERROR, msg)
        return self.coctx
    end
    -- Reset states from previous fetch.
    self.redirects = 0
    self.response_headers = nil
    self.s_connecting = false 
    self.s_error = false 
    self.payload = nil
    self.error_str = ""
    self.error_code = 0
    self.start_time = util.gettimeofday()
    self.url = url
    self.kwargs = kwargs or {}
    -- Set sane defaults for kwargs if not present.
    self.redirect_max = self.kwargs.max_redirects or 4
    self.kwargs.method = self.kwargs.method or "GET"
    self.kwargs.user_agent = self.kwargs.user_agent or "Turbo Client v1.0.0"
    self.kwargs.connect_timeout = self.kwargs.connect_timeout or 30
    self.kwargs.request_timeout = self.kwargs.request_timeout or 60
    -- Check if a body is present for HTTP request methods that requires so.
    if not self.kwargs.body and not self.kwargs.params and 
        util.is_in(self.kwargs.method, {"POST", "PATCH", "PUT"}) then
        -- Request requires a body.
        self:_throw_error(errors.REQUIRES_BODY, 
            "Standard does not support this request method without a body.")
        return self.coctx
    end    
    if self.schema == "http" then
        -- Standard HTTP connect.
        if self.port == -1 then
            -- Default to port 80 if not specified in URL.
            self.port = 80
        end
        self.iostream = iostream.IOStream:new(
            sock, 
            self.io_loop, 
            self.max_buffer_size)
        local rc, msg = self.iostream:connect(self.hostname, 
            self.port, 
            self.family,
            self._handle_connect,
            self._handle_connect_fail,
            self)
        if rc ~= 0 then
            -- If connect fails without blocking the hostname is most probably 
            -- not resolvable.
            self:_throw_error(errors.COULD_NOT_CONNECT, msg)
            return self.coctx            
        end
    elseif (self.schema == "https") then
        -- HTTPS connect.
        -- Create context if not already done.
        if not self.ssl_options or not self.ssl_options._ssl_ctx then
            -- SSL options does not have to be set by the user to use SSL.
            -- It is a available optimizations if the user wants to avoid
            -- recreating new SSL contexts for every fetch.
            self.ssl_options = self.ssl_options or {}
            crypto.ssl_init()
            local rc, ctx_or_err = crypto.ssl_create_client_context(
                self.ssl_options.priv_key,
                self.ssl_options.cert_key,
                self.ssl_options.ca_path,
                self.ssl_options.verify_ca)
            if rc ~= 0 then
                self:_throw_error(errors.SSL_ERROR, 
                    string.format("Could not create SSL context. %s", 
                        ctx_or_err))
                return self.coctx            
            end
            -- Set SSL context to this class. This means that we only support 
            -- one SSL context per instance! The user must create more class 
            -- instances if he wishes to do so.
            self.ssl_options._ssl_ctx = ctx_or_err
            self.ssl_options._type = 1
        end
        if self.port == -1 then
            -- Default to port 443 if not specified in URL.
            self.port = 443
        end
        self.iostream = iostream.SSLIOStream:new(
            sock, 
            self.ssl_options, 
            self.io_loop, 
            self.max_buffer_size)
        local rc, msg = self.iostream:connect(
            self.hostname, 
            self.port, 
            self.family,
            self._handle_connect,
            self._handle_connect_fail,
            self)
        if rc ~= 0 then
            self:_throw_error(errors.COULD_NOT_CONNECT, msg)
            return self.coctx            
        end
    else
        -- Some other strange schema that not is HTTP or supported at all.
        self:_throw_error(errors.INVALID_SCHEMA, 
            "Invalid schema used in URL parameter.")
        return self.coctx
    end
    -- Add connect timeout.
    self.connect_timeout_ref = self.io_loop:add_timeout(
        self.kwargs.connect_timeout * 1000 + util.gettimeofday(), 
        self._handle_connect_timeout,
        self)

    -- Assuming the method is yielded the returned context is placed in the 
    -- IOLoop, awaiting further work.
    self.coctx:set_state(coctx.states.WAIT_COND)
    return self.coctx
end

function async.HTTPClient:_handle_connect_timeout()
    log.warning(string.format(
        "[async.lua] Connect timed out after %d secs. %s %s%s",
        self.kwargs.connect_timeout,
        self.kwargs.method,
        self.hostname,
        self.path))
    self.connect_timeout_ref = nil
    self:_throw_error(errors.CONNECT_TIMEOUT, string.format(
        "Connect timed out after %d secs", 
        self.kwargs.connect_timeout))
end

function async.HTTPClient:_handle_connect_fail(err, strerr)
    self:_throw_error(errors.COULD_NOT_CONNECT, strerr)
end

function async.HTTPClient:_handle_connect()
    self.s_connecting = false
    self.io_loop:remove_timeout(self.connect_timeout_ref)
    self.connect_timeout_ref = nil
    self.request_timeout_ref = self.io_loop:add_timeout(
        self.kwargs.request_timeout * 1000 + util.gettimeofday(), 
        self._handle_request_timeout,
        self)

    self.headers:add("Host", self.hostname)
    self.headers:add("User-Agent", self.kwargs.user_agent)
    -- No keep-alive support at this point.
    self.headers:add("Connection", "Close")
    self.headers:set_method(self.kwargs.method:upper())
    self.headers:set_version("HTTP/1.1")
    if type(self.kwargs.on_headers) == "function" then
        -- Call on header callback. Allow the user to modify the
        -- headers class instance on their own.
        self.kwargs.on_headers(self.headers)
    end
    if self.path == -1 then
        self.path = ""
    end
    if self.query ~= -1 then
        self.headers:set_uri(string.format("%s?%s", self.path, self.query))
    else
        self.headers:set_uri(self.path)
    end
    local write_buf = ""
    if (self.kwargs.body) then
        if (type(self.kwargs.body) == "string") then
            local len = self.kwargs.body:len()
            self.headers:add("Content-Length", len)
            write_buf = write_buf .. self.kwargs.body .. "\r\n\r\n"
        else
            self:_throw_error(errors.INVALID_BODY, 
                "Request body is not a string.")
            return
        end
    elseif (type(self.kwargs.params) == "table") then
        if self.kwargs.method == "POST" then
            self.headers:add("Content-Type", 
                "application/x-www-form-urlencoded")
            local post_data = deque:new()
            local n = 0
            for k, v in pairs(self.kwargs.params) do
                if (n ~= 0) then
                    post_data:append("&")
                end
                n  = n + 1
                post_data:append(
                    string.format("%s=%s", 
                        escape.escape(k), 
                        escape.escape(v)))
            end
            write_buf = write_buf .. post_data
        elseif (self.kwargs.method == "GET" and self.query == -1) then
            local get_url_params = deque:new()
            local n = 0
            get_url_params:append("?")
            for k, v in pairs(self.kwargs.params) do
                if (n ~= 0) then
                    get_url_params:append("&")
                end
                n  = n + 1
                get_url_params:append(
                    string.format("%s=%s", 
                        escape.escape(k), 
                        escape.escape(v)))
            end
            self.headers:set_uri(self.headers:get_uri() .. get_url_params)
        end
    end
    local stringifed_headers = self.headers:stringify_as_request()
    write_buf = stringifed_headers .. write_buf
    self.iostream:write(write_buf, self._headers_written_cb, self)
end

function async.HTTPClient:_headers_written_cb()
    self.iostream:read_until_pattern("\r?\n\r?\n", self._handle_headers, self)
end

function async.HTTPClient:_handle_request_timeout()
    self.request_timeout_ref = nil
    log.warning(string.format(
        "[async.lua] Request to %s timed out.", self.hostname))
    self:_throw_error(errors.REQUEST_TIMEOUT, 
        string.format("Request timed out after %d secs", 
            self.kwargs.connect_timeout))
end

function async.HTTPClient:_handle_1xx_code(code)
    -- Continue reading.
    self.iostream:read_until_pattern(
        "\r?\n\r?\n", 
        self._handle_headers,
        self)
end

function async.HTTPClient:_handle_headers(data)
    if not data then
        return self:_throw_error(errors.NO_HEADERS, 
            "No data recieved after connect. Expected HTTP headers.")
    end 
    self.response_headers = httputil.HTTPHeaders:new()
    local rc, httperrno, errnoname, errnodesc = 
        self.response_headers:parse_response_header(data)
    if rc == -1 then
        return self:_throw_error(errors.PARSE_ERROR_HEADERS, 
            "Could not parse HTTP headers: " .. errnodesc)
    end
    local code = self.response_headers:get_status_code()
    if (100 <= code and code < 200) then
        self:_handle_1xx_code(code)
        return
    end
    if code == 301 and self.redirect < self.redirect_max then
        local redirect_loc = self.response_headers:get("Location", true)
        if redirect_loc then
            -- FIXME: handle redirect here.
            self.redirect = self.redirect + 1
        end
    end
    local content_length = self.response_headers:get("Content-Length", true)
    if not content_length or content_length == 0  then
        -- No content length. This is probably a HEAD request or a error?
        self:_finalize_request()
        return
    end
    self.iostream:read_bytes(tonumber(content_length),
        self._handle_body,
        self)
end

function async.HTTPClient:_handle_body(data)
    self.payload = data
    self:_finalize_request()
end

function async.HTTPClient:_throw_error(code, msg)
    -- Add as callback to make sure that errors are always returned after the
    -- CoroutineContext has ended up in the IOLoop.
    self.s_error = true
    self.error_code = code
    self.error_str = msg
    self.io_loop:add_callback(self._finalize_request, self)
end

function async.HTTPClient:_finalize_request()
    if not self.s_error then 
        self.finish_time = util.gettimeofday()
        local status_code = self.response_headers:get_status_code()
        if (status_code == 200) then
            log.success(string.format("[async.lua] %s %s%s => %d %s %dms",
              self.kwargs.method,
              self.hostname,
              self.path,
              status_code,
              http_response_codes[status_code],
              self.finish_time - self.start_time))
        else
            log.warning(string.format("[async.lua] %s %s%s => %d %s %dms",
              self.kwargs.method,
              self.hostname,
              self.path,
              status_code,
              http_response_codes[status_code],
              self.finish_time - self.start_time))
        end
    end
    if (self.request_timeout_ref) then
        self.io_loop:remove_timeout(self.request_timeout_ref)
    end
    if (self.connect_timeout_ref) then
        self.io_loop:remove_timeout(self.connect_timeout_ref)
    end
    if self.iostream then 
        self.iostream:close()
        self.iostream = nil
    end
    local res = async.HTTPResponse:new()
    if self.s_error == true then
        log.error(string.format("[async.lua] Error code %d. %s", 
            self.error_code, 
            self.error_str))
        res.error = {
            code = self.error_code,
            message = self.error_str
        }
    else
        res.error = nil
        res.code = self.response_headers:get_status_code()
        res.reason = http_response_codes[res.code]
        res.body = self.payload
        res.request_time = self.finish_time - self.start_time
        res.headers = self.response_headers
    end
    self.coctx:set_state(coctx.states.DEAD)
    self.coctx:set_arguments({res})
    self.coctx:finalize_context()
end

async.HTTPResponse = class("HTTPResponse")

function async.HTTPResponse:initialize()
    self.request = nil
    self.code = code
    self.headers = headers
    self.body = body
    self.error = err
    self.request_time = nil    
end


return async
