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

--- Extends the standard string library with a split method.
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

--- Join a list into a string with  given delimiter. 
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

--- Current msecs since epoch. Better granularity than Lua builtin.
function util.gettimeofday()
  local timeval = ffi.new("struct timeval")
  ffi.C.gettimeofday(timeval, nil)
  return (tonumber(timeval.tv_sec) * 1000) + math.floor(tonumber(timeval.tv_usec) / 1000)
end

local zlib = ffi.load "z"
--- zlib compress.
function util.z_compress(txt)
  local n = zlib.compressBound(#txt)
  local buf = ffi.new("uint8_t[?]", n)
  local buflen = ffi.new("unsigned long[1]", n)
  local res = zlib.compress2(buf, buflen, txt, #txt, 9)
  assert(res == 0)
  return ffi.string(buf, buflen[0])
end

--- zlib decompress.
function util.z_decompress(comp, n)
  local buf = ffi.new("uint8_t[?]", n)
  local buflen = ffi.new("unsigned long[1]", n)
  local res = zlib.uncompress(buf, buflen, comp, #comp)
  assert(res == 0)
  return ffi.string(buf, buflen[0])
end

--- Returns true if value exists in table.
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

local ASIZE = 256
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
            g = i;
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
  local i = 0
  for i = 0, ASIZE do
    bmBc[i] = m
  end
  while i < m - 1 do
    bmBc[x[i]] = m - i - 1;
    i = i + 1
  end
end

local suffix_cache = {}

--- Turbo Booyer-Moore memory search algorithm.
-- @param x char *
-- @param m int
-- @param y char *
-- @param n int
function util.TBM(x, m, y, n)
  local bcShift, i, j, shift, u, v, turboShift 
  local bmGs, bmBc
  m = tonumber(m)
  n = tonumber(n)
  
  local p = ffi.string(x, m)
  if not suffix_cache[p] then
    -- Preprocessing
    bmGs, bmBc = {}, {}
    preBmGs(x, m, bmGs);
    preBmBc(x, m, bmBc);
    suffix_cache[p] = {bmGs, bmBc}
  else
    bmGs, bmBc = suffix_cache[p][1], suffix_cache[p][2]
  end

  -- Searching
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
      --shift = bmGs[0]
      --u = m - shift
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

return util


