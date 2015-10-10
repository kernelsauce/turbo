--- Turbo.lua Unit test
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
local ffi = require "ffi"

describe("turbo.util Namespace", function()

    describe("util.str_find", function()
        local search_time = 1000000
        local sneedle = "\r\n\r\n"
        local shaystack = "pkl2''234kokosmv,.-sd,fkwerj234982a9dfj89as9dhrh234"

        it("should work", function()
            local haystack = turbo.structs.buffer()
            for i = 0, search_time do
                haystack:append_luastr_right(shaystack)
            end
            haystack:append_luastr_right(sneedle)
            for i = 0, search_time do
                haystack:append_luastr_right(shaystack)
            end
            local needle = turbo.structs.buffer()
            needle:append_luastr_right(sneedle)
            local h_str, h_len = haystack:get()
            local n_str, n_len = needle:get()
            assert.equal(turbo.util.str_find(h_str, n_str, h_len, n_len) - h_str, 51000051)
        end)
    end)
end)