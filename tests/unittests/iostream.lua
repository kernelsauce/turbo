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

describe("turbo.iostream Namespace", function()
	-- Many of the tests rely on the fact that the TCPServer class
	-- functions as expected...
	describe("IOStream/SSLIOStream classes", function()

		teardown(function() _G.io_loop_instance = nil end)

		it("IOStream:connect, localhost", function()
			local io = turbo.ioloop.IOLoop()
			local port = math.random(10000,40000)
			local connected = false
			local failed = false
			
			-- Server
			local Server = class("TestServer", turbo.tcpserver.TCPServer)
			function Server:handle_stream(stream)
				stream:close()
			end
			local srv = Server(io)
			srv:listen(port)

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
						error("Could not connect.")
					end)
			end)
			io:wait(2)
			srv:stop()
			assert.truthy(connected)
			assert.falsy(failed)
		end)

		it("IOStream:connect, hostnames,e.g turbolua.org", function()
			-- If this fails make sure there is a connection available.
			local io = turbo.ioloop.IOLoop()
			local connected = false
			local failed = false
			io:add_callback(function() 
				-- Client
				local fd = turbo.socket.new_nonblock_socket(turbo.socket.AF_INET,
					turbo.socket.SOCK_STREAM, 
					0)
				local stream = turbo.iostream.IOStream(fd, io)
				assert.equal(stream:connect("turbolua.org", 
					80, 
					turbo.socket.AF_INET, 
					function()
						connected = true
						stream:close()
						io:close()
					end,
					function(err)
						failed = true
						error("Could not connect.")
					end), 0)
			end)
			io:wait(2)
			assert.truthy(connected)
			assert.falsy(failed)
		end)

		it("IOStream:read_bytes", function()
			local io = turbo.ioloop.instance()
			local port = math.random(10000,40000)
			local connected = false
			local data = false
			local bytes = turbo.structs.buffer()
			for i = 1, 1024*1024 do
				bytes:append_luastr_right(string.char(math.random(1, 128)))
			end
			bytes = tostring(bytes)

			-- Server
			local Server = class("TestServer", turbo.tcpserver.TCPServer)
			local srv
			function Server:handle_stream(stream)
				io:add_callback(function()
					coroutine.yield (turbo.async.task(stream.write, stream, bytes))
					stream:close()
					srv:stop()
				end)
			end
			srv = Server(io)
			srv:listen(port)


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
						local res = coroutine.yield (turbo.async.task(
													 stream.read_bytes,stream,1024*1024))						
						data = true
						assert.equal(res, bytes)
						stream:close()
						io:close()
					end,
					function(err)
						failed = true
						io:close()
						error("Could not connect.")
					end)
			end)
			io:wait(2)
			srv:stop()
			assert.truthy(connected)
			assert.truthy(data)
		end)

		it("IOStream:read_until", function()
			local delim = "CRLF GALLORE\r\n\r\n\r\n\r\n\r"
			local io = turbo.ioloop.instance()
			local port = math.random(10000,40000)
			local connected, failed = false, false
			local data = false
			local bytes = turbo.structs.buffer()
			for i = 1, 1024*1024 do
				bytes:append_luastr_right(string.char(math.random(1, 128)))
			end
			bytes:append_luastr_right(delim)
			local bytes2 = tostring(bytes) -- Used to match correct delimiter cut.
			for i = 1, 1024*1024 do
				bytes:append_luastr_right(string.char(math.random(1, 128)))
			end			
			bytes = tostring(bytes)

			-- Server
			local Server = class("TestServer", turbo.tcpserver.TCPServer)
			function Server:handle_stream(stream)
				io:add_callback(function()
					coroutine.yield (turbo.async.task(stream.write, stream, bytes))
					stream:close()
				end)
			end
			local srv = Server(io)
			srv:listen(port)

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
						local res = coroutine.yield (turbo.async.task(
													 stream.read_until,stream,delim))					
						data = true
						assert.equal(res, bytes2)
						stream:close()
						io:close()
					end,
					function(err)
						failed = true
						io:close()
						error("Could not connect.")
					end)
			end)
			
			io:wait(1)
			srv:stop()
			assert.falsy(failed)
			assert.truthy(connected)
			assert.truthy(data)
		end)

	end)
end)