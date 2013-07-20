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
	it("should be constructed right", function()
		local buf = turbo.structs.buffer()
		assert.truthy(instanceOf(turbo.structs.buffer, buf))
	end)
	it("should append correctly", function()
		local buf = turbo.structs.buffer()
		buf:append_luastr_right("Long string")
		buf:append_luastr_right(" that is expected to")
		buf:append_luastr_right(" equal a constant")
		assert.equal(tostring(buf), "Long string that is expected to equal a constant")
	end)
	it("should prepend correctly", function()
		local buf = turbo.structs.buffer()
		buf:append_luastr_left(" equal a constant")
		buf:append_luastr_left(" that is expected to")
		buf:append_luastr_left("Long string")
		assert.equal(tostring(buf), "Long string that is expected to equal a constant")
	end)
	it("should handle mixed append/prepend", function()
		local buf = turbo.structs.buffer()
		local cmp = ""
		for i = 0, 10000 do
			local dice = math.random() * 10
			if dice > 5 then
				cmp = tostring(dice) .. cmp
				buf:append_luastr_left(tostring(dice))
			else
				cmp = cmp .. tostring(dice)
				buf:append_luastr_right(tostring(dice))
			end
		end
		assert.equal(cmp, tostring(buf))
		assert.equal(cmp:len(), buf:len())
	end)
	it("should support == operator", function()
		local buf = turbo.structs.buffer()
		buf:append_luastr_right("two equal string should equal!")
		local buf2 = turbo.structs.buffer()
		buf2:append_luastr_right("two equal string should equal!")
		assert.truthy(buf == buf2)
		buf2:clear()
		assert.truthy(buf ~= buf2)
	end)
	it("should pop correctly", function()
		local buf = turbo.structs.buffer()
		for i = 1, 10000 do
			buf:append_luastr_right("much data in here")
		end
		buf:pop_right(string.len("much data in here") * 10000)
		assert.equal(buf:len(), 0)
		for i = 1, 10000 do
			buf:append_luastr_left("much data in here")
		end
		assert.has_error(function()
			buf:pop_right(string.len("much data in here") * 10001)
		end)
		while buf:len() ~= 0 do
			buf:pop_left(1)
		end
		assert.equal(tostring(buf), "")
		buf:clear()
	end)
end)