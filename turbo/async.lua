--[[ Turbo Async module

Copyright 2013 John Abrahamsen

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.     ]]

local iostream =            require "turbo.iostream"
local ioloop =              require "turbo.ioloop"
local httputil =            require "turbo.httputil"
local util =                require "turbo.util"
local socket =              require "turbo.socket_ffi"
local log =                 require "turbo.log"
local http_response_codes = require "turbo.http_response_codes"
local coctx =               require "turbo.coctx"
require "turbo.3rdparty.middleclass"

local fast_assert = util.fast_assert
local AF_INET = socket.AF_INET


local async = {} -- async namespace

async.HTTPClient = class("HTTPClient")

function async.HTTPClient:initialize(family, io_loop, max_buffer_size, read_chunk_size)
    self.io_loop = io_loop or ioloop.instance()
    self.max_buffer_size = max_buffer_size
    self.read_chunk_size = read_chunk_size    
end

function async.HTTPClient:_handle_connect()
    self.connecting = false
    self.headers:add("Host", self.hostname)
    self.headers:add("User-Agent", "Turbo v1.0")
    self.headers:add("Connection", "close")
    self.headers:add("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
    self.headers:add("Accept-Language", "en-US,en;q=0.8")
    self.headers:add("Cache-Control", "max-age=0")
    self.headers:set_method(self.method)
    self.headers:set_version("HTTP/1.1")
    if (self.query ~= -1) then
        self.headers:set_uri(string.format("%s?%s", self.path, self.query))
    else
        self.headers:set_uri(self.path)
    end
    
    local stringifed_headers = self.headers:stringify_as_request()
    self.iostream:write(stringifed_headers, function()
        self.iostream:read_until_pattern("\r?\n\r?\n", function(data) self:_handle_headers(data) end)
    end)
end

function async.HTTPClient:_handle_headers(data)
    if (not data) then
        self:_handle_error()
    end
        
    self.response_headers = httputil.HTTPHeaders:new()
    local rc, httperrno, errnoname, errnodesc = self.response_headers:parse_response_header(data)
    if (rc == -1) then
        error(string.format("Could not parse header. %s, %s", errnoname, errnodesc))
    end
    self.header_parsed = true
    
    local content_length = self.response_headers:get("Content-Length", true)
    self.iostream:read_bytes(tonumber(content_length), function(data)
        self:_handle_body(data)
    end)
end

function async.HTTPClient:_handle_body(data)
    self.finish_time = util.gettimeofday()
    local status_code = self.response_headers:get_status_code()
    log.success(string.format("[async.lua] %s %s%s => %d %s %dms", self.method, self.hostname, self.path, status_code, http_response_codes[status_code], self.finish_time - self.start_time))
    self.iostream:close()
    self.coctx:set_arguments({self.response_headers, data})
    self.coctx:finalize_context()
end

function async.HTTPClient:_handle_error(err)
    if (self.err_handler) then
        if (self.connecting) then
            
        elseif (self.header_parsed) then
            
        end
    end
end

function async.HTTPClient:fetch(url, kwargs)
    fast_assert(type(url) == "string", "URL must be string.")
    self.headers = httputil.HTTPHeaders:new()
    local rc = self.headers:parse_url(url)
    fast_assert(rc == 0, "Invalid URL provided to fetch().")
    
    local sock, msg = socket.new_nonblock_socket(socket.AF_INET, socket.SOCK_STREAM, 0)
    fast_assert(sock ~= -1, msg)
    self.iostream = iostream.IOStream:new(sock, self.io_loop, self.max_buffer_size, self.read_chunk_size)
    self.response_headers = nil
    self.connecting = false
    self.headers_parsed = false

    self.start_time = util.gettimeofday()
    self.url = url
    self.method = kwargs.method or "GET"

    self.hostname = self.headers:get_url_field(httputil.UF.HOST)
    self.port = self.headers:get_url_field(httputil.UF.PORT)
    self.path = self.headers:get_url_field(httputil.UF.PATH)
    self.query = self.headers:get_url_field(httputil.UF.QUERY)
    if (self.port == -1) then
        self.port = 80
    end
    if (self.headers:get_url_field(httputil.UF.SCHEMA) == "http") then
        self.connecting = true
        self.iostream:connect(self.hostname, self.port, AF_INET,
                              function() self:_handle_connect() end,
                              function(err) self:_handle_error(err) end)
    else
        error("Wrong schema used in fetch() url parameter.")
    end
    self.coctx = coctx.CoroutineContext:new(self.io_loop)
    return self.coctx
end

return async