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
local nixio = assert(require('nixio'),
	[[Missing required module: Nixio (https://github.com/Neopallium/nixio)]])
local iostream = assert(require('iostream'), 
	[[Missing iostream module]])
local ioloop = assert(require('ioloop'), 
	[[Missing ioloop module]])
-------------------------------------------------------------------------

local socket = nixio.socket('inet', 'stream')
local loop = ioloop.instance()
local stream = iostream.IOStream:new(socket)

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

function on_body(data)
	print('body: \r\n\r\n' .. data)

	stream:close()
	loop:close()
end

function on_headers(data)
	print('headers: ' .. data .. '\r\n\r\n')
	local headers = parse_headers(data)
	local length = tonumber(headers.extras['Content-Length'])
	log.warning('Parsed headers, now read: ' .. length)
	stream:read_bytes(length, on_body)
end

function send_request()
	stream:write("GET / HTTP/1.0\r\nHost: dagbladet.no\r\n\r\n")
	stream:read_until("\r\n\r\n", on_headers)
end

stream:connect("dagbladet.no", 80, send_request)

loop:start()
