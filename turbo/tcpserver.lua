--[[ Turbo TCP Server module

Copyright 2011, 2012, 2013 John Abrahamsen

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.		]]
  
local log =         require "turbo.log"
local util =        require "turbo.util"
local iostream =    require "turbo.iostream"
local ioloop =      require "turbo.ioloop"
local socket =      require "turbo.socket_ffi"
local sockutil =    require "turbo.sockutil"
local ngc =         require "turbo.nwglobals"
local crypto =      require "turbo.crypto"
local ffi =         require "ffi"
local bit =         require "bit"
require "turbo.3rdparty.middleclass"

local SOL_SOCKET =  socket.SOL_SOCKET
local SO_RESUSEADDR = socket.SO_REUSEADDR
local O_NONBLOCK =  socket.O_NONBLOCK
local F_SETFL =     socket.F_SETFL
local F_GETFL =     socket.F_GETFL
local SOCK_STREAM = socket.SOCK_STREAM
local INADDRY_ANY = socket.INADDR_ANY
local AF_INET =     socket.AF_INET
local EWOULDBLOCK = socket.EWOULDBLOCK
local EAGAIN =      socket.EAGAIN

local tcpserver = {}  -- tcpserver namespace

tcpserver.TCPServer = class('TCPServer')

function tcpserver.TCPServer:initialize(io_loop, ssl_options, max_buffer_size, read_chunk_size)	
    self.io_loop = io_loop or ioloop.instance()
    self.ssl_options = ssl_options
    self.read_chunk_size = read_chunk_size
    self.max_buffer_size = max_buffer_size
    self._sockets = {}
    self._pending_sockets = {}
    self._started = false
    -- Validate SSL options if set.
    if self.ssl_options then
        if not type(ssl_options.cert_file) == "string" then
            error("ssl_options argument is set, but cert_file argument is missing or not a string.")
        end
        if not type(ssl_options.key_file) == "string" then
            error("ssl_options argument is set, but key_file arguments is missing or not a string.")
        end
        -- So the only check that is done is that the cert and key file are readable.
        -- However the validity of the keys are not checked until we create the SSL context.
        if not util.file_exists(ssl_options.cert_file) then
            error(string.format("SSL cert_file, %s, does not exist.", ssl_options.cert_file))
        end
        if not util.file_exists(ssl_options.key_file) then
            error(string.format("SSL key_file, %s, does not exist.", ssl_options.key_file))
        end
        -- The ssl_create_context function will raise error and exit by its own, so there is
        -- no need to catch errors.
        crypto.ssl_init()
        local rc, ssl_ctx = crypto.ssl_create_server_context(self.ssl_options.cert_file, self.ssl_options.key_file)
        if rc ~= 0 then
            error(string.format("Could not create SSL context. %s", crypto.ERR_error_string(rc)))
        end
        self._ssl_ctx = ssl_ctx
        self.ssl_options._ssl_ctx = self._ssl_ctx
    end
end

--[[ Start listening on port and address.
If no address is supplied, * will be used.     ]]
function tcpserver.TCPServer:listen(port, address)
    assert(port, [[Please specify port for listen() method]])
    local sock = sockutil.bind_sockets(port, address, 1024)
    log.devel("[tcpserver.lua] TCPServer listening on port: " .. port)
    self:add_sockets({sock})
end


--[[ Add multiple sockets in a table.        ]]
function tcpserver.TCPServer:add_sockets(sockets)	
    if not self.io_loop then
	    self.io_loop = ioloop.instance()
    end
    for _, sock in ipairs(sockets) do
        self._sockets[sock] = sock
        sockutil.add_accept_handler(sock,
            function(connection, address)
                self:_handle_connection(connection, address)
            end,
            self.io_loop)
    end
end

--[[ Add a single socket.     ]]
function tcpserver.TCPServer:add_socket(socket)	self:add_sockets({socket}) end

function tcpserver.TCPServer:bind(port, address, backlog)
    local backlog = backlog or 128
    local sockets = sockutil.bind_sockets(port, address, backlog)
    if self._started then
	self:add_sockets(sockets)
    else
        self._pending_sockets[#self._pending_sockets + 1] = sockets
    end
end

--[[ Start the TCPServer.		]]
function tcpserver.TCPServer:start()	
	assert((not self._started), "Running started on a already started TCPServer.")
	self._started = true
	local sockets = self._pending_sockets
	self._pending_sockets = {}
	self:add_sockets(sockets)
end

--[[ Stop the TCPServer.		]]
function tcpserver.TCPServer:stop()
    for fd, sock in pairs(self._sockets) do
	self.io_loop:remove_handler(fd)
	assert(socket.close(sock) == 0)
	ngc.dec("tcp_open_sockets", 1)
    end
end

--[[ What to do with a new stream/connection.
-- This method should be redefined when inheriting from the TCPServer class.  ]]
function tcpserver.TCPServer:handle_stream(stream, address)	
	error('handle_stream method not implemented in this object')
end

--[[ Handle new connection.    ]]
function tcpserver.TCPServer:_handle_connection(connection, address)
    if self.ssl_options ~= nil then
        local stream = iostream.SSLIOStream:new(connection, self.ssl_options, self.io_loop, self.max_buffer_size, self.read_chunk_size)
        self:handle_stream(stream, address)
    else
	local stream = iostream.IOStream:new(connection, self.io_loop, self.max_buffer_size, self.read_chunk_size)
	self:handle_stream(stream, address)
    end
end

return tcpserver
