--[[ Double ended queue for Lua

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


require('middleclass')

--[[ Double ended queue class. 	]]
local deque = class('Deque')


function deque:init()
	self._virtual_queue = {}
end

--[[ Append elements to tail.  ]]
function deque:append(item) self._virtual_queue[#self._virtual_queue + 1] = item end
--[[ Append element to head. 	]]
function deque:appendleft(item) table.insert(self._virtual_queue, 1, item) end

--[[ Removes element at tail and returns it. 	]]
function deque:pop()
	local len = #self._virtual_queue
	local pop = self._virtual_queue[len]
	self._virtual_queue[len] = nil
	return pop
end

--[[ Removes element at head and returns it. 	]]
function deque:popleft()
	local pop = self._virtual_queue[1]
	table.remove(self._virtual_queue, 1)
	return pop
end

--[[ Returns element at tail. 	]]
function deque:peeklast() return self._virtual_queue[#self._virtual_queue] end
--[[ Returns element at head. 	]]
function deque:peekfirst() return self._virtual_queue[1] end

--[[ Returns element at position n. 	]]
function deque:getn(k)
	if k == -1 then 
		return self:peeklast()
	else
	return self._virtual_queue[k + 1]
	end
end

--[[ Returns size of deque. 	]]
function deque:size() return #self._virtual_queue or 0 end
--[[ Is deque empty or not?   ]]
function deque:not_empty() return #self._virtual_queue > 0 and true or false end

--[[ Concat all elements. 	]]
function deque:concat() return table.concat(self._virtual_queue) or '' end

return deque
