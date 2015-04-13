--- Turbo.lua Github Feed
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

-- This implementation uses the Github REST API to pull current amount of
-- watchers for the Turbo.lua repository.

TURBO_SSL = true -- Enable SSL as Github API requires HTTPS.
local turbo = require "turbo"
local yield = coroutine.yield

local GithubFeed = class("GithubFeed", turbo.web.RequestHandler)

function GithubFeed:get(search)
    local res = yield(
        turbo.async.HTTPClient():fetch("https://api.github.com/repos/kernelsauce/turbo"))

    if res.error or res.headers:get_status_code() ~= 200 then
        -- Check for errors.
        -- If data could not be fetched a 500 error is sent as response.
        error(turbo.web.HTTPError:new(500, res.error.message))
    end

    local json = turbo.escape.json_decode(res.body)
    -- Ugly inlining of HTML code. You get the point!
    self:write([[<html><head></head><body>]])
    self:write(string.format(
        [[
        <h1>Turbo.lua Github feed<h1>
        <p>Current watchers %d</p>
        ]],
        json.watchers_count
        ))
    self:write([[</body></html>]])
end

local application = turbo.web.Application:new({
    {"^/$", GithubFeed}
})

application:listen(8888)
turbo.ioloop.instance():start()
