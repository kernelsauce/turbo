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

local util = {}

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


