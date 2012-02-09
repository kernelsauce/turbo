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
  
-------------------------------------------------------------------------
--
-- Load modules
--
local log = assert(require('nonsence_log'), 
	[[Missing nonsence_log module]])
local nixio = assert(require('nixio'),
	[[Missing required module: Nixio (https://github.com/Neopallium/nixio)]])
local iostream = assert(require('nonsence_iostream'), 
	[[Missing nonsence_iostream module]])
local ioloop = assert(require('nonsence_ioloop'), 
	[[Missing nonsence_ioloop module]])
-------------------------------------------------------------------------

log.dump(ioloop)
local socket = nixio.socket('inet', 'stream')
local loop = ioloop.instance()
local stream = iostream.IOStream:new(socket)

function on_headers()
	print('closing socket....')
	stream:close()
end

function send_request()
	stream:write("GET / HTTP/1.0\r\nHost: friendfeed.com\r\n\r\n")
	stream:read_until("\r\n\r\n", on_headers)
end

stream:connect("friendfeed.com", 80, send_request)

loop:start()
