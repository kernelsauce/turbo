--[[
	
	http://www.opensource.org/licenses/mit-license.php

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

package.path = package.path.. ";../nonsence/?.lua"  

-------------------------------------------------------------------------
--
-- Load modules
--
local deque = assert(require('deque'), 
	[[Missing required module: deque]])
-------------------------------------------------------------------------

local d = deque:new()
local append_n_elements = 20000
local string1 = "Some string that should be appended"
local string2 = "Another string that should be appended"

-- Append n elements to end of deque.
for i = 1, append_n_elements, 1 do
	d:append(string1)
end

-- Count the amount elements.
assert(d:size() == append_n_elements, "Wrong amount of elements in deque")

-- Check if concat function gives right length on return.
assert(d:concat():len() == append_n_elements * string1:len(), "Wrong concat length")

-- Test the appendleft method
d:appendleft(string2)

-- Test the peekleft method
assert(d:peekfirst() == string2, "peekleft method returned wrong value")

-- Test the popleft method
assert(d:popleft() == string2, "popleft method return wrong value")
assert(d:popleft() == string1, "popleft did not remove the value from queue")

-- Test the pop method
d:append(string1 .. string2)
assert(d:pop() == string1 .. string2, "pop not working right.")

-- Test the pop method again
assert(d:pop() == string1, "pop not working right")

-- Test not_empty method
assert(d:not_empty() == true, "not_empty method returning wrong boolean, should be true")

-- Pop all values of the queue.
while d:not_empty() == true do
	d:pop()
end

-- Test not_empty method again
assert(d:not_empty() == false, "not_empty method returning wrong boolean, should be false")

-- Another appendleft n elements.
for i = 1, append_n_elements, 1 do
	d:appendleft(string1)
	d:append(string2)
end

-- Pop all values of the queue.
while d:not_empty() == true do
	d:popleft()
end
