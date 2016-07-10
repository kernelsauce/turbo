--- Turbo.lua signalfd example
--
-- Copyright 2014 John Abrahamsen
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


local turbo = require("turbo")
local io = turbo.ioloop.instance()

print("Press CTRL-C 3 times to exit")

io:add_callback(function ()
    local times = 0
    io:add_signal_handler(turbo.signal.SIGINT, function (signum, info)
        print(string.format("\nReceived signal SIGINT (%d)", signum))
        times = times + 1
        if times == 3 then
            io:close()
        end
    end)
end)
io:start()

