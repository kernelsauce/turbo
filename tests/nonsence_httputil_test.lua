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

local raw_headers = 
"GET /shaft/djisjdio/sdfko/lol.gif HTTP/1.1\r\n"..
"Host: www.vg.no\r\n"..
"Connection: keep-alive\r\n"..
"Cache-Control: max-age=0\r\n"..
"User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.56 Safari/535.11\r\n"..
"Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\n"..
"Accept-Encoding: gzip,deflate,sdch\r\n"..
"Accept-Language: en-US,en;q=0.8\r\n"..
"Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3\r\n"

local headers = nonsence.httputil.HTTPHeaders:new(raw_headers)

dump(headers._header_table)
dump(headers.method)
dump(headers.uri)
dump(headers.url)
dump(headers.version)