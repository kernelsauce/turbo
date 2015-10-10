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

_G.__TURBO_USE_LUASOCKET__ = os.getenv("TURBO_USE_LUASOCKET") and true or false
local turbo = require 'turbo'
math.randomseed(turbo.util.gettimeofday())

describe("turbo.iostream Namespace", function()
    -- Many of the tests rely on the fact that the TCPServer class
    -- functions as expected...

    describe("IOStream/SSLIOStream classes", function()

        before_each(function()
            -- Make sure we start with a fresh global IOLoop to
            -- avoid random results.
            _G.io_loop_instance = nil
        end)

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
                assert.equal(stream:connect("127.0.0.1",
                    port,
                    turbo.socket.AF_INET,
                    function()
                        connected = true
                        local res = coroutine.yield (turbo.async.task(
                                                     stream.read_until,stream,delim))
                        data = true
                        assert.truthy(res == bytes2)
                        stream:close()
                        io:close()
                    end,
                    function(err)
                        failed = true
                        io:close()
                        error("Could not connect.")
                    end), 0)
            end)

            io:wait(30)
            srv:stop()
            assert.falsy(failed)
            assert.truthy(connected)
            assert.truthy(data)
        end)

        it("IOStream:read_until_pattern", function()
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
                assert.equal(stream:connect("127.0.0.1",
                    port,
                    turbo.socket.AF_INET,
                    function()
                        connected = true
                        local res = coroutine.yield (turbo.async.task(
                                                     stream.read_until_pattern,stream,delim))
                        data = true
                        assert.truthy(res == bytes2)
                        stream:close()
                        io:close()
                    end,
                    function(err)
                        failed = true
                        io:close()
                        error("Could not connect.")
                    end), 0)
            end)

            io:wait(60)
            srv:stop()
            assert.falsy(failed)
            assert.truthy(connected)
            assert.truthy(data)
        end)

        it("IOStream:read_until_close", function()
            local io = turbo.ioloop.instance()
            local port = math.random(10000,40000)
            local connected, failed = false, false
            local data = false
            local bytes = turbo.structs.buffer()

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
                assert.equal(stream:connect("127.0.0.1",
                    port,
                    turbo.socket.AF_INET,
                    function()
                        connected = true
                        local res = coroutine.yield (turbo.async.task(
                                                     stream.read_until_close,stream))
                        data = true
                        assert.truthy(stream:closed())
                        assert.truthy(res == bytes)
                        io:close()
                    end,
                    function(err)
                        failed = true
                        io:close()
                        error("Could not connect.")
                    end), 0)
            end)

            io:wait(30)
            srv:stop()
            assert.falsy(failed)
            assert.truthy(connected)
            assert.truthy(data)
        end)

        if turbo.platform.__LINUX__ then
        it("IOStream:set_close_callback", function()
            local io = turbo.ioloop.IOLoop()
            local port = math.random(10000,40000)
            local connected = false
            local failed = false
            local closed = false

            -- Server
            local Server = class("TestServer", turbo.tcpserver.TCPServer)
            function Server:handle_stream(stream)
                stream:close()
                closed = true
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
                        stream:set_close_callback(function()
                            assert.truthy(closed)
                            io:close()
                        end)
                    end,
                    function(err)
                        failed = true
                        error("Could not connect.")
                    end)
            end)
            io:wait(10)
            srv:stop()
            assert.truthy(connected)
            assert.falsy(failed)
            assert.truthy(closed)
        end)

        it("IOStream:closed", function()
            local io = turbo.ioloop.IOLoop()
            local port = math.random(10000,40000)
            local connected = false
            local failed = false
            local closed = false

            -- Server
            local Server = class("TestServer", turbo.tcpserver.TCPServer)
            function Server:handle_stream(stream)
                assert.falsy(stream:closed())
                stream:close()
                closed = true
            end
            local srv = Server(io)
            srv:listen(port, "127.0.0.1")

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
                        assert.falsy(stream:closed())
                        stream:set_close_callback(function()
                            assert.truthy(stream:closed())
                            assert.truthy(closed)
                            io:close()
                        end)
                    end,
                    function(err)
                        failed = true
                        error("Could not connect.")
                    end)
            end)
            io:wait(10)
            srv:stop()
            assert.truthy(connected)
            assert.falsy(failed)
            assert.truthy(closed)
        end)
        end

        it("IOStream:writing", function()
            local io = turbo.ioloop.instance()
            local port = math.random(10000,40000)
            local connected, failed = false, false
            local data = false
            local bytes = turbo.structs.buffer()

            for i = 1, 1024*1024 do
                bytes:append_luastr_right(string.char(math.random(1, 128)))
            end
            bytes = tostring(bytes)

            -- Server
            local Server = class("TestServer", turbo.tcpserver.TCPServer)
            function Server:handle_stream(stream)
                io:add_callback(function()
                    assert.falsy(stream:writing())
                    stream:write(bytes, function()
                        assert.falsy(stream:writing())
                        stream:close()
                    end)
                    assert.truthy(stream:writing())
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
                assert.equal(stream:connect("127.0.0.1",
                    port,
                    turbo.socket.AF_INET,
                    function()
                        connected = true
                        local res = coroutine.yield (turbo.async.task(
                                                     stream.read_until_close,stream))
                        data = true
                        assert.truthy(stream:closed())
                        assert.truthy(res == bytes)
                        io:close()
                    end,
                    function(err)
                        failed = true
                        io:close()
                        error("Could not connect.")
                    end), 0)
            end)
        end)

        it("IOStream:reading", function()
            local io = turbo.ioloop.instance()
            local port = math.random(10000,40000)
            local connected, failed = false, false
            local data = false
            local bytes = turbo.structs.buffer()

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
                assert.equal(stream:connect("127.0.0.1",
                    port,
                    turbo.socket.AF_INET,
                    function()
                        connected = true
                        assert.falsy(stream:reading())
                        stream:read_until_close(function(res)
                            assert.falsy(stream:reading())
                            data = true
                            assert.truthy(stream:closed())
                            assert.truthy(res == bytes)
                            io:close()
                        end)
                        assert.truthy(stream:reading())
                    end,
                    function(err)
                        failed = true
                        io:close()
                        error("Could not connect.")
                    end), 0)
            end)

            io:wait(30)
            srv:stop()
            assert.falsy(failed)
            assert.truthy(connected)
            assert.truthy(data)
        end)

        it("IOStream streaming callbacks", function()
            local io = turbo.ioloop.instance()
            local port = math.random(10000,40000)
            local connected, failed = false, false
            local data = false
            local bytes = turbo.structs.buffer()
            local comp = turbo.structs.buffer()
            local streamed = 0

            -- Server
            local Server = class("TestServer", turbo.tcpserver.TCPServer)
            function Server:handle_stream(stream)
                io:add_callback(function()
                    for i = 1, 10 do
                        local rand = turbo.structs.buffer()
                        for i = 1, 1024*1024 do
                            rand:append_luastr_right(string.char(math.random(1, 128)))
                        end
                        bytes:append_right(rand:get())
                        coroutine.yield (turbo.async.task(stream.write, stream, tostring(rand)))
                    end
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
                assert.equal(stream:connect("127.0.0.1",
                    port,
                    turbo.socket.AF_INET,
                    function()
                        connected = true
                        stream:read_until_close(
                            function(res)
                                -- Will be called finally.
                                data = true
                                comp:append_luastr_right(res)
                                -- On close callback
                                io:close()
                            end, nil,
                            function(res)
                                -- Streaming callback
                                comp:append_luastr_right(res)
                                streamed = streamed + 1
                            end)
                    end,
                    function(err)
                        failed = true
                        io:close()
                        error("Could not connect.")
                    end), 0)
            end)

            io:wait(30)
            srv:stop()
            assert.falsy(failed)
            assert.truthy(connected)
            assert.truthy(data)
            assert.truthy(tostring(comp) == tostring(bytes))
            assert.truthy(streamed > 1)
        end)

    end)
end)