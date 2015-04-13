--- Turbo.lua Hello world example
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

local ExampleHandler = class("ExampleHandler", turbo.web.RequestHandler)

function ExampleHandler:get()
    self:write("Hello world!")
end

turbo.web.Application({{"^/$", ExampleHandler}}):listen(8888, "::1")
turbo.ioloop.instance():start()
