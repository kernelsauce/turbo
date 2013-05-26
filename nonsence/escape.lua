--[[ Nonsence Escape module

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

local json = require('JSON')
local escape = {} -- escape namespace


--[[ JSON stringify a table.   ]]
function escape.json_encode(lua_table_or_value) return json:encode(lua_table_or_value) end
--[[ Decode a JSON string to table.  ]]
function escape.json_decode(json_string_literal) return json:decode(json_string_literal) end

--[[ Unescape a escaped hexadecimal representation string.  ]]
function escape.unescape(s)
    return string.gsub(s, "%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
end

--[[ Encodes a string into its escaped hexadecimal representation.   ]]
function escape.escape(s)
    return gsub(s, "([^A-Za-z0-9_])", function(c)
        return string.format("%%%02x", string.byte(c))
    end)
end


local function make_set(t)
	local s = {}
	for i,v in ipairs(t) do
		s[t[i]] = 1
	end
	return s
end
--[[ These are allowed withing a path segment, along with alphanum
other characters must be escaped.      ]]
function escape.protect_segment(s)

	local segment_set = make_set {
		"-", "_", ".", "!", "~", "*", "'", "(",
		")", ":", "@", "&", "=", "+", "$", ",",
	}
	return gsub(s, "([^A-Za-z0-9_])", function (c)
		if segment_set[c] then return c
		else return string.format("%%%02x", string.byte(c)) end
	end)
end

return escape
