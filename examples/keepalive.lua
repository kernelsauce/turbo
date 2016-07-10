--- Turbo.lua HTTPClient.
-- A really simple one...
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

_G.TURBO_SSL = true -- Enable SSL
local turbo = require "turbo"

local tio = turbo.ioloop.instance()

tio:add_callback(function()
    local cli = turbo.async.HTTPClient()
    for i=1, 10, 1 do
        local res = coroutine.yield(
            cli:fetch("http://www.vg.no", {allow_redirects=true, keep_alive = true}))
        if res.error or res.headers:get_status_code() ~= 200 then
            -- Check for errors.
            tio:close()
            return
        else
            -- Handle body :) 
        end
    end
    tio:close()
end)
tio:start()