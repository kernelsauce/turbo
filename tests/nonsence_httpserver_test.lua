--[[
	
	http://www.opensource.org/licenses/mit-license.php

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
local ioloop_instance = nonsence.ioloop.instance()

function handle_request(request)
	message = "You requested: " .. request._request.headers.uri
	request:write("HTTP/1.1 200 OK\r\nContent-Length:" .. message:len() .."\r\n\r\n")
	request:write(message)
	request:finish()

end

http_server = nonsence.httpserver.HTTPServer:new(handle_request)
http_server:listen(8888)
ioloop_instance:start()
