--[[
	
	Nonsence Asynchronous event based Lua Web server.
	Author: John Abrahamsen < JhnAbrhmsn@gmail.com >
	
	This module "IOLoop" is a part of the Nonsence Web server.
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

--[[

	Very simple deque implementation in Lua
	
  ]]

assert(require('yacicode'), 
[[Missing required module: Yet Another class Implementation http://lua-users.org/wiki/YetAnotherClassImplementation]])

deque = newclass('Deque')

local insert, remove = table.insert, table.remove

function deque:init()
	self._virtual_queue = {}
end

function deque:append(item)
	self._virtual_queue[#self._virtual_queue + 1] = item
end

function deque:appendleft(item)
	insert(self._virtual_queue, 1, item)
end

function deque:pop()
	local len = #self._virtual_queue
	local pop = self._virtual_queue[len]
	remove(self._virtual_queue, len)
	return pop
end

function deque:popleft()
	local pop = self._virtual_queue[1]
	remove(self._virtual_queue, 1)
	return pop
end

function deque:peeklast()
	return self._virtual_queue[#self._virtual_queue]
end

function deque:peekfirst()
	return self._virtual_queue[1]
end

function deque:getn(k)
	-- Return number.
	if k == -1 then 
		return self:peeklast()
	else
	return self._virtual_queue[k + 1]
	end
end

function deque:size()
	return #self._virtual_queue
end

function deque:not_empty()
	return #self._virtual_queue > 0 and true or false
end

local test = deque:new()
test:append('Left side..')
test:appendleft('New left side...')
print(test:peekfirst())
print(test:getn(0))

