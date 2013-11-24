--- Turbo.lua Hash module
-- Wrappers for OpenSSL crypto.
--
-- Copyright 2011, 2012, 2013 John Abrahamsen
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

if not _G.TURBO_SSL then
    return setmetatable({},
    {
    __index = function(t, k)
        error("TURBO_SSL is not defined and you are trying to use hash functions.")
    end,
    __call  = function(t, k)
        error("TURBO_SSL is not defined and you are trying to use hash functions.")
    end
    })
end

local ffi = require "ffi"
local buffer = require "turbo.structs.buffer"
require "turbo.cdef"
local lssl = ffi.load("ssl")

-- Buffers
local hexstr = buffer()

local hash = {} -- hash namespace

hash.SHA1 = class("SHA1")

--- Create a SHA1 object. Pass a Lua string with the initializer to digest
-- it.
function hash.SHA1:initialize(str)
	self.md =  ffi.new("unsigned char[21]")
	if type(str) == "string" then
		lssl.SHA1(str, str:len(), self.md)
	end
end

--- Convert message digest to Lua hex string.
function hash.SHA1:hex()
	hexstr:clear()
	for i=0, 19 do
		hexstr:append_right(string.format("%02x", self.md[i]), 2)
	end
	local str = hexstr:__tostring()
	hexstr:clear(true)
	return str 
end

function hash.HMAC(key, digest)
	assert(type(key) == "string", "Key is invalid type: "..type(key))
	assert(type(digest) == "string", "Can not hash: "..type(digest))
	local digest = 
		lssl.HMAC(lssl.EVP_sha1(), 
				  key, key:len(), 
				  digest, 
				  digest:len(), 
				  nil, 
				  nil)
	hexstr:clear()
	for i=0, 19 do
		hexstr:append_right(string.format("%02x", digest[i]), 2)
	end
	local str = hexstr:__tostring()
	hexstr:clear(true)
	return str
end

return hash
