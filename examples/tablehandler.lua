--- Turbo.lua Table Handler example.
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

ExampleHandler.get = {
    pre = {function(self)
            self:set_header("Server", "Special awesomeness V1")
            self.session = self:get_cookie("ritz")
            if not self.session then
                self.cookie = turbo.util.rand_str(10)
                self:set_cookie("ritz", self.cookie)
            end
        end, function(self)
            turbo.log.success("Someone is using my site!")
        end},
    main = function(self)
        self:write(
            string.format("Hello You. Your unique ID is %s. ", self.session))
    end,
    post = {function(self)
        self:write("Goodbye")
    end}
}

turbo.web.Application({
    {"^/$", ExampleHandler},
}):listen(8888)
turbo.ioloop.instance():start()
