--- Turbo.lua Mustache.js fast compiler.
-- Logic-less templates with {{ }}, http://mustache.github.io/
--
-- Copyright 2011, 2012, 2013 John Abrahamsen
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local util = require "turbo.util"
local escape = require "turbo.escape"
local buffer = require "turbo.structs.buffer"
local ffi = require "ffi"
require "turbo.3rdparty.middleclass"

local b = string.byte

local START = 			"{{"
local START_NO_ESC 	= 	"{{{"
local END = 			"}}"
local END_NO_ESC = 		"}}}"
local START_SEC = 		"#"
local END_SEC = 		"/"
local START_INV_SEC = 	"^"

--- Mustache parser states.
local PNONE = 			0x0
local PSTART = 			0x1
local PSTARTNOESC = 	0x2
local PSTARTSEC = 		0x3
local PSTARTSECINV = 	0x4
local PTABLEKEY = 		0x5
local PTABLEKEYNOESC =	0x6
local PEND = 			0x7

--- Template instruction set
local MSTR = 			0x01  	-- Constant string
local TKEY = 			0x02  	-- Table key
local TKEE =			0x22 	-- Table key escape
local SECS =			0x03 	-- Section straight
local SECI =			0x33  	-- Section inverted
local SECE = 			0x05	-- Section end

local Mustache = {}

local function IS_WHITESPACE(char)
	if char == b ' ' or char == b '\t' then 
		return true
	end
end

local function PLAIN_STRING(tbl, ptr, sz)
	tbl[#tbl+1]= {} 
	tbl[#tbl][1] = MSTR
	tbl[#tbl][2] = ffi.string(ptr, sz)
end

local function TABLE_KEY(tbl, key, sz)
	tbl[#tbl+1] = {}
	tbl[#tbl][1] = TKEE
	tbl[#tbl][2] = ffi.string(key, sz)
end

local function TABLE_KEY_NO_ESC(tbl, key, sz)
	tbl[#tbl+1] = {}
	tbl[#tbl][1] = TKEY
	tbl[#tbl][2] = ffi.string(key, sz)
end


local function SECTION(tbl, key, sz)
	tbl[#tbl+1] = {}
	tbl[#tbl][1] = SECS
	tbl[#tbl][2] = ffi.string(key, sz)
end

local function SECTION_INVERTED(tbl, key, sz)
	tbl[#tbl+1] = {}
	tbl[#tbl][1] = SECI
	tbl[#tbl][2] = ffi.string(key, sz)
end

local function SECTION_END(tbl, key, sz)
	tbl[#tbl+1] = {}
	tbl[#tbl][1] = SECE
	tbl[#tbl][2] = ffi.string(key, sz)
end

local function SEARCH(h, hlen, n)
	return util.str_find(h, ffi.cast("char *", n), hlen, n:len())
end

local function CHECK_TABLE_SEC(tbl, key, sz)
	local name = ffi.string(key, sz)
	for i = #tbl, 1, -1 do
		if (tbl[i][1] == SECS or tbl[i][1] == SECI) and 
			tbl[i][2] == name then
			return true
		end
	end
end

function Mustache.compile(template)
	local vmtbl = {}
	local temp = ffi.cast("char*", template)
	local tsz = template:len()
	local consumed = 0
	local state = PNONE
	local mark

	-- Fast forward until mustaches is found.
	::search::
	local loc = SEARCH(temp, tsz - consumed, START)
	if loc ~= nil then
		if loc[2] ~= b '{' then 
			-- No escape mustache {{
			PLAIN_STRING(vmtbl, temp, loc - temp)
			state = PSTART
			consumed = consumed + (loc - temp) + START:len() 
			temp = loc + START:len()
		else
			-- Escape mustache {{{
			PLAIN_STRING(vmtbl, temp, (loc - temp))
			state = PSTARTNOESC
			consumed = consumed + (loc - temp) + START_NO_ESC:len()
			temp = loc + START_NO_ESC:len()			
		end
	else
		-- No mustaches or end of file reached.
		-- Add what is left.
		PLAIN_STRING(vmtbl, temp, tsz - consumed)
		if state ~= PNONE then
			error("Unclosed mustaches in template.")
		end
		goto ret
	end

	while consumed < tsz do
		if IS_WHITESPACE(temp[0]) then 
			if state == PTABLEKEY then
				-- End of table key if whitespace directly after tablekey.
				TABLE_KEY(vmtbl, mark, (temp - mark))
				state = PNONE
			elseif state == PTABLEKEYNOESC then
				TABLE_KEY_NO_ESC(vmtbl, mark, (temp - mark))
				state = PNONE
			elseif state == PSTARTSEC then
				-- End of section keyword.
				-- Keep state until /.
				SECTION(vmtbl, mark, (temp - mark))
				state = PNONE
			end
			-- Whitespace is allowed if state is not above, just skip.
			-- Most probably it is something like {{ name }}

		elseif temp[0] == b '}' and temp[1] == b '}' then 
			-- End of mustache highlight.
			-- Determine escapeness.
			
			if temp[2] == b '}'  then
				if state == PTABLEKEYNOESC then
					-- No escape three mustache case "}}}".
					TABLE_KEY_NO_ESC(vmtbl, mark, (temp - mark))
					state = PNONE
				elseif state == PSTARTSEC then
					-- Basically we do no treat unescaped list {{{#list}}} any
					-- other way than {{#list}}
					SECTION(vmtbl, mark + 1, (temp - mark - 1))	
					-- Skip magic character '#' from name.
					state = PNONE
				elseif state == PEND then 
					-- Check if section end is actually opened somewhere.
					if not CHECK_TABLE_SEC(vmtbl, mark + 1, (temp - mark - 1)) then
						error(string.format(
							"Trying to end section '%s', but it was never opened."),
						ffi.string(mark + 1, (temp - mark - 1)))
					end
					SECTION_END(vmtbl, mark + 1, (temp - mark - 1))
					state = PNONE
				elseif state == PSTARTSECINV then
					SECTION_INVERTED(vmtbl, mark + 1, (temp - mark - 1))
					state = PNONE
				end
				temp = temp + 3
				consumed = consumed + 3

			else
				if state == PTABLEKEY then 
					TABLE_KEY(vmtbl, mark, (temp - mark))
					state = PNONE
				elseif state == PSTARTSEC then
					SECTION(vmtbl, mark + 1, (temp - mark - 1))	
					state = PNONE
				elseif state == PEND then
					if not CHECK_TABLE_SEC(vmtbl, mark + 1, (temp - mark - 1)) then
						error(string.format(
							"Trying to end section '%s', but it was never opened.",
						ffi.string(mark + 1, (temp - mark - 1))))
					end
					SECTION_END(vmtbl, mark + 1, (temp - mark - 1))
					state = PNONE
				elseif state == PSTARTSECINV then
					SECTION_INVERTED(vmtbl, mark + 1, (temp - mark - 1))
					state = PNONE
				end
				temp = temp + 2
				consumed = consumed + 2
			end
			goto search

		elseif state == PSTART  or state == PSTARTNOESC then 
			-- Essentially next char is either first char of key or it is 
			-- a section char "#". If a match is found a mark is placed.
			if temp[0] == b(START_SEC) then
				mark = temp
				state = PSTARTSEC
			elseif temp[0] == b(START_INV_SEC) then
				mark = temp
				state = PSTARTSECINV	
			elseif temp[0] == b(END_SEC) then
				mark = temp
				state = PEND	
			else
				-- No prefix, must be a table key.
				mark = temp
				if state == PSTART then
					state = PTABLEKEY
				elseif state == PSTARTNOESC then
					state = PTABLEKEYNOESC
				end
			end	

		end
		consumed = consumed + 1
		temp = temp + 1
	end
	::ret::
	return vmtbl
end

local function _compile_template(vmtbl, obj)
	local buf = buffer(1024)
	local i = 1
	local vmtbl_sz = #vmtbl
	while 1 do
		::start::
		if i == vmtbl_sz + 1 then
			break
		end
		local instr = vmtbl[i][1]
		local arg = vmtbl[i][2]
		local sec
		if instr == MSTR then
			buf:append_luastr_right(arg)
		elseif instr == TKEE then
			if obj[arg] then
				if type(obj[arg]) == "string" then
					local esc = escape.escape(obj[arg])
					buf:append_luastr_right(esc)
				elseif type(obj[arg]) == "number" then
					buf:append_luastr_right(tostring(obj[arg]))
				end
			end
		elseif instr == TKEY then
			if obj[arg] then
				if type(obj[arg]) == "string" then
					buf:append_luastr_right(obj[arg])
				end
			end
		elseif instr == SECS then
			if obj[arg] then
				if type(obj[arg]) == "table" and #obj[arg] ~= 0 then
					sec = obj[arg]
				end
			else
				-- Section is purely used as a conditional thing.
				-- Just fast-forward until SECE is found.
				while 1 do 
					i = i + 1
					if vmtbl[i][1] == SECE then
						goto start
					end
				end
			end
		elseif instr == SECI then
			-- TODO

		end
		i = i + 1
	end
	return tostring(buf)
end

function Mustache.render(template, obj)
	if not template then
		error("No precompiled template or template string passed to Mustache.render.")
	end
	if type(template) == "string" then
		template = Mustache.compile(template)
	elseif type(template) ~= "table" then
		error("Invalid template passed to Mustache.render")
	end
	if type(obj) ~= "table" then
		error("No table passed to Mustache.render")
	end
	return _compile_template(template, obj)
end

function Mustache._template_dump(tbl)
	local vmcode = {
		[0x1] = 	"MSTR",
		[0x2] = 	"TKEY",
		[0x22] = 	"TKEE",
		[0x3] = 	"SECS",
		[0x33] = 	"SECI",
		[0x05] = 	"SECE"
	}
	print("  Mustache parse tree dump\n  ====================================")
	for i = 1, #tbl do
		if tbl[i][1] == SECS or tbl[i][1] == SECI or 
			tbl[i][1] == SECE then
			print(
				string.format("  %d\x1b[32m %s => \x1b[37m %s", 
					i,
					vmcode[tbl[i][1]], 
					tbl[i][2]:gsub("[\n\t]+", "")))
		elseif tbl[i][1] == TKEY or tbl[i][1] == TKEE then
			print(
				string.format("  %d\x1b[32m %s => \x1b[37m %s", 
					i,
					vmcode[tbl[i][1]], 
					tbl[i][2]:gsub("[\n\t]+", "")))
		else
			print(
				string.format("  %d\x1b[36m %s => \x1b[37m '%s'", 
					i,
					vmcode[tbl[i][1]], 
					tbl[i][2]:gsub("[\n\t]+", "")))
		end
	end
	print("  ====================================\n")
end

return Mustache