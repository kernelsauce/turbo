--[[ Turbo Utilities module.

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
SOFTWARE."			]]

local ffi = require "ffi"

--[[ Extends the string library with a split method.   ]]
function string:split(sep, max, pattern)	
	assert(sep ~= '')
	assert(max == nil or max >= 1)

	local aRecord = {}

	if self:len() > 0 then
		local bPlain = not pattern
		max = max or -1

		local nField=1 nStart=1
		local nFirst,nLast = self:find(sep, nStart, bPlain)
		while nFirst and max ~= 0 do
			aRecord[nField] = self:sub(nStart, nFirst-1)
			nField = nField+1
			nStart = nLast+1
			nFirst,nLast = self:find(sep, nStart, bPlain)
			max = max-1
		end
		aRecord[nField] = self:sub(nStart)
	end

	return aRecord
end

local util = {}

--[[ Join a list into a string with  given delimiter.   ]]
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
    if (not voidptr) then
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
        if (voidptr[i] < 0xf) then
            hex_string = string.format("0x0%s ", hex(voidptr[i]))
        else
            hex_string = string.format("0x%s ", hex(voidptr[i]))
        end
        io.write(hex_string)
        p = p + 1
    end
    io.write("\n")
end


--[[ Merge two tables to one.   ]]
function util.tablemerge(t1, t2)
    for k, v in pairs(t2) do
        if (type(v) == "table") and (type(t1[k] or false) == "table") then
            util.tablemerge(t1[k], t2[k])
        else
            t1[k] = v
        end
    end
    return t1
end


function util.fast_assert(condition, ...) 
    if not condition then
       if next({...}) then
          local s,r = pcall(function (...) return(string.format(...)) end, ...)
          if s then
             error(r, 2)
          end
       end
       error("assertion failed!", 2)
    end
end

if not _G.TIME_H then
    _G.TIME_H = 1
    ffi.cdef([[
             
    typedef long time_t ;
    typedef long suseconds_t ;
    struct timeval
    {            
        time_t tv_sec;		/* Seconds.  */
        suseconds_t tv_usec;	/* Microseconds.  */
    };
    struct timezone
    {
        int tz_minuteswest;		/* Minutes west of GMT.  */
        int tz_dsttime;		/* Nonzero if DST is ever in effect.  */
    };
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
    typedef struct timezone * timezone_ptr_t;
    
    size_t strftime(char* ptr, size_t maxsize, const char* format, const struct tm* timeptr);
    struct tm *localtime(const time_t *timer);
    time_t time(time_t* timer);
    int fputs(const char *str, void *stream); // Stream defined as void to avoid pulling in FILE.
    int snprintf(char *s, size_t n, const char *format, ...);
    int sprintf ( char * str, const char * format, ... );
    
    struct tm * gmtime (const time_t * timer);
    extern int gettimeofday (struct timeval *tv, timezone_ptr_t tz);
    
    ]])
end
--[[ Current msecs since epoch. Better granularity than Lua builtin. ]]
function util.gettimeofday()
        local timeval = ffi.new("struct timeval")
        ffi.C.gettimeofday(timeval, nil)
        return (tonumber(timeval.tv_sec) * 1000) + math.floor(tonumber(timeval.tv_usec) / 1000)
end

ffi.cdef[[
unsigned long compressBound(unsigned long sourceLen);
int compress2(uint8_t *dest, unsigned long *destLen,
	      const uint8_t *source, unsigned long sourceLen, int level);
int uncompress(uint8_t *dest, unsigned long *destLen,
	       const uint8_t *source, unsigned long sourceLen);
]]

local zlib = ffi.load "z"
--[[ zlib compress.  ]]
function util.z_compress(txt)
  local n = zlib.compressBound(#txt)
  local buf = ffi.new("uint8_t[?]", n)
  local buflen = ffi.new("unsigned long[1]", n)
  local res = zlib.compress2(buf, buflen, txt, #txt, 9)
  assert(res == 0)
  return ffi.string(buf, buflen[0])
end

--[[ zlib decompress.  ]]
function util.z_decompress(comp, n)
  local buf = ffi.new("uint8_t[?]", n)
  local buflen = ffi.new("unsigned long[1]", n)
  local res = zlib.uncompress(buf, buflen, comp, #comp)
  assert(res == 0)
  return ffi.string(buf, buflen[0])
end

--[[  Returns true if value exists in table.        ]]
function util.is_in(needle, haystack)
	if not needle or not haystack then return nil end
	local i
	for i = 1, #haystack, 1 do 
		if needle == haystack[i] then
			return true
		end
	end
	return
end

function util.file_exists(name)
   local f = io.open(name, "r")
   if f ~= nil then
       io.close(f)
       return true
    else
        return false
    end
end

function util.funpack(t, i)
    i = i or 1
    if t[i] ~= nil then
        return t[i], util.funpack(t, i + 1)
    end
end

return util


