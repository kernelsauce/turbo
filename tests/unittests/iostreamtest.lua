--- Turbo.lua Unit test
--
-- Copyright 2013 John Abrahamsen
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.	


local turbo = require 'turbo'
math.randomseed(turbo.util.gettimeofday())

describe("IOStream/SSLIOStream classes", function()
	describe("iostream connect", function()
		it("it should connect", function()
			local io = turbo.ioloop.IOLoop()
			local port = math.random(10000,40000)
			local connected = false
			local failed = false
			
			io:add_callback(function() 
				-- Server
				local Server = class("TestServer", turbo.tcpserver.TCPServer)
				function Server:handle_stream(stream)
					stream:close()
				end
				local srv = Server(io)
				srv:listen(port)
			end)
			
			io:add_callback(function() 
				-- Client
				local fd = turbo.socket.new_nonblock_socket(turbo.socket.AF_INET,
					turbo.socket.SOCK_STREAM, 
					0)
				local stream = turbo.iostream.IOStream(fd, io)
				stream:connect("127.0.0.1", 
					port, 
					turbo.socket.AF_INET, 
					function()
						connected = true
						stream:close()
						io:close()
					end,
					function(err)
						failed = true
						io:close()
						print(err)
					end)
			end)
			io:wait(2)
			assert.equal(connected, true)
		end)
	end)
end)