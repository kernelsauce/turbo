--[[ Nonsence Asynchronous event based Lua Web server.
Author: John Abrahamsen < JhnAbrhmsn@gmail.com >

This module "util" is a part of the Nonsence Web server.
For the complete stack hereby called "software package" please see:

https://github.com/JohnAbrahamsen/nonsence-ng/

Many of the modules in the software package are derivatives of the 
Tornado web server. Tornado is also licensed under Apache 2.0 license.
For more details on Tornado please see:

http://www.tornadoweb.org/


Copyright 2011 John Abrahamsen

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.  	]]

local ffi = require "ffi"

--[[ Extends the string library with a split method.   ]]
function string:split(sSeparator, nMax, bRegexp)	
	assert(sSeparator ~= '')
	assert(nMax == nil or nMax >= 1)

	local aRecord = {}

	if self:len() > 0 then
		local bPlain = not bRegexp
		nMax = nMax or -1

		local nField=1 nStart=1
		local nFirst,nLast = self:find(sSeparator, nStart, bPlain)
		while nFirst and nMax ~= 0 do
			aRecord[nField] = self:sub(nStart, nFirst-1)
			nField = nField+1
			nStart = nLast+1
			nFirst,nLast = self:find(sSeparator, nStart, bPlain)
			nMax = nMax-1
		end
		aRecord[nField] = self:sub(nStart)
	end

	return aRecord
end

local util = {}

--[[ Join a list into a string with  given delimiter.    ]]
function util.join(delimiter, list)
	local len = getn(list)
	if len == 0 then 
	return "" 
	end
	local string = list[1]
	for i = 2, len do 
	string = string .. delimiter .. list[i] 
	end
	return string
end

function util.hex(num)
    local hexstr = '0123456789abcdef'
    local s = ''
    while num > 0 do
        local mod = math.fmod(num, 16)
        s = string.sub(hexstr, mod+1, mod+1) .. s
        num = math.floor(num / 16)
    end
    if s == '' then s = '0' end
    return s
end
local hex = util.hex

function util.mem_dump(ptr, sz)
	local voidptr = ffi.cast("unsigned char *", ptr)
	if (voidptr == 0) then
		error("Trying to dump null ptr")
	end
        
	io.write(string.format("Pointer type: %s\nFrom memory location: 0x%s dumping %d bytes\n",
                               ffi.typeof(ptr),
                               hex(tonumber(ffi.cast("intptr_t", voidptr))),
                               sz))
        local p = 0;
        local sz_base_1 = sz - 1
        for i = 0, sz_base_1 do
            if (p == 10) then
                p = 0
                io.write("\n")
            end
            local hex_string
            if (voidptr[i] < 14) then
                hex_string = string.format("0x0%s ", hex(voidptr[i]))
            else
                hex_string = string.format("0x%s ", hex(voidptr[i]))
            end
            io.write(hex_string)
            p = p + 1
        end
	io.write("\n")
end

--[[  Returns true if value exists in table.        ]]
function util.is_in(value_to_check, table_to_check)
	if not value_to_check or not table_to_check then return nil end
	local i
	for i = 1, #value_to_check, 1 do 
		if value_to_check == table_to_check[i] then
			return true
		end
	end
	return
end

return util


