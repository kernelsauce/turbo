--- Turbo.lua Parameters example
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

local NumericHandler = class("NumericHandler", turbo.web.RequestHandler)

function NumericHandler:get(num)
    -- This handler takes one parameter from the Application class.
    -- The argument must consists of arbitrary length of digits.
    self:write("Numeric resource is: " .. num)
end


local ArgumentsHandler = class("ArgumentsHandler", turbo.web.RequestHandler)

function ArgumentsHandler:get()
    -- This handler takes one GET argument.
    self:write("Argument is: " .. self:get_argument("query"))
end

function ArgumentsHandler:post()
    -- This handler takes one POST argument.
    self:write("Argument is: " .. self:get_argument("query"))
end

turbo.web.Application({
    {"^/num/(%d*)$", NumericHandler},
    {"^/argument$", ArgumentsHandler}
}):listen(8888)
turbo.ioloop.instance():start()
