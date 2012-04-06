--[[
	
		Nonsence Asynchronous event based Lua Web server.
		Author: John Abrahamsen < JhnAbrhmsn@gmail.com >
		
		This module "ansicolors" is a part of the Nonsence Web server.
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

local pairs = pairs
local tostring = tostring
local setmetatable = setmetatable
local schar = string.char

module 'ansicolors'

local colormt = {}

function colormt:__tostring()
    return self.value
end

function colormt:__concat(other)
    return tostring(self) .. tostring(other)
end

function colormt:__call(s)
    return self .. s .. _M.reset
end

colormt.__metatable = {}

local function makecolor(value)
    return setmetatable({ value = schar(27) .. '[' .. tostring(value) .. 'm' }, colormt)
end

local colors = {
    -- attributes
    reset = 0,
    clear = 0,
    bright = 1,
    dim = 2,
    underscore = 4,
    blink = 5,
    reverse = 7,
    hidden = 8,

    -- foreground
    black = 30,
    red = 31,
    green = 32,
    yellow = 33,
    blue = 34,
    magenta = 35,
    cyan = 36,
    white = 37,

    -- background
    onblack = 40,
    onred = 41,
    ongreen = 42,
    onyellow = 43,
    onblue = 44,
    onmagenta = 45,
    oncyan = 46,
    onwhite = 47,
}

for c, v in pairs(colors) do
    _M[c] = makecolor(v)
end
