--- Turbo.lua Streaming write example
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

local ChunkedHandler = class("ChunkedHandler", turbo.web.RequestHandler)

function ChunkedHandler:get()
    self:set_chunked_write()
    self:write("Hello world! ")
    self:write("Another world is coming soon. ")
    self:flush() -- At this point the RequestHandler buffer is flushed.
    self:write("Hello Mars!") -- Refill buffer.
    -- Flush again.
    -- Each flush will end up as one chunk in the IOStream.
    self:flush()
    self:finish()
end

turbo.web.Application({{"^/$", ChunkedHandler}}):listen(8888)
turbo.ioloop.instance():start()
