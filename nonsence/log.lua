--[[
	
		Nonsence Asynchronous event based Lua Web server.
		Author: John Abrahamsen < JhnAbrhmsn@gmail.com >
		
		This module "log" is a part of the Nonsence Web server.
		For the complete stack hereby called "software package" please see:
		
		https://github.com/JohnAbrahamsen/nonsence-ng/
		
		Many of the modules in the software package are derivatives of the 
		Tornado web server. Tornado is licensed under Apache 2.0 license.
		For more details on Tornado please see:
		
		http://www.tornadoweb.org/
		
		However, this module, log is not a derivate of Tornado and are
		hereby licensed under the MIT license.
		
		http://www.opensource.org/licenses/mit-license.php >:

		"Permission is hereby granted, free of charge, to any person obtaining a copy of
		this software and associated documentation files (the "Software"), to deal in
		the Software without restriction, including without limitation the rights to
		use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
		of the Software, and to permit persons to whom the Software is furnished to do
		so, subject to the following conditions:

		The above copyright notice and this permission notice shall be included in all
		copies or substantial portions of the Software.

		THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
		IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
		FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
		AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
		LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
		OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
		SOFTWARE."

  ]]
  
require('ansicolors')

local log = {} -- log namespace.

log.stringify = function (t, name, indent)
   local cart     -- a container
   local autoref  -- for self references
   local function isemptytable(t) return next(t) == nil end
   local function basicSerialize (o)
	  local so = tostring(o)
	  if type(o) == "function" then
	 local info = debug.getinfo(o, "S")
	 -- info.name is nil because o is not a calling level
	 if info.what == "C" then
		return string.format("%q", so .. ", C function")
	 else
		-- the information is defined through lines
		return string.format("%q", so .. ", defined in (" ..
		info.linedefined .. "-" .. info.lastlinedefined ..
		")" .. info.source)
	 end
	  elseif type(o) == "number" or type(o) == "boolean" then
	 return so
	  else
	 return string.format("%q", so)
	  end
   end

   local function addtocart (value, name, indent, saved, field)
	  indent = indent or ""
	  saved = saved or {}
	  field = field or name

	  cart = cart .. indent .. field

	  if type(value) ~= "table" then
	 cart = cart .. " = " .. basicSerialize(value) .. ";\n"
	  else
	 if saved[value] then
		cart = cart .. " = {}; -- " .. saved[value]
			.. " (self reference)\n"
		autoref = autoref ..  name .. " = " .. saved[value] .. ";\n"
	 else
		saved[value] = name
		--if tablecount(value) == 0 then
		if isemptytable(value) then
		   cart = cart .. " = {};\n"
		else
		   cart = cart .. " = {\n"
		   for k, v in pairs(value) do
		  k = basicSerialize(k)
		  local fname = string.format("%s[%s]", name, k)
		  field = string.format("[%s]", k)
		  -- three spaces between levels
		  addtocart(v, fname, indent .. "   ", saved, field)
		   end
		   cart = cart .. indent .. "};\n"
		end
	 end
	  end
   end

   name = name or "__unnamed__"
   if type(t) ~= "table" then
	  return name .. " = " .. basicSerialize(t)
   end
   cart, autoref = "", ""
   addtocart(t, name, indent)
   return cart .. autoref
end	

--[[ Usefull table printer for debug.       ]]
log.dump = function(stuff, description)
	print(log.stringify(stuff, description))
end

log.success = function(str)
	print(ansicolors.green .. "[S " .. os.date("%X", os.time()) .. '] ' .. str .. ansicolors.reset)
end

--[[ Prints a warning to stdout.      ]]
log.warning = function(str)	
	print(ansicolors.yellow .. "[W " .. os.date("%X", os.time()) .. '] ' .. str .. ansicolors.reset)
end

--[[ Prints a notice to stdout.  ]]
log.notice = function(str)
	print(ansicolors.white .. "[I " .. os.date("%X", os.time()) .. '] ' .. str .. ansicolors.reset)
end

--[[ Prints a error to stdout.  ]]
log.error = function(str)	
	print(ansicolors.red .. "[E " .. os.date("%X", os.time()) .. '] ' .. str .. ansicolors.reset)
end

--[[ Prints a error to stdout.  ]]
log.stacktrace = function(str)	
	print(ansicolors.onblue .. str .. ansicolors.reset)
end

return log
