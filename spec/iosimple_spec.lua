--- Turbo.lua Unit test
--
-- Copyright 2015 John Abrahamsen
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

local turbo = require 'turbo'

turbo.ioloop.instance():add_callback(function()
    local stream = turbo.iosimple.dial("tcp://turbolua.org:80")

    stream:write("GET / HTTP/1.0\r\n\r\n")
    local data = stream:read_until_close()

    turbo.ioloop.instance():close()
end):start()

