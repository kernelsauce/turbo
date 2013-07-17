--- Turbo.lua Http client example
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

local turbo = require "turbo"
local TwitterFeedHandler = class("TwitterFeed", turbo.web.RequestHandler)

function TwitterFeedHandler:get(search)
    -- Use this handler by directing browser to 
    -- http://*your hostname*/tweet/*twitter search phrase*
    local res = coroutine.yield(
        turbo.async.HTTPClient:new():fetch(
            "http://search.twitter.com/search.json",
            {
                params = {
                    q=search,
                    result_type="mixed"
                }
            }))
    
    if (res.error) then
        error(turbo.web.HTTPError:new(500, res.error.message))
    end
    
    if (res.headers:get_status_code() == 200) then
        -- Decode and create nice Twitter page!
        local json = turbo.escape.json_decode(res.body)
        self:write(string.format(
            [[<h1>Search for %s on Twitter gave these tweets:</h1>]], 
            search))
        for k, v in ipairs(json.results) do
            local text = v.text
            local pic = v.profile_image_url
            self:write(string.format([[
                <img src="%s">
                <p>%s</p>
                <br />
            ]], pic, text))
        end
    else
        error(turbo.web.HTTPError:new(res.headers:get_status_code(), 
            "Something bad happened!"))
    end
end

local application = turbo.web.Application:new({
    {"/tweet/(.*)", TwitterFeedHandler}
})

application:listen(8888)
turbo.ioloop.instance():start()
