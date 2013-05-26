#!/usr/local/bin/luajit

--[[ Nonsence Web console

Copyright 2013 John Abrahamsen

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.     ]]

require "curses"
require "os"

local nonsence = require "nonsence"
local SOCK_STREAM = nonsence.socket.SOCK_STREAM
local INADDRY_ANY = nonsence.socket.INADDR_ANY
local AF_INET = nonsence.socket.AF_INET



if not arg[1] then
    print "Please provide a hostname as argument."
    os.exit(1)
end

local addr = arg[1]:split(":")
if #addr ~= 2 then
    print "Bad syntax in hostname. Use <hostname:port>."
    os.exit(1)
end

local hostname = addr[1]
local port = tonumber(addr[2])

local io_loop = nonsence.ioloop.instance()
local stream = nonsence.iostream.IOStream:new(nonsence.socket.new_nonblock_socket(AF_INET, SOCK_STREAM, 0))

local rc, msg = stream:connect(hostname, port, AF_INET, function()
    -- On success
    curses.initscr()
    curses.cbreak()
    curses.echo(0)
    curses.nl(0)
    local stdscr = curses.stdscr()
    stdscr:clear()

    local reading = false
    io_loop:set_interval(200, function()
        -- 200 msec loop
        if reading then
            return
        end
        
        stream:write("s\n\n", function()
            reading = true
            stream:read_until("\n\n", function(data)
                if data:len() == 0 then
                    os.exit(1)
                end
                reading = false
                stdscr:clear()

                local stats = nonsence.escape.json_decode(data)
                stdscr:mvaddstr(0,0, "Nonsence Web Debug Console")                
    
                stdscr:mvaddstr(2,2, "TCP | Bytes recieved : ")
                stdscr:mvaddstr(2,60, stats.tcp_recv_bytes .. " B")
                
                stdscr:mvaddstr(3,2, "TCP | Bytes sent : ")
                stdscr:mvaddstr(3,60, stats.tcp_send_bytes .. " B")
                
                stdscr:mvaddstr(4,2, "TCP | Current open sockets : ")
                stdscr:mvaddstr(4,60, stats.tcp_open_sockets)
                
                stdscr:mvaddstr(5,2, "TCP | Total sockets opened : ")
                stdscr:mvaddstr(5,60, stats.tcp_total_connects )
                
                stdscr:mvaddstr(6,2, "IO Loop | Callbacks run : ")
                stdscr:mvaddstr(6,60, stats.ioloop_callbacks_run)
                
                stdscr:mvaddstr(7,2, "IO Loop | Callbacks in queue : ")
                stdscr:mvaddstr(7,60, stats.ioloop_callbacks_queue)
                
                stdscr:mvaddstr(8,2, "IO Loop | Callback errors caught : ")
                stdscr:mvaddstr(8,60, stats.ioloop_callbacks_error_count)
                
                stdscr:mvaddstr(9,2, "IO Loop | Current FD count: ")
                stdscr:mvaddstr(9,60, stats.ioloop_fd_count )                

                stdscr:mvaddstr(10,2, "IO Loop | Active handler count : ")
                stdscr:mvaddstr(10,60, stats.ioloop_handlers_total)

                stdscr:mvaddstr(11,2, "IO Loop | Handlers added : ")
                stdscr:mvaddstr(11,60, stats.ioloop_add_handler_count)
                                
                stdscr:mvaddstr(12,2, "IO Loop | Handlers updated: ")
                stdscr:mvaddstr(12,60, stats.ioloop_update_handler_count)                     

                stdscr:mvaddstr(13,2, "IO Loop | Handlers called : ")
                stdscr:mvaddstr(13,60, stats.ioloop_handlers_called)                     
                
                stdscr:mvaddstr(14,2, "IO Loop | Handler errors caught : ")
                stdscr:mvaddstr(14,60, stats.ioloop_handlers_errors_count)                                     

                stdscr:mvaddstr(15,2, "IO Loop | Active timeout callback count : ")
                stdscr:mvaddstr(15,60, stats.ioloop_timeout_count)
                
                stdscr:mvaddstr(16,2, "IO Loop | Active interal callback count : ")
                stdscr:mvaddstr(16,60, stats.ioloop_interval_count)
                
                stdscr:mvaddstr(17,2, "IO Loop | Iteration count : ")
                stdscr:mvaddstr(17,60, stats.ioloop_iteration_count) 

                stdscr:mvaddstr(18,2, "File cache | Objects count : ")
                stdscr:mvaddstr(18,60, stats.static_cache_objects) 

                stdscr:mvaddstr(19,2, "File cache | Total bytes : ")
                stdscr:mvaddstr(19,60, stats.static_cache_bytes) 
                
                stdscr:refresh()
            end)
        end)
        
    end)
end, function(_, errno)
    -- On connect fail
    print(string.format("Could not connect to host %s: %s.", hostname, nonsence.socket.strerror(errno)))
    os.exit(1)
end)


if rc == -1 then
    print("Could not connect to host. Invalid hostname given.")
    os.exit(1)
elseif rc == -3 then
    print("Could not connect. Unknown error.")
    os.exit(1)
end

io_loop:start()