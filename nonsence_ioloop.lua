--[[

	"Nonsence" Lua web server
	Author: John Abrahamsen (jhnabrhmsn@gmail.com).
	License: MIT.

	The ultra fast cached web server written in Lua.


        .;''-.
      .' |    `._
     /`  ;       `'.
   .'     \         \
  ,'\|    `|         |
  | -'_     \ `'.__,J
 ;'   `.     `'.__.'
 |      `"-.___ ,'
 '-,           /
 |.-`-.______-|
 }      __.--'L
 ;   _,-  _.-"`\         ___
 `7-;"   '  _,,--._  ,-'`__ `.
  |/      ,'-     .7'.-"--.7 |        _.-'
  ;     ,'      .' .'  .-. \/       .'
   ;   /       / .'.-     ` |__   .'
    \ |      .' /  |    \_)-   `'/   _.-'``
     _,.--../ .'     \_) '`_      \'`
   '`f-'``'.`\;;'    ''`  '-`      |
      \`.__. ;;;,   )              /
       `-._,|;;;,, /\            ,'
        / /<_;;;;'   `-._    _,-'
       | '- /;;;;;,      `t'` \. I like nonsence.
       `'-'`_.|,';;;,      '._/| It wakes up the brain cells!
       ,_.-'  \ |;;;;;    `-._/
             / `;\ |;;;,  `"     - Theodor Seuss Geisel -
           .'     `'`\;;, /
          '           ;;;'|
              .--.    ;.:`\    _.--,
             |    `'./;' _ '_.'     |
              \_     `"7f `)       /
              |`   _.-'`t-'`"-.,__.'
              `'-'`/;;  | |   \ mx
                  ;;;  ,' |    `
                      /   '

]]--

local socket = {}

local epoll = assert(require('epoll'), [[Missing required module: Lua Epoll. (https://github.com/Neopallium/lua-epoll)]])
local nixio = assert(require('nixio'), [[Missing required module: Nixio (https://github.com/Neopallium/nixio)]])
local web = require('nonsence_web') -- Require web module for some tools.
local escape = require('nonsence_escape') -- Require escape module for some tools.
local mime = require('nonsence_mime') -- Require MIME module for document types.
local http_status_codes = require('nonsence_codes') -- Require codes module for HTTP status codes.

local parse_headers, nonsence_applications, split, gmatch, match, 
concat, xpcall, assert, ipairs, pairs, getmetatable, print, coroutine
= web.parse_headers, nonsence_applications, escape.split, 
string.gmatch , string.match, table.concat, xpcall, assert, ipairs, 
pairs, getmetatable, print, coroutine

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
			local HTTP_request, sender, port = sock:recv(1024)
			local buffer = {} -- Socket write buffer.
			
			--
			-- write_to_buffer function.
			--
			write_to_buffer = function(data)
				buffer[#buffer +1] = data
			end
			
			if HTTP_request and #HTTP_request > 0 then
				local Header = parse_headers(HTTP_request)
				local ErrorHandler = web.RequestHandler:new()
		
				if not Header.uri then -- TODO: Better invalid.
					sock_close(sock)
					return
				end
				local URL, Parameters = Header.uri:match("(/[^%? ]*)%??(%S-)$")
				for Pattern, RequestHandler in pairs(application) do 
					-- RequestHandler is actually just the url pattern in this case.
					if URL and match(URL, '^'..Pattern:gsub('%(',''):gsub('%)','')..'$') then
					
						local method = Header.method and Header.method:lower()
						if RequestHandler[method] and type(RequestHandler[method]) == 'function' then
						
							--
							-- Call method inside a coroutine to have a crash safe environment.
							--
							local safe_thread = coroutine.create(RequestHandler[method])
							local _, err_message = coroutine.resume(safe_thread, getmetatable(RequestHandler))
							if err_message then script_error_handler(err_message) end -- Throw exception from coroutine. Should we not write the buffer maybe?
							
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
					else
						print('skaft')
						--
						-- No RequestHandler assigned to this URL
						-- Give 404 Not Found
						--
						ErrorHandler:set_status_code(404)
						ErrorHandler:write();
						sock:write(concat(buffer)) -- Write from buffer.
						sock_close(sock)
					end
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
