--[[
	
	Nonsence Asynchronous event based Lua Web server.
	Author: John Abrahamsen < JhnAbrhmsn@gmail.com >
	
	This module "IOLoop" is a part of the Nonsence Web server.
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

package.path = package.path.. ";../nonsence/?.lua"  

-------------------------------------------------------------------------
--
-- Load modules
--
local log = assert(require('log'), 
	[[Missing log module]])
local nonsence = assert(require('nonsence'), 
	[[Missing httputil module]])
-------------------------------------------------------------------------

--
-- Request headers parsing.
--
local do_tests_n_times = 30000
for do_tests = 1, do_tests_n_times, 1 do
	local raw_headers = 
		"GET /test/test.gif?param1=something&param2=somethingelse HTTP/1.1\r\n"..
		"Host: somehost.no\r\n"..
		"Connection: keep-alive\r\n"..
		"Cache-Control: max-age=0\r\n"..
		"User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.56 Safari/535.11\r\n"..
		"Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\n"..
		"Accept-Encoding: gzip,deflate,sdch\r\n"..
		"Accept-Language: en-US,en;q=0.8\r\n"..
		"Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3\r\n"

	local headers = nonsence.httputil.HTTPHeaders:new(raw_headers)

	assert(type(headers._header_table) == "table", "Test failed: _header_table not a table!")
	assert(headers:get("Host") == "somehost.no", "Test failed: Error in field:Host")
	assert(headers:get("Connection") == "keep-alive", "Test failed: Error in field:Connection")
	assert(headers:get("Cache-Control") == "max-age=0", "Test failed: Error in field:Cache-Control")
	assert(headers:get("User-Agent") == 
		"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.56 Safari/535.11", 
		"Test failed: Error in field:User-Agent")
	assert(headers:get("Accept") == "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", 
		"Test failed: Error in field:Accept")
	assert(headers:get("Accept-Encoding") == "gzip,deflate,sdch", "Test failed: Error in field:Accept-Encoding")
	assert(headers:get("Accept-Language") == "en-US,en;q=0.8", "Test failed: Error in field:Accept-Language")
	assert(headers:get("Accept-Charset") == "ISO-8859-1,utf-8;q=0.7,*;q=0.3", "Test failed: Error in field:Accept-Charset")
	assert(headers.method == "GET", "Test failed: method field invalid")
	assert(headers.uri == "/test/test.gif?param1=something&param2=somethingelse", "Test failed: uri field invalid")
	assert(headers.url == "/test/test.gif", "Test failed: url field invalid")
	assert(headers.version == "HTTP/1.1", "Test failed: version field invalid")
	assert(headers:get_argument("param1") == "something", "Test failed: could not get argument param1")
	assert(headers:get_argument("param2") == "somethingelse", "Test failed: could not get argument param2")
	assert(type(headers:get_arguments()) == 'table', "Test failed: No arguments table passed from get_arguments() method")
end
print("\r\nHTTPHeaders:init(raw_headers) parsed " .. do_tests_n_times .. " headers without errors.")

--
-- Response headers assembling test
--
local do_tests_n_times = 30000
for do_tests = 1, do_tests_n_times, 1 do
	local headers = nonsence.httputil.HTTPHeaders:new()
	headers:set_status_code(304)
	headers:set_version("HTTP/1.1")
	headers:add("Server", "Nonsence/1.0")
	headers:add("Accept-Ranges", "bytes")
	headers:add("Connection", "keep-alive")
	headers:add("Age", "0")
	assert(headers:__tostring():len() == 140)
end
print("\r\nHTTPHeaders:__tostring() assembled " .. do_tests_n_times .. " headers without errors.")

print("\r\nAll tests passed")