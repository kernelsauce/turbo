--[[ Turbo Log module

Copyright John Abrahamsen 2011, 2012, 2013 < JhnAbrhmsn@gmail.com >

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
SOFTWARE."             ]]

local util = require "turbo.util"
local ffi = require "ffi"

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


ffi.cdef([[
    struct tm
    {
      int tm_sec;			/* Seconds.	[0-60] (1 leap second) */
      int tm_min;			/* Minutes.	[0-59] */
      int tm_hour;			/* Hours.	[0-23] */
      int tm_mday;			/* Day.		[1-31] */
      int tm_mon;			/* Month.	[0-11] */
      int tm_year;			/* Year	- 1900.  */
      int tm_wday;			/* Day of week.	[0-6] */
      int tm_yday;			/* Days in year.[0-365]	*/
      int tm_isdst;			/* DST.		[-1/0/1]*/
      long int __tm_gmtoff;		/* Seconds east of UTC.  */
      const char *__tm_zone;	/* Timezone abbreviation.  */
    };
    
    typedef long time_t;
    size_t strftime(char* ptr, size_t maxsize, const char* format, const struct tm* timeptr);
    struct tm *localtime(const time_t *timer);
    time_t time(time_t* timer);
    int fputs(const char *str, void *stream); // Stream defined as void to avoid pulling in FILE.
    int snprintf(char *s, size_t n, const char *format, ...);
    int sprintf ( char * str, const char * format, ... );
]])

local buf = ffi.new("char[4096]") -- Buffer for log lines.
local time_t = ffi.new("time_t[1]")

--[[ Usefull table printer for debug.       ]]
log.dump = function(stuff, description)
    io.stdout:write(log.stringify(stuff, description) .. "\n")
end

log.success = function(str)
    ffi.C.time(time_t)
    local tm = ffi.C.localtime(time_t)
    local sz = ffi.C.strftime(buf, 4096, "\x1b[32m[S %Y/%m/%d %H:%M:%S] ", tm)
    local offset
    if sz + str:len() > 4094 then
        -- Use static buffer.
        ffi.C.sprintf(buf + sz, "%s\x1b[37m\n", ffi.cast("const char*", str))
        ffi.C.fputs(buf, io.stdout)
    else
        -- Use Lua string.
        io.stdout:write(ffi.string(buf, sz) .. str .. "\x1b[37m\n")
    end
end

--[[ Prints a notice to stdout.  ]]
log.notice = function(str)
    ffi.C.time(time_t)
    local tm = ffi.C.localtime(time_t)
    local sz = ffi.C.strftime(buf, 4096, "[I %Y/%m/%d %H:%M:%S] ", tm)
    local offset
    if sz + str:len() < 4094 then
        -- Use static buffer.
        ffi.C.sprintf(buf + sz, "%s\n", ffi.cast("const char*", str))
        ffi.C.fputs(buf, io.stdout)
    else
        -- Use Lua string.
        io.stdout:write(ffi.string(buf, sz) .. str .. "\n")
    end
end

--[[ Prints a notice to stdout.  ]]
log.debug = function(str)
    ffi.C.time(time_t)
    local tm = ffi.C.localtime(time_t)
    local sz = ffi.C.strftime(buf, 4096, "[D %Y/%m/%d %H:%M:%S] ", tm)
    local offset
    if sz + str:len() < 4094 then
        -- Use static buffer.
        ffi.C.sprintf(buf + sz, "%s\n", ffi.cast("const char*", str))
        ffi.C.fputs(buf, io.stdout)
    else
        -- Use Lua string.
        io.stdout:write(ffi.string(buf, sz) .. str .. "\n")
    end
end

--[[ Prints a error to stdout.  ]]
log.error = function(str)	
    ffi.C.time(time_t)
    local tm = ffi.C.localtime(time_t)
    local sz = ffi.C.strftime(buf, 4096, "\x1b[31m[E %Y/%m/%d %H:%M:%S] ", tm)
    local offset
    if sz + str:len() < 4094 then
        -- Use static buffer.
        ffi.C.sprintf(buf + sz, "%s\x1b[37m\n", ffi.cast("const char*", str))
        ffi.C.fputs(buf, io.stdout)
    else
        -- Use Lua string.
        io.stdout:write(ffi.string(buf, sz) .. str .. "\x1b[37m\n")
    end
end

--[[ Prints a warning to stdout.      ]]
log.warning = function(str)	
    ffi.C.time(time_t)
    local tm = ffi.C.localtime(time_t)
    local sz = ffi.C.strftime(buf, 4096, "\x1b[33m[W %Y/%m/%d %H:%M:%S] ", tm)
    local offset
    if sz + str:len() < 4094 then
        -- Use static buffer.
        ffi.C.sprintf(buf + sz, "%s\x1b[37m\n", ffi.cast("const char*", str))
        ffi.C.fputs(buf, io.stdout)
    else
        -- Use Lua string.
        io.stdout:write(ffi.string(buf, sz) .. str .. "\x1b[37m\n")
    end
end

--[[ Prints a error to stdout.  ]]
log.stacktrace = function(str)	
    io.stdout:write(nwcolors.red .. str .. nwcolors.reset .. "\n")
end

log.devel = function(str)
    ffi.C.time(time_t)
    local tm = ffi.C.localtime(time_t)
    local sz = ffi.C.strftime(buf, 4096, "\x1b[36m[d %Y/%m/%d %H:%M:%S] ", tm)
    local offset
    if sz + str:len() < 4094 then
        -- Use static buffer.
        ffi.C.sprintf(buf + sz, "%s\x1b[37m\n", ffi.cast("const char*", str))
        ffi.C.fputs(buf, io.stdout)
    else
        -- Use Lua string.
        io.stdout:write(ffi.string(buf, sz) .. str .. "\x1b[37m\n")
    end
end

return log
