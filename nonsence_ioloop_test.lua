--[[
	
	Nonsence Asynchronous event based Lua Web server.
	Author: John Abrahamse < JhnAbrhmsn@gmail.com >
	
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

--[[
	
	Tests for the IOLoop class.
	
  ]]

-------------------------------------------------------------------------
--
-- Load modules
--
assert(require('nonsence_ioloop'), 
	[[Missing nonsence_ioloop module]])
local log = assert(require('nonsence_log'), 
	[[Missing nonsence_log module]])
local nixio = assert(require('nixio'),
	[[Missing required module: Nixio (https://github.com/Neopallium/nixio)]])
-------------------------------------------------------------------------

local testloop = IOLoop:new()

local host = '*'
local sock = nixio.socket('inet', 'stream')
local fd = sock:fileno()
sock:setblocking(false)
assert(sock:setsockopt('socket', 'reuseaddr', 1))
if host == '*' then host = nil end
sock:bind(host, 8080)
assert(sock:listen(1024))

local dump = log.dump

--
-- Callback/handler to run when READ event is fired on 
-- file descriptor
--
function some_handler_that_accepts()
	-- Accept socket connection.
	local new_connection = sock:accept()
	local fd = new_connection:fileno()
	--
	-- Callback/handler function when client is ready to read again.
	--
	function some_handler_that_reads()
		new_connection:recv(1024)
		new_connection:write('IOLoop works!')
		new_connection:close()
		--
		-- Test callbacks.
		--
		testloop:add_callback(function() print "This is a callback"  end)
		testloop:add_callback(function() print "This is another callback" end)

	end	
	testloop:add_handler(fd, READ, some_handler_that_reads) -- Callback/handler passed.
end

testloop:add_handler(fd, READ, some_handler_that_accepts)
testloop:start()
