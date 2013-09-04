-- Turbo.lua Utilities module.
--
-- Copyright John Abrahamsen 2011, 2012, 2013 < JhnAbrhmsn@gmail.com >
--
-- "Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE."		

local ffi = require "ffi"
require "turbo.cdef"
local  UCHAR_MAX = tonumber(ffi.new("uint8_t", -1))
local g_time_str_buf = ffi.new("char[1024]")
local g_time_t = ffi.new("time_t[1]")

--- Extends the standard string library with a split method.
function string:split(sep, max, pattern)	
    assert(sep ~= '')
    assert(max == nil or max >= 1)

    local aRecord = {}
    if self:len() > 0 then
        local bPlain = not pattern
        max = max or -1
        local nField=1 nStart=1
        local nFirst, nLast = self:find(sep, nStart, bPlain)
        while nFirst and max ~= 0 do
            aRecord[nField] = self:sub(nStart, nFirst-1)
            nField = nField+1
            nStart = nLast+1
            nFirst, nLast = self:find(sep, nStart, bPlain)
            max = max-1
        end
        aRecord[nField] = self:sub(nStart)
    end
    return aRecord
end

local util = {}

--- Join a list into a string with  given delimiter. 
function util.join(delimiter, list)
	local len = #list
	if len == 0 then 
        return "" 
    end
    local string = list[1]
    for i = 2, len do 
        string = string .. delimiter .. list[i] 
    end
    return string
end


--- Convert number value to hexadecimal string format.
-- @param num The number to convert.
-- @return String
function util.hex(num)
    local hexstr = '0123456789abcdef'
    local s = ''
    while num > 0 do
        local mod = math.fmod(num, 16)
        s = string.sub(hexstr, mod+1, mod+1) .. s
        num = math.floor(num / 16)
    end
    if s == '' then 
        s = '0' 
    end
    return s
end
local hex = util.hex

--- Dump memory region to stdout, from ptr to given size. Usefull for 
-- debugging Luajit FFI. Notice! This can and will cause a SIGSEGV if 
-- not being used on valid pointers.
-- @param ptr A cdata pointer (from FFI)
-- @param sz (Number) Length to dump contents for.
function util.mem_dump(ptr, sz)
    local voidptr = ffi.cast("unsigned char *", ptr)
    if not voidptr then
        error("Trying to dump null ptr")
    end

    io.write(string.format("Pointer type: %s\
        From memory location: 0x%s dumping %d bytes\n",
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


--- Merge two tables to one.
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

--- Returns true if value exists in table.
function util.is_in(needle, haystack)
	if not needle or not haystack then 
        return nil 
    end
	local i
	for i = 1, #haystack, 1 do 
		if needle == haystack[i] then
			return true
		end
	end
	return
end

--*************** Time and date *************** 

--- Current msecs since epoch. Better granularity than Lua builtin.
-- @return Number
function util.gettimeofday()
    local timeval = ffi.new("struct timeval")
    ffi.C.gettimeofday(timeval, nil)
    return (tonumber(timeval.tv_sec) * 1000) + 
        math.floor(tonumber(timeval.tv_usec) / 1000)
end

--- Create a time string used in HTTP cookies.
-- "Sun, 04-Sep-2033 16:49:21 GMT"
function util.time_format_cookie(epoch)
    g_time_t[0] = epoch
    local tm = ffi.C.gmtime(g_time_t)
    local sz = ffi.C.strftime(
        g_time_str_buf, 
        1024, 
        "%a, %d-%b-%Y %H:%M:%S GMT", 
        tm)
    return ffi.string(g_time_str_buf, sz)
end

--- Create a time string used in HTTP header fields.
-- "Sun, 04 Sep 2033 16:49:21 GMT"
function util.time_format_http_header(time_t)
    g_time_t[0] = time_t
    local tm = ffi.C.gmtime(g_time_t)
    local sz = ffi.C.strftime(
        g_time_str_buf, 
        1024, 
        "%a, %d %b %Y %H:%M:%S GMT", 
        tm)
    return ffi.string(g_time_str_buf, sz)
end

--*************** File ***************

--- Check if file exists on local filesystem.
-- @param path Full path to file
-- @return True or false.
function util.file_exists(path)
    local f = io.open(path, "r")
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

--******** Low-level buffer search *********

local function suffixes(x, m, suff)
    local f, g, i
  
    suff[m - 1] = m
    g = m - 1
    i = m - 2
    while i >= 0 do 
        if i > g and suff[i + m - 1 - f] < i - g then
            suff[i] = suff[i + m - 1 - f]
        else 
            if i < g then
                g = i
            end
            f = i
            while g >= 0 and x[g] == x[g + m - 1 - f] do
                g = g - 1
            end
            suff[i] = f - g
        end
        i = i -1
    end
end

local function preBmGs(x, m, bmGs)
    local i, j
    local suff = {}

    suffixes(x, m, suff);
    i = 0
    while i < m do
        bmGs[i] = m
        i = i + 1
    end
    j = 0
    i = m - 1
    while i >= 0 do
        if suff[i] == i + 1 then
            while j < m - 1 - i do
                if bmGs[j] == m then
                    bmGs[j] = m - 1 - i;
                end
            j = j + 1
            end
        end
        i = i -1
    end
    i = 0
    while i <= m - 2 do
        bmGs[m - 1 - suff[i]] = m - 1 - i;
        i = i +1
    end
end

local function preBmBc(x, m, bmBc)
    local i
    for i = 0, UCHAR_MAX - 1 do
        bmBc[i] = m
    end
    i = 0
    while i < m - 1 do
        bmBc[x[i]] = m - i - 1;
        i = i + 1
    end
end

local NEEDLE_MAX = 1024
local bmGs = ffi.new("int[?]", NEEDLE_MAX)
local bmBc = ffi.new("int[?]", NEEDLE_MAX)
--- Turbo Booyer-Moore memory search algorithm. 
-- Search through arbitrary memory and find first occurence of given byte sequence.
-- @param x char* Needle memory pointer
-- @param m int Needle size
-- @param y char* Haystack memory pointer
-- @param n int Haystack size.
function util.TBM(x, m, y, n)
    if m == 0 or n == 0 then
        return
    elseif m > NEEDLE_MAX then
        error("Needle exceeds NEEDLE_MAX defined in util.lua. \
            Can not do memory search.")
    end
    local bcShift, i, j, shift, u, v, turboShift  
    preBmGs(x, m, bmGs);
    preBmBc(x, m, bmBc);
    j = 0
    u = 0
    shift = m
    while j <= n - m do
        i = m -1
        while i >= 0 and x[i] == y[i + j] do
            i = i - 1
            if u ~= 0 and i == m - 1 - shift then
                i = i - u
            end
        end
        if i < 0 then
            return j
        else
            v = m - 1 - i;
            turboShift = u - v;
            bcShift = bmBc[y[i + j]] - m + 1 + i;
            shift = math.max(turboShift, bcShift);
            shift = math.max(shift, bmGs[i]);
            if shift == bmGs[i] then
                u = math.min(m - shift, v)
            else
                if turboShift < bcShift then
                    shift = math.max(shift, u + 1);
                    u = 0
                end
            end
        end
        j = j + shift
    end
end

function util.read_all(file)
    local f = io.open(file, "rb")
    local content = f:read("*all")
    f:close()
    return content
end

--- Find substring in memory string.
-- Based on lj_str_find in lj_str.c in LuaJIT by Mike Pall.
function util.str_find(s, p, slen, plen)
    if plen <= slen then
        if plen == 0 then
            return s
        else
            local c = ffi.cast("int", p[0])
            p = p + 1
            plen = plen - 1
            slen = slen - plen
            local q
            while slen > 0 do
                q = ffi.cast("char*", ffi.C.memchr(s, c, slen))
                if q == nil then 
                    break
                end
                if ffi.C.memcmp(q + 1, p, plen) == 0 then
                    return q
                end
                q = q + 1
                slen = slen - (q - s)
                s = q
            end
        end
    end
end

return util


