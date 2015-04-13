-- Turbo Unit test
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

local ffi = require "ffi"
if pcall(ffi.load, "ssl") then
	_G.TURBO_SSL = true
	local turbo = require "turbo"

	describe("turbo.hash Namespace", function()
	    it("SHA1 class", function()
	    	local hash = turbo.hash.SHA1("lol")
	    	assert.equal(hash:hex(), "403926033d001b5279df37cbbe5287b7c7c267fa")
	    end)
	    it("works with nil initializer", function()
	    	local hash = turbo.hash.SHA1()
		hash:update("lol")
		hash:finalize()
	    	assert.equal(hash:hex(), "403926033d001b5279df37cbbe5287b7c7c267fa")
	    end)
	    it("works with nil initializer and multiple updates", function()
	    	local hash = turbo.hash.SHA1()
		hash:update("l")
		hash:update("o")
		hash:update("l")
		hash:finalize()
	    	assert.equal(hash:hex(), "403926033d001b5279df37cbbe5287b7c7c267fa")
	    end)
	    it("gives error on already finalized context", function()
	    	local hash = turbo.hash.SHA1("lol")
		assert.has.errors(function() hash:update("ol") end)
	    end)
	    it("gives error on not yet finalized context", function()
	    	local hash = turbo.hash.SHA1()
		hash:update("lol")
		assert.has.errors(function() hash:hex() end)
	    end)
	end)
end
