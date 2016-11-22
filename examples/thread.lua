--- Turbo.lua Example module
--
-- Copyright 2016 John Abrahamsen
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

local turbo = require "turbo"

local function hard_work(n)
    return "This is hard work!"
end


turbo.ioloop.instance():add_callback(function()

    local thread = turbo.thread.Thread(function(th)
        th:send(hard_work())
        th:stop()
    end)

    local thread2 = turbo.thread.Thread(function(th)
        th:send(hard_work())
        th:stop()
    end)

    local data = coroutine.yield(turbo.async.task(
        thread.wait_for_data, thread))
    print(data)

    local data2 = coroutine.yield(turbo.async.task(
        thread2.wait_for_data, thread2))
    print(data2)

    turbo.ioloop.instance():close()

end):start()