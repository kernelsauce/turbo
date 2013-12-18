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
local C = ffi.C
require "turbo.cdef"
local  UCHAR_MAX = tonumber(ffi.new("uint8_t", -1))
local g_time_str_buf = ffi.new("char[1024]")
local g_time_t = ffi.new("time_t[1]")
local g_timeval = ffi.new("struct timeval")

local util = {}

--*************** String library extensions ***************

--- Extends the standard string library with a split method.
function string:split(sep, max, pattern)
    assert(sep ~= '', "Separator is not a string or a empty string.")
    assert(max == nil or max >= 1, "Max is 0 or a negative number.")

    local record = {}
    if self:len() > 0 then
        local plain = not pattern
        max = max or -1
        local field=1 start=1
        local first, last = self:find(sep, start, plain)
        while first and max ~= 0 do
            record[field] = self:sub(start, first-1)
            field = field+1
            start = last+1
            first, last = self:find(sep, start, plain)
            max = max-1
        end
        record[field] = self:sub(start)
    end
    return record
end

-- strip white space from sides of a string
function string:strip()
    return self:match("^%s*(.-)%s*$")
end

--- Create substring from.
-- Beware that index starts at 0.
-- @param from From index, can be nil to indicate start.
-- @param to To index, can be nil to indicate end.
-- @return string
function string:substr(from, to)
    local len = self:len()
    from = from or 0
    to = to or len
    assert(from < len, "From out of range.")
    assert(to <= len, "To out of range.")
    assert(from < to, "From greater than to.")
    local ptr = ffi.cast("char *", self)
    return ffi.string(ptr + from, to - from)
end

--*************** Table utilites ***************

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

--- unpack that does not cause trace abort.
-- May not be very fast if large tables are unpacked.
function util.funpack(t, i)
    i = i or 1
    if t[i] ~= nil then
        return t[i], util.funpack(t, i + 1)
    end
end

--*************** Time and date ***************

--- Current msecs since epoch. Better granularity than Lua builtin.
-- @return Number
function util.gettimeofday()
    C.gettimeofday(g_timeval, nil)
    return ((tonumber(g_timeval.tv_sec) * 1000) +
        math.floor(tonumber(g_timeval.tv_usec) / 1000))
end

--- Create a time string used in HTTP cookies.
-- "Sun, 04-Sep-2033 16:49:21 GMT"
function util.time_format_cookie(epoch)
    g_time_t[0] = epoch
    local tm = C.gmtime(g_time_t)
    local sz = C.strftime(
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
    local tm = C.gmtime(g_time_t)
    local sz = C.strftime(
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
--- Turbo Booyer-Moore memory search algorithm.
-- Search through arbitrary memory and find first occurence of given byte sequence.
-- @param x char* Needle memory pointer
-- @param m int Needle size
-- @param y char* Haystack memory pointer
-- @param n int Haystack size.
function util.TBM(x, m, y, n)
    local bmGs = ffi.new("int[?]", NEEDLE_MAX)
    local bmBc = ffi.new("int[?]", NEEDLE_MAX)
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

-- Fast string case agnostic comparison
function util.strcasecmp(str1, str2)
    local r = 0;
    local b1,b2
    local i
    local len = ((#str1 > #str2) and #str1) or #str2 -- get the longer length

    for i = 1,len do

        b1,b2 = string.byte(str1,i), string.byte(str2,i)
        if b1 == nil then return -1 end
        if b2 == nil then return 1 end

        -- convert b1 and b2 to lower case
        b1 = ((b1 > 0x40) and (b1 < 0x5b) and bit.bor(b1,0x60)) or b1
        b2 = ((b2 > 0x40) and (b2 < 0x5b) and bit.bor(b2,0x60)) or b2
        r = b1 - b2
    end

    return r
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
                q = ffi.cast("char*", C.memchr(s, c, slen))
                if q == nil then
                    break
                end
                if C.memcmp(q + 1, p, plen) == 0 then
                    return q
                end
                q = q + 1
                slen = slen - (q - s)
                s = q
            end
        end
    end
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

----- MIME BASE64 Encoding / Decoding Routines
---------- authored by Jeff Solinsky
do
    local bit = require'bit'
    local rshift = bit.rshift
    local lshift = bit.lshift
    local bor = bit.bor
    local band = bit.band

    -- fastest way to decode mime64 is array lookup
    local mime64chars = ffi.new("uint8_t[64]","ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")
    local mime64lookup = ffi.new("uint8_t[256]")
    ffi.fill(mime64lookup, 256, 0xFF)
    for i=0,63 do
        mime64lookup[mime64chars[i]]=i
    end

    local u8arr= ffi.typeof('uint8_t[?]')

    -- Very Fast Mime Base64 Decoding routine by Jeff Solinsky
    -- takes Mime Base64 encoded input string
    function util.from_base64(d)
        local m64, b1, b2 -- val between 0 and 63, partially decoded byte, decoded byte
        local p = 0 -- position in binary output array
        local boff = 6 -- bit offset, alternates 0, 2, 4, 6
        local bin_arr=ffi.new(u8arr, math.floor(bit.rshift(#d*3,2)))

        for i=1,#d do
            m64 = mime64lookup[d:byte(i)]
            -- skip non-mime characters like newlines
            if m64 ~= 0xFF then
                if boff==6 then
                    b1=lshift(m64, 2)
                    boff=0
                else
                    if boff ~= 4 then
                        b2 = bit.bor(b1,rshift(m64, 4-boff))
                        b1 = lshift(m64,boff+4)
                    else
                        b2 = bor(b1, m64)
                    end
                    bin_arr[p] = b2; p=p+1
                    boff=boff+2
                end
            end
        end
        return ffi.string(bin_arr, p)
    end


    local eq=string.byte('=')
    local htonl = ffi.abi("le") and bit.bswap or bit.tobit
    -- note: we could use a 12-bit lookup table (requiring 8096 bytes)
    --       this should already be fast though using 6-bit lookup
    function util.to_base64(d)
        local outlen = math.floor(#d*4/3)
        outlen = outlen + math.floor(outlen/38)+5
        local m64_arr=ffi.new(u8arr,outlen)
        local l,p,c,v=0,0,0
        local bptr = ffi.cast("uint8_t*",d)
        local bend=bptr+#d
        ::while_3bytes::  -- using a label to be able to jump into the loop
            if bptr+3>bend then
                goto break3
            end
            v = (ffi.cast("int32_t*", bptr))[0]
            v = htonl(v)
            ::encode4:: -- jump here to decode last bytes of the data
            if c==76 then
                m64_arr[p]=0x0D; p=p+1 -- CR
                m64_arr[p]=0x0A; p=p+1 -- LF
                c=0
            end
            m64_arr[p]=mime64chars[rshift(v,26)]; p=p+1
            m64_arr[p]=mime64chars[band(rshift(v,20),63)]; p=p+1
            m64_arr[p]=mime64chars[band(rshift(v,14),63)]; p=p+1
            m64_arr[p]=mime64chars[band(rshift(v,8),63)]; p=p+1
            c=c+4
            bptr=bptr+3
            goto while_3bytes
        ::break3::
      -- l is always 0 the first time this is encountered
      -- this is to add trailing equal signs to encode the end
      -- of the data according ot the MIME base64 specification
      if l>0 then
        -- l will always be 1 or 2 representing the number of remaing
        -- bytes that were encoded
        m64_arr[p-1]=eq;
        -- if only 1 byte of data was left, need to encode a second equal sign
        if l==1 then
          m64_arr[p-2]=eq;
        end
      else
        l=bend-bptr -- get the number of remaining bytes to be encoded
        if l>0 then
          v=0
          for i=1,4 do
            v=lshift(v,8)
            if bptr<bend then
              v=v+bptr[0]
              bptr=bptr+1
            end
          end
          goto encode4
        end
      end
      return ffi.string(m64_arr,p)
    end
end

return util
