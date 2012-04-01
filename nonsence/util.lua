--[[
	
		Nonsence Asynchronous event based Lua Web server.
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
		limitations under the License.

  ]]

function string:split(sSeparator, nMax, bRegexp)
	--[[
	
			Extends the string library with a split method
			
	  ]]
	
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

function util.join(delimiter, list)
	--[[
	
			join(delimiter, list)
			
			Description: Function to join a list into a string with 
			given delimiter.
	
	  ]]
	  
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

function util.is_in(value_to_check, table_to_check)
	--[[
	
			is_in(value, table)
			
			Description: Returns true if value exists in table.
				
	  ]]

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


