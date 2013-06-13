--[[ Turbo Unit test

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
  
local turbo = require "turbo"
require "turbo.3rdparty.middleclass"
local raw_headers = 
"GET /test/test.gif?param1=something&param2=somethingelse&param2=somethingelseelse HTTP/1.1\r\n"..
"Host: somehost.no\r\n"..
"Connection: keep-alive\r\n"..
"Cache-Control: max-age=0\r\n"..
"User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.56 Safari/535.11\r\n"..
"Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\n"..
"Accept-Encoding: gzip,deflate,sdch\r\n"..
"Accept-Language: en-US,en;q=0.8\r\n"..
"Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3\r\n"

local badheaders = 
"BAD! /test/test.gif?param1=something&param2=somethingelse&param2=somethingelseelse HTTP/1.1\r\n"..
"Host: somehost.no\r\n"..
"Connection: keep-alive\r\n"..
"Cache-Control: max-age=0\r\n"..
"User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.56 Safari/535.11\r\n"..
"Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\n"..
"Accept-Encoding: gzip,deflate,sdch\r\n"..
"Accept-Language: en-US,en;q=0.8\r\n"..
"Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3\r\n"
 
describe("turbo httputil module", function()
  describe("parse request header", function()
           
    it("should parse valid headers correctly", function()
        local headers = turbo.httputil.HTTPHeaders:new(raw_headers)
        assert.truthy(instanceOf(turbo.httputil.HTTPHeaders, headers))
    end)

    it("should throw on bad headers", function()        
        assert.has_error(function() turbo.httputil.HTTPHeaders:new(badheaders) end)
    end)    
    
    it("should parse header name/value fields correctly", function()
        local headers = turbo.httputil.HTTPHeaders:new(raw_headers)
        assert.equal(headers:get("Host"), "somehost.no")
        assert.equal(headers:get("Connection"), "keep-alive")
        assert.equal(headers:get("Cache-Control"), "max-age=0")
        assert.equal(headers:get("User-Agent"), "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.56 Safari/535.11")
        assert.equal(headers:get("Accept"), "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
        assert.equal(headers:get("Accept-Encoding"), "gzip,deflate,sdch")
        assert.equal(headers:get("Accept-Language"), "en-US,en;q=0.8")
        assert.equal(headers:get("Accept-Charset"), "ISO-8859-1,utf-8;q=0.7,*;q=0.3")
        assert.equal(headers.method, "GET")
        assert.equal(headers.uri, "/test/test.gif?param1=something&param2=somethingelse&param2=somethingelseelse")
        assert.equal(headers:get_url_field(turbo.httputil.UF.PATH), "/test/test.gif")
        assert.equal(headers:get_version(), "HTTP/1.1")
        assert.equal(headers:get_argument("param1")[1], "something")
        assert.equal(headers:get_argument("param2")[1], "somethingelse")
        assert.equal(headers:get_argument("param2")[2], "somethingelseelse")
        assert.equal(type(headers:get_arguments()), "table")
    end)
    
    it("should assemble headers correctly", function()
	local headers = turbo.httputil.HTTPHeaders:new()
        assert.truthy(instanceOf(turbo.httputil.HTTPHeaders, headers))
	headers:set_status_code(304)
	headers:set_version("HTTP/1.1")
        headers:add("Date", "Wed, 08 May 2013 15:00:22 GMT")
	headers:add("Server", "Turbo/1.0")
	headers:add("Accept-Ranges", "bytes")
	headers:add("Connection", "keep-alive")
	headers:add("Age", "0")
        local expected = "HTTP/1.1 304 Not Modified\r\nConnection: keep-alive\r\nDate: Wed, 08 May 2013 15:00:22 GMT\r\nAge: 0\r\nAccept-Ranges: bytes\r\nServer: Turbo/1.0\r\n\r\n"
        assert.equal(headers:__tostring(), expected)
	assert(headers:__tostring():len() == 139, headers:__tostring():len())
    end)
    
    it("should allow settings and getting of notable values", function()
        local h = turbo.httputil.HTTPHeaders:new()
        h:set_status_code(200)
        assert.equal(h:get_status_code(), 200)
        h:set_method("GET")
        assert.equal(h:get_method(), "GET")
        h:set_content_length(1233)
        assert.equal(h:get_content_length(), 1233)
        h:set_uri("/someplace/here")
        assert.equal(h:get_uri(), "/someplace/here")
        h:set_version("HTTP/1.1")
        assert.equal(h:get_version(), "HTTP/1.1")
        h:add("My-Field", "Some value")
        assert.has_error(function() h:add("My-Field", "Someimportdata") end)
        assert.has_no.errors(function() h:set("My-Field", "Someimportdata") end)
        assert.equal(h:get("My-Field"), "Someimportdata")
        h:remove("My-Field")
        assert.equal(h:get("My-Field"), nil)
    end)
    
    it("should fail on setting of bad values", function()
        local h = turbo.httputil.HTTPHeaders:new()
        assert.has_error(function() h:set_status_code("FAIL") end)
        assert.has_error(function() h:set_method(123) end)
        assert.has_error(function() h:set_uri() end)
        assert.has_error(function() h:set_content_length("nisse") end)
        assert.has_error(function() h:set_version({"HI"}) end)
    end)
    
    it("should parse formdata", function()
        local data = "?username=user782400&mmm=ddd"
        local tbl = turbo.httputil.parse_post_arguments(data)
        assert.equal(type(tbl), "table")
        assert.equal(tbl.username, "user782400")
        assert.equal(tbl.mmm, "ddd")
    end)
    
  end)
end)