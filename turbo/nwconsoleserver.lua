--[[ Turbo Console Server

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

local tcpserver = require "turbo.tcpserver"
local ioloop = require "turbo.ioloop"
local escape = require "turbo.escape"
local ngc = require "turbo.nwglobals"
require "turbo.3rdparty.middleclass"


local console = {} -- console namespace

console.ConsoleServer = class('ConsoleServer', tcpserver.TCPServer)

function console.ConsoleServer:initialize(io_loop)
    io_loop = io_loop or ioloop.instance()
    tcpserver.TCPServer:initialize(io_loop)
end

function console.ConsoleServer:handle_stream(stream, address)
    console.ConsoleStream:new(stream, address)
end

console.ConsoleStream = class("ConsoleStream")

function console.ConsoleStream:initialize(stream, address)
    self.stream = stream
    self.address = address    
    stream:read_until("\n\n", function(data) self:handle_request(data) end)
end

function console.ConsoleStream:handle_request(data)
    local key = data:sub(1,1)
    if (key == "s") then           -- Statistics
        self.stream:write(escape.json_encode(ngc.ret()))
        
    elseif (key == "q") then       -- Quit
        self.stream:close()
        self = nil
        return
    end

    self.stream:write("\n\n")    
    self.stream:read_until("\n\n", function(data) self:handle_request(data) end)
end

return console