--- Turbo.lua Escape module
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

local json = require('turbo.3rdparty.JSON')

local escape = {} -- escape namespace

--- JSON stringify a table.
-- @param lua_table_or_value Value to JSON encode.
-- @note May raise a error if table could not be decoded.
function escape.json_encode(lua_table_or_value)
    return json:encode(lua_table_or_value)
end

--- Decode a JSON string to table.
-- @param json_string_literal (String) JSON enoded string to decode into
-- Lua primitives.
-- @return (Table)
function escape.json_decode(json_string_literal)
    return json:decode(json_string_literal)
end

local function _unhex(hex) return string.char(tonumber(hex, 16)) end
--- Unescape a escaped hexadecimal representation string.
-- @param s (String) String to unescape.
function escape.unescape(s)
    return string.gsub(s, "%%(%x%x)", _unhex)
end

local function _hex(c)
    return string.format("%%%02x", string.byte(c))
end
--- Encodes a string into its escaped hexadecimal representation.
-- @param s (String) String to escape.
function escape.escape(s)
    return string.gsub(s, "([^A-Za-z0-9_])", _hex)
end

-- Remove trailing and leading whitespace from string.
-- @param s String
function escape.trim(s)
    -- from PiL2 20.4
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- Remove leading whitespace from string.
-- @param s String
function escape.ltrim(s)
    return (s:gsub("^%s*", ""))
end

-- Remove trailing whitespace from string.
-- @param s String
function escape.rtrim(s)
    local n = #s
    while n > 0 and s:find("^%s", n) do n = n - 1 end
    return s:sub(1, n)
end

----- Very Fast MIME BASE64 Encoding / Decoding Routines
--------------- authored by Jeff Solinsky
do
    local bit = require'bit'
    local rshift = bit.rshift
    local lshift = bit.lshift
    local bor = bit.bor
    local band = bit.band
    local floor = math.floor
    local ffi = require"ffi"

    local mime64chars = ffi.new("uint8_t[64]",
     "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")
    local mime64lookup = ffi.new("uint8_t[256]")
    ffi.fill(mime64lookup, 256, 0xFF)
    for i=0,63 do
        mime64lookup[mime64chars[i]]=i
    end

    local u8arr= ffi.typeof'uint8_t[?]'
    local u16ptr=ffi.typeof'uint16_t*'
    local u8ptr=ffi.typeof'uint8_t*'

    --- Base64 decode a string or a FFI char *.
    -- @param str (String or char*) Bytearray to decode.
    -- @param sz (Number) Length of string to decode, optional if str is a Lua string
    -- @return (String) Decoded string.
    function escape.base64_decode(str, sz)
        if (type(str)=="string") and (sz == nil) then sz=#str end
        local m64, b1, b2 -- value 0 and 63, partial byte, decoded byte
        local p = 0 -- position in binary output array
        local boff = 6 -- bit offset, alternates 0, 2, 4, 6
        local bin_arr=ffi.new(u8arr, floor(bit.rshift(sz*3,2)))
        local bptr = ffi.cast(u8ptr,str)

        for i=0,sz-1 do
            m64 = mime64lookup[bptr[i]]
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

    local mime64shorts=ffi.new('uint16_t[4096]')
    for i=0,63 do
        for j=0,63 do
            local v
            if ffi.abi("le") then
                v=mime64chars[j]*256+mime64chars[i]
            else
                v=mime64chars[i]*256+mime64chars[j]
            end
            mime64shorts[i*64+j]=v
        end
    end

    local eq=string.byte('=')
    --- Base64 encode binary data of a string or a FFI char *.
    -- @param str (String or char*) Bytearray to encode.
    -- @param sz (Number) Length of string to encode, optional if str is a Lua string
    -- @return (String) Encoded base64 string.
    function escape.base64_encode(str, sz)
        if (type(str)=="string") and (sz == nil) then sz=#str end
        local outlen = floor(sz*4/3)
        outlen = outlen + floor(outlen/38)+5
        local m64_arr=ffi.new(u8arr,outlen)
        local m64wptr
        local l,p,c,v=0,0,76
        local bptr = ffi.cast(u8ptr,str)
        local bend=bptr+sz
        ::while_3bytes::
            if bptr+3>bend then goto break3 end
            v = bor(lshift(bptr[0],16),lshift(bptr[1],8),bptr[2])
            ::encode_last3::
            if p==c then
                m64_arr[p]=0x0D; p=p+1 -- CR
                m64_arr[p]=0x0A; p=p+1 -- LF
                c=p+76
            end
            m64wptr = ffi.cast(u16ptr,m64_arr+p)
            m64wptr[0]=mime64shorts[rshift(v,12)];
            m64wptr[1]=mime64shorts[band(v,4095)];
            p=p+4
            bptr=bptr+3
            goto while_3bytes
        ::break3::
        if l>0 then
            m64_arr[p-1]=eq -- Add trailing equal sign padding
            -- 1 byte encoded needs second trailing equal sign sign
            if l==1 then m64_arr[p-2]=eq end
        else
            l=bend-bptr -- get remaining len (1 or 2 bytes)
            if l>0 then
                v= lshift(bptr[0],16)
                if l==2 then v=bor(v,lshift(bptr[1],8)) end
                goto encode_last3
            end
        end
        return ffi.string(m64_arr,p)
    end
end

return escape
