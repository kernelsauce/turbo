--[["Permission is hereby granted, free of charge, to any person obtaining a copy of
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
    SOFTWARE." ]]
  
local nonsence = require "nonsence"
require "middleclass"
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
 
describe("nonsence httputil module", function()
  describe("parse request header", function()
           
    it("should parse valid headers correctly", function()
        local headers = nonsence.httputil.HTTPHeaders:new(raw_headers)
        assert.truthy(instanceOf(nonsence.httputil.HTTPHeaders, headers))
    end)

    it("should throw on bad headers", function()        
        assert.has_error(function() nonsence.httputil.HTTPHeaders:new(badheaders) end)
    end)    
    
    it("should parse header name/value fields correctly", function()
        local headers = nonsence.httputil.HTTPHeaders:new(raw_headers)
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
        assert.equal(headers:get_url_field(nonsence.httputil.UF.PATH), "/test/test.gif")
        assert.equal(headers:get_version(), "HTTP/1.1")
        assert.equal(headers:get_argument("param1")[1], "something")
        assert.equal(headers:get_argument("param2")[1], "somethingelse")
        assert.equal(headers:get_argument("param2")[2], "somethingelseelse")
        assert.equal(type(headers:get_arguments()), "table")
    end)
    
    it("should assemble headers correctly", function()
	local headers = nonsence.httputil.HTTPHeaders:new()
        assert.truthy(instanceOf(nonsence.httputil.HTTPHeaders, headers))
	headers:set_status_code(304)
	headers:set_version("HTTP/1.1")
        headers:add("Date", "Wed, 08 May 2013 15:00:22 GMT")
	headers:add("Server", "Nonsence/1.0")
	headers:add("Accept-Ranges", "bytes")
	headers:add("Connection", "keep-alive")
	headers:add("Age", "0")
        local expected = "HTTP/1.1 304 Not Modified\r\nConnection: keep-alive\r\nDate: Wed, 08 May 2013 15:00:22 GMT\r\nAge: 0\r\nAccept-Ranges: bytes\r\nServer: Nonsence/1.0\r\n\r\n"
        assert.equal(headers:__tostring(), expected)
	assert(headers:__tostring():len() == 142, headers:__tostring():len())
    end)
    
    it("should allow settings and getting of notable values", function()
        local h = nonsence.httputil.HTTPHeaders:new()
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
        local h = nonsence.httputil.HTTPHeaders:new()
        assert.has_error(function() h:set_status_code("FAIL") end)
        assert.has_error(function() h:set_method(123) end)
        assert.has_error(function() h:set_uri() end)
        assert.has_error(function() h:set_content_length("nisse") end)
        assert.has_error(function() h:set_version({"HI"}) end)
    end)
    
    it("should parse formdata", function()
        local data = "?username=user782400&mmm=ddd"
        local tbl = nonsence.httputil.parse_post_arguments(data)
        assert.equal(type(tbl), "table")
        assert.equal(tbl.username, "user782400")
        assert.equal(tbl.mmm, "ddd")
    end)
    
  end)
end)