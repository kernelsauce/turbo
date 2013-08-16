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

describe("turbo low level buffer module", function()
	it("should work", function()
		local haystack = turbo.structs.buffer()
		for i = 0, 10000 do 
			haystack:append_luastr_right("this is a big ass string.")
		end
		haystack:append_luastr_right("noob")
		for i = 0, 10000 do 
			haystack:append_luastr_right("this is a big ass string.")
		end
		local needle = turbo.structs.buffer()
		needle:append_luastr_right("string")
		local h_str, h_len = haystack:get()
		local n_str, n_len = needle:get()
		print(turbo.util.TBM(n_str, n_len, h_str, h_len))
	end)
end)