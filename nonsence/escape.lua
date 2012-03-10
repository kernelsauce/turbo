--[[
	
	Nonsence Asynchronous event based Lua Web server.
	Author: John Abrahamsen < JhnAbrhmsn@gmail.com >
	
	This module "escape" is a part of the Nonsence Web server.
	< https://github.com/JohnAbrahamsen/nonsence-ng/ >
	
	Nonsence is licensed under the MIT license < http://www.opensource.org/licenses/mit-license.php >:

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

local escape = {}
local json = pcall(require, 'json') and require('json') or 
	error('Missing module Lua4JSON')

-- Import JSON module.
escape.json_encode = json.encode
escape.json_decode = json.decode

function escape.unescape(s)
	-- From LuaSocket:
	-- Encodes a string into its escaped hexadecimal representation
	
    return gsub(s, "%%(%x%x)", function(hex)
        return char(tonumber(hex, 16))
    end)
end

function escape.escape(s)
	-- From LuaSocket:
	-- Encodes a string into its escaped hexadecimal representation
	
    return gsub(s, "([^A-Za-z0-9_])", function(c)
        return format("%%%02x", byte(c))
    end)
end

local function make_set(t)
	local s = {}
	for i,v in ipairs(t) do
		s[t[i]] = 1
	end
	return s
end

function escape.protect_segment(s)
	-- From LuaSocket:
	-- Protects a path segment, to prevent it from interfering with the
	
	-- These are allowed withing a path segment, along with alphanum
	-- other characters must be escaped
	local segment_set = make_set {
		"-", "_", ".", "!", "~", "*", "'", "(",
		")", ":", "@", "&", "=", "+", "$", ",",
	}
	return gsub(s, "([^A-Za-z0-9_])", function (c)
		if segment_set[c] then return c
		else return format("%%%02x", byte(c)) end
	end)
end

return escape
