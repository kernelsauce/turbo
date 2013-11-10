#!/usr/bin/env luajit

local turbo = require "turbo"
local yield = coroutine.yield
turbo.log.categories.success = false

local url = arg[1]

local bytes = turbo.structs.buffer()
print("generating string...")
for i = 1, 1024*1024*100 do
    bytes:append_luastr_right(string.char(math.random(1, 128)))
end

local io = turbo.ioloop.instance()


io:add_callback(function()
    local sock, msg = turbo.socket.new_nonblock_socket(
        turbo.socket.AF_INET, 
        turbo.socket.SOCK_STREAM, 
        0)
    if sock == -1 then 
        error("Could not create socket.")
    end
    local stream = turbo.iostream.IOStream:new(sock)
    local rc, msg = stream:connect(
        "127.0.0.1", 
        8888,
        turbo.socket.AF_INET,
        function()
            print("Connected... nuking.")
            stream:set_close_callback(function() 
                print("Socket closed!")
                io:close()
            end)
            yield (turbo.async.task(stream.write_zero_copy, stream, bytes))
            print("loaded up with 100MB")
        end)
    if rc ~= 0 then
        error("Could not connect")
    end
end)


io:start()