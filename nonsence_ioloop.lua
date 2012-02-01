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
	
	IOLoop is a class responsible for managing I/O events. In addition it adds callback
	functionality to Lua.
	
  ]]

local epoll = assert(require('epoll'), [[Missing required module: Lua Epoll. (https://github.com/Neopallium/lua-epoll)]])
local nixio = assert(require('nixio'), [[Missing required module: Nixio (https://github.com/Neopallium/nixio)]])
local log = require('nonsence_log') -- Require log module for some tools.
local web = require('nonsence_web') -- Require web module for some tools.
local escape = require('nonsence_escape') -- Require escape module for some tools.
local mime = require('nonsence_mime') -- Require MIME module for document types.
local http_status_codes = require('nonsence_codes') -- Require codes module for HTTP status codes.

-------------------------------------------------------------------------
--
-- Assign locals
--
-------------------------------------------------------------------------
local parse_headers, nonsence_applications, split, gmatch, match, 
concat, xpcall, assert, ipairs, pairs, getmetatable, print, coroutine
, find, dump = web.parse_headers, nonsence_applications, escape.split, 
string.gmatch , string.match, table.concat, xpcall, assert, ipairs, 
pairs, getmetatable, print, coroutine, string.find, log.dump
-------------------------------------------------------------------------

local IOLoop = {}
function IOLoop:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	
	self._handler = {}
	self._events = {}
	self._callbacks = {}
	self._running = false
	self._stopped = false
	
	function self.start(self)	
		-- Starts the I/O loop.
		--
		-- The loop will run until stop is called.

		self._running = true
	end
	
	function self.close(self)
		-- Close the I/O loop.
		-- Close the loop after current events are run.

		self._running = false
		self._stopped = true
	end
	
	return o
end

--
-- Returning ioloop class table to require.
--
return {
	IOLoop = IOLoop
}

















--[[ local socket = {}

socket.start = function()
	---*
	--
	-- Start the web server.
	-- Method: start()
	-- Description: Creates socket and listens for requests.
	--
	---*
	
	--
	-- Create a new epoller
	--
	local epoller = epoll.new()

	-- Tables with sockets and callbacks called by epoll.
	local socks = {}
	local cbs = {}

	--
	-- Poll handlers
	--
	local function poll_add(sock, events, cb)
		--if #cbs > 200 then print(#cbs) end
		--if #socks > 200 then print(#socks) end
		local fd = sock:fileno()
		cbs[fd] = cb
		return epoller:add(fd, events, fd)
	end

	local function poll_mod(sock, events, cb)
		local fd = sock:fileno()
		cbs[fd] = cb
		return epoller:mod(fd, events, fd)
	end

	local function poll_del(sock)
		local fd = sock:fileno()
		cbs[fd] = nil
		return epoller:del(fd)
	end

	--
	-- Endless pool loop.
	--
	local function poll_loop()
		local events = {}
		while true do
			assert(epoller:wait(events, -1))
			for i=1,#events,2 do
				local fd = events[i]
				local ev = events[i+1]
				-- remove event from table.			
				events[i] = nil
				events[i+1] = nil
				-- call registered callback.
				local sock = socks[fd]
				local cb = cbs[fd]
				if sock and cb then
					cb(sock, ev)
				end
			end
		end
	end

	--
	-- Accept connection
	--
	local function accept_connection(sock, cb)
		local client = sock:accept()
		local fd = client:fileno()
		socks[fd] = client
		client:setblocking(false)
		-- register callback for read events.
		poll_add(client, epoll.EPOLLIN, cb)
		return client
	end

	--
	-- New acceptor
	--
	local function new_acceptor(host, port, family, cb)
		local sock = nixio.socket(family or 'inet', 'stream')
		local fd = sock:fileno()
		socks[fd] = sock
		sock:setblocking(false)
		assert(sock:setsockopt('socket', 'reuseaddr', 1))
		if host == '*' then host = nil end
		assert(sock:bind(host, port))
		assert(sock:listen(1024))
		-- register callback for read events.
		poll_add(sock, epoll.EPOLLIN, cb)
		return sock
	end

	--
	-- Close socket
	--
	local function sock_close(sock)
		local fd = sock:fileno()
		socks[fd] = nil
		poll_del(sock)
		sock:close()
	end

	local function script_error_handler(err)
		if err then
			print("Something went terribly bad when executing script: " .. err)
		end
	end

	--
	-- New client handler.
	-- RequestHandlers are run here.
	--
	local function new_client(server, application)
		accept_connection(server, function(sock, events)
			local callback = function()
				local HTTP_request, sender, port = sock:recv(1024)
				local buffer = {} -- Socket write buffer.
				
				--
				-- write_to_buffer function.
				--
				write_to_buffer = function(data)
					buffer[#buffer +1] = data
				end

				--
				-- Create a RequestHandler for errors.
				--
				local ErrorHandler = web.RequestHandler:new()
				
				if HTTP_request and #HTTP_request > 0 then
					local Header = parse_headers(HTTP_request)
			
					if not Header.uri then -- TODO: Better invalid.
						--
						-- URI missing. Can not do anything.
						-- Give 400 Bad Request status.
						--
						ErrorHandler:set_status_code(400)
						ErrorHandler:write();
						sock:write(concat(buffer)) -- Write from buffer.
						sock_close(sock)
						return
					end
					
					local RequestHandler_hit = false -- Flag for matching RequestHandler.
					
					local URL, Arguments = Header.uri:match("(/[^%? ]*)%??(%S-)$")
					for Pattern, RequestHandler in pairs(application) do 
						if URL and match(URL, "^"..Pattern.."$") then -- Check if pattern exists in Application.
						
							local method = Header.method and Header.method:lower()
							if RequestHandler[method] and type(RequestHandler[method]) == 'function' then
								
								RequestHandler_hit = true
								
								if Arguments then
									RequestHandler._set_arguments(getmetatable(RequestHandler), Arguments)
								end
								
								--
								-- Call method inside a coroutine to have a crash safe environment.
								--
								local safe_thread = coroutine.create(RequestHandler[method])
								local _, err_message = coroutine.resume(safe_thread, getmetatable(RequestHandler), 'skaft')
								-- Throw exception from coroutine. Should we not write the buffer maybe?
								if err_message then script_error_handler(err_message) end
								
							else
							
								--
								-- Method requested not implemented in RequestHandler
								-- Give 405 Not Implemented status
								--
								ErrorHandler:set_status_code(405)
								ErrorHandler:write();
								sock:write(concat(buffer)) -- Write from buffer.
								sock_close(sock)
								return
							end
							
							--
							-- RequestHandler finished running.
							-- Flush buffer.
							--
							sock:write(concat(buffer)) -- Write from buffer.
							sock_close(sock)
						end
					end
					if not RequestHandler_hit then
						--
						-- No RequestHandler assigned to this URL
						-- Give 404 Not Found
						--
						ErrorHandler:set_status_code(404)
						ErrorHandler:write();
						sock:write(concat(buffer)) -- Write from buffer.
						sock_close(sock)
					end				
				else
				
					--
					-- Request missing or garbled request.
					-- Give 400 Bad Request status.
					--
					ErrorHandler:set_status_code(400)
					ErrorHandler:write();
					sock:write(concat(buffer)) -- Write from buffer.
					sock_close(sock)
				end
			end
			poll_add(sock, epoll.EPOLLIN, callback)
		end)
	end

	--
	-- New server
	--
	local function new_server(port, application)
		print("Spawned new Nonsence Application on port:", port)
		new_acceptor('*', port, 'inet', function(sock, events)
			new_client(sock, application)
		end)
	end
	
	--
	-- Add a server for each application.
	--
	for _,application in ipairs(nonsence_applications) do
		-- Spawn new server with routinglist supplied
		new_server(application.port, application.routinglist)
	end
	
	--
	-- Start endless IO loop.
	--
	poll_loop()
end

return socket

--]]
