--- Turbo.lua HTTP Server module
-- A non-blocking HTTPS Server based on the TCPServer class.
-- Supports HTTP/1.0 and HTTP/1.1.
-- Includes SSL support. 
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
 
local tcpserver =   require "turbo.tcpserver"
local httputil =    require "turbo.httputil"
local ioloop =      require "turbo.ioloop"
local iostream =    require "turbo.iostream"
local util =        require "turbo.util"
local log =         require "turbo.log"
require('turbo.3rdparty.middleclass')

local httpserver = {} -- httpserver namespace

-- HTTPServer based on TCPServer, IOStream and IOLoop classes.
-- This class is used by the Application class to serve its RequestHandlers.
-- The server itself is only responsible for handling incoming requests, no
-- response to the request is produced, that is the purpose of the request
-- callback given as argument on initialization. The callback recieves the
-- HTTPRequest class instance produced for the incoming request and can 
-- by data provided in that instance decide on how it want to respond to 
-- the client. The callback must produce a valid HTTP response header and
-- optionally a response body and use the HTTPRequest:write method.
--
-- The server supports SSL, HTTP/1.1 Keep-Alive and optionally HTTP/1.0
-- Keep-Alive if the header field is specified.
--
-- Example usage of HTTPServer:
--
-- local httpserver = require('turbo.httpserver')
-- local ioloop = require('turbo.ioloop')
-- local ioloop_instance = ioloop.instance()
--
-- function handle_request(request)
--     local message = "You requested: " .. request._request.path
--     request:write("HTTP/1.1 200 OK\r\nContent-Length:" .. message:len() ..
--          "\r\n\r\n")
--     request:write(message)
--     request:finish()
-- end
--
-- http_server = httpserver.HTTPServer:new(handle_request)
-- http_server:listen(8888)
-- ioloop_instance:start()
httpserver.HTTPServer = class('HTTPServer', tcpserver.TCPServer)

--- Create a new HTTPServer class instance.
-- @param request_callback (Function) Callback when requests are recieved by 
-- the server.
-- @param no_keep_alive (Boolean) If clients request to use Keep-Alive is to be
-- ignored.
-- @param io_loop (IOLoop instance) The IOLoop instance you want to use.
-- @param xheaders (Boolean) Care about X-* header fields or not.
-- @param kwargs (Table) Key word arguments.
-- Key word arguments supported:
-- ** SSL Options **
-- To enable SSL remember to set the _G.TURBO_SSL global.
-- "key_file" = SSL key file if a SSL enabled server is wanted.
-- "cert_file" = Certificate file. key_file must also be set.
function httpserver.HTTPServer:initialize(request_callback, no_keep_alive, 
    io_loop, xheaders, kwargs)
    self.request_callback = request_callback
    self.no_keep_alive = no_keep_alive
    self.xheaders = xheaders
    tcpserver.TCPServer:initialize(io_loop, kwargs and kwargs.ssl_options)
end

--- Internal handle_stream method to be called by super class TCPServer on new 
-- connection.
-- @param stream (IOStream instance) Stream for the newly connected client.
-- @param address (String) IP address of newly connected client.
function httpserver.HTTPServer:handle_stream(stream, address)
    httpserver.HTTPConnection:new(stream, address, self.request_callback,
        self.no_keep_alive, self.xheaders)
end


--- HTTPConnection class.
-- Represents a live connection to the server. Basically a helper class to 
-- HTTPServer. It uses the IOStream class's callbacks to handle the different
-- sections of a HTTP request.
httpserver.HTTPConnection = class('HTTPConnection')

function httpserver.HTTPConnection:initialize(stream, address, 
    request_callback, no_keep_alive, xheaders)
    self.stream = stream
    self.address = address
    self.request_callback = request_callback
    self.no_keep_alive = no_keep_alive or false
    self.xheaders = xheaders or false
    self._request_finished = false
    self.arguments = {}
    self._header_callback = self._on_headers
    self._write_callback = nil
    self._request = nil
    self.stream:read_until("\r\n\r\n", self._header_callback, self)
end

--- Writes a chunk of output to the stream.
-- @param chunk (String) Data chunk to write to underlying IOStream.
-- @param callback (Function) Optional callback called when socket is flushed.
function httpserver.HTTPConnection:write(chunk, callback)
    local callback = callback
    assert(self._request, "Request closed")
    if not self.stream:closed() then
        self._write_callback = callback
        self.stream:write(chunk, self._on_write_complete, self)
    end
end

--- Finishes the request.
function httpserver.HTTPConnection:finish()    
    assert(self._request, "Request closed")
    self._request_finished = true
    if not self.stream:writing() then
        self:_finish_request()
    end
end

local function _on_headers_error_handler(err)
    log.error(string.format("[httpserver.lua] %s", err))
end

--- Handles incoming headers. The HTTPHeaders class is used to parse
-- request headers.
function httpserver.HTTPConnection:_on_headers(data)
    local headers
    local status, headers = xpcall(httputil.HTTPHeaders, 
        _on_headers_error_handler, data)

    if (status == false) then
        -- Invalid headers. Close stream.
        -- Log line is printed by error handler describing the reason.       
        self.stream:close()
        return
    end
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
        self.stream:read_bytes(content_length, self._on_request_body, self)
        return
    end
    self:request_callback(self._request)
end

--- Handles incoming request body.
function httpserver.HTTPConnection:_on_request_body(data)
    self._request.body = data
    local content_type = self._request.headers:get("Content-Type")

    if content_type then
        if content_type:find("x-www-form-urlencoded", 1, true) then
            local arguments = httputil.parse_post_arguments(self._request.body)
            self._request.arguments = arguments
        elseif content_type:find("multipart/form-data", 1, true) then
            self.arguments = httputil.parse_multipart_data(self._request.body) 
                or {}
        end
    end
    self:request_callback(self._request)
end

--- Finish request. 
function httpserver.HTTPConnection:_finish_request()
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
    self._request_finished = false
    if disconnect then
        self.stream:close()
        return
    end
    if not self.stream:closed() then
        self.stream:read_until("\r\n\r\n", self._header_callback, self)
    else
        log.debug("[httpserver.lua] Client hang up. End Keep-Alive session.")
        self = nil
        return
    end
end

--- Callback for on complete event.
function httpserver.HTTPConnection:_on_write_complete()
    if self._write_callback then
        local callback = self._write_callback
        self._write_callback = nil
        callback()
    end
    if self._request_finished and not self.stream:writing() then
        self:_finish_request()
    end
end

--- HTTPRequest class.
-- Represents a HTTP request to the server.
-- HTTP headers are parsed magically if headers are supplied with kwargs table.
httpserver.HTTPRequest = class('HTTPRequest')

--- Create a new HTTPRequest class instance.
-- @param method (String) HTTP request method, e.g "POST".
-- @param uri (String) The URI requested.
-- @param args (Table) Table or optional arguments:
-- Arguments available:
--         headers,
--         body,
--         remote_ip,
--         protocol,
--         host,
--         files, 
--         connection
function httpserver.HTTPRequest:initialize(method, uri, args)
    local headers, body, remote_ip, protocol, host, files, version, connection 
        = nil, nil, nil, nil, nil, nil, "HTTP/1.0", nil

    -- Find arguments sent.
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
            instanceOf(iostream.SSLIOStream, connection.stream) then
            self.protocol = "https"
        else
            self.protocol = "http"
        end
    end
    self.host = host or self.headers:get("Host") or "127.0.0.1"
    self.files = files or {}
    self.connection = connection 
    self._start_time = util.gettimeofday()
    self._finish_time = nil
    self.path = self.headers.url
    self.arguments = self.headers:get_arguments()
end


---  Returns true if requester supports HTTP 1.1.
-- @return (Boolean)
function httpserver.HTTPRequest:supports_http_1_1()
    return self.version == "HTTP/1.1"
end

--- Writes a chunk of output to the stream.
-- @param chunk (String) Data chunk to write to underlying IOStream.
-- @param callback (Function) Optional callback called when socket is flushed.
function httpserver.HTTPRequest:write(chunk, callback, arg)
    assert(type(chunk) == "string")
    self.connection:write(chunk, callback, arg)
end

--- Finish the request. Close connection.
function httpserver.HTTPRequest:finish()
    self.connection:finish()
    self._finish_time = util.gettimeofday()
end

--- Return the full URL that the user requested.
function httpserver.HTTPRequest:full_url()
    return self.protocol .. "://" .. self.host .. self.uri
end

--- Return the time used to handle the request or the 
-- time up to now if request not finished.
-- @return (Number) Ms the request took to finish, or up until now if not yet
-- completed.
function httpserver.HTTPRequest:request_time()
    if not self._finish_time then
        return util.gettimeofday() - self._start_time
    else
        return self._finish_time - self._start_time
    end
end

function httpserver.HTTPRequest:_valid_ip(ip)
    --FIXME: This IP validation is broken!
    local ip = ip or ''
    return ip:find("[%d+%.]+") or nil
end

return httpserver
