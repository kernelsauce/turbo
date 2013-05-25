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

package.path = package.path.. ";../turbo/?.lua"  

-------------------------------------------------------------------------
--
-- Load modules
--
local log = assert(require('log'), 
	[[Missing log module]])
local turbo = assert(require('turbo'), 
	[[Missing httputil module]])
-------------------------------------------------------------------------
local ioloop_instance = turbo.ioloop.instance()

function handle_request(request)	
	local message = "You requested: " .. request._request.headers.uri
	
	local headers = turbo.httputil.HTTPHeaders:new()

	headers:set_status_code(200)
	headers:set_version("HTTP/1.1")
	headers:add("Cache-Control", "Cache-Control:private, max-age=0, must-revalidate")
	headers:add("Connection", "keep-alive")
	headers:add("Content-Type", "text/html; charset=utf-8")
	headers:add("Server", "Turbo v0.1")
	headers:add("Content-Length", message:len() + 2)
	
	request:write(headers:__tostring())
	request:write(message)
	request:finish()
end

http_server = turbo.httpserver.HTTPServer:new(handle_request)
http_server:listen(8888)
ioloop_instance:start()
