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

--[[
	
	Tests for the TCPServer class.
	
  ]]

package.path = package.path.. ";../turbo/?.lua"
  
-------------------------------------------------------------------------
--
-- Load modules
--
local ioloop = assert(require('ioloop'), 
	[[Missing ioloop module]])
local tcpserver = assert(require('tcpserver'), 
	[[Missing tcpserver module]])
local log = assert(require('log'), 
	[[Missing log module]])
-------------------------------------------------------------------------

local io_loop = ioloop.instance()
local server = tcpserver.TCPServer:new()
local parse_headers = function(raw_headers)
	local HTTPHeader = raw_headers
	if HTTPHeader then
		-- Fetch HTTP Method.
		local method, uri = HTTPHeader:match("([%a*%-*]+)%s+(.-)%s")
		-- Fetch all header values by key and value
		local request_header_table = {}	
		for key, value  in HTTPHeader:gmatch("([%a*%-*]+):%s?(.-)[\r?\n]+") do
			request_header_table[key] = value
		end
	return { method = method, uri = uri, extras = request_header_table }
	end
end

function server:handle_stream(stream, address)
	function close()
		if #io_loop:list_callbacks() > 20 then
			print(#io_loop:list_callbacks())
		end
		stream:close()
	end	
	function headers(data)
		local requestheaders = parse_headers(data)
		stream:write("HTTP/1.1 200 OK\r" .. "Content-Type: text/html; charset=UTF-8\r" .. "Content-Length: 16\r\n\r\n" .. "TCPServer works!", close)
	end
	stream:read_until("\r\n\r\n", headers)
end

server:listen(8888)
io_loop:start()
