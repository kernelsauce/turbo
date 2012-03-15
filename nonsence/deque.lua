--[[
	
	Nonsence Asynchronous event based Lua Web server.
	Author: John Abrahamsen < JhnAbrhmsn@gmail.com >
	
	This module "deque" is a part of the Nonsence Web server.
	For the complete stack hereby called "software package" please see:
	
	https://github.com/JohnAbrahamsen/nonsence-ng/
	
	Many of the modules in the software package are derivatives of the 
	Tornado web server. Tornado is licensed under Apache 2.0 license.
	For more details on Tornado please see:
	
	http://www.tornadoweb.org/
	
	However, this module, deque is not a derivate of Tornado and are
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

--[[

	Very simple deque implementation in Lua
	Needs work! :)
	
  ]]

assert(require('middleclass'), 
	[[Missing required module: MiddleClass 
	https://github.com/kikito/middleclass]])

local deque = class('Deque')

local insert, remove, concat = table.insert, table.remove, table.concat

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
	self._virtual_queue[len] = nil
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
	return #self._virtual_queue or 0
end

function deque:not_empty()
	return #self._virtual_queue > 0 and true or false
end

function deque:concat()
	return concat(self._virtual_queue)
end

return deque
