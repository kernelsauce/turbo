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


require 'turbo.3rdparty.middleclass'
local log = require "turbo.log"
local ffi = require "ffi"

--[[ Double ended queue class. 	]]
local deque = class('Deque')
_G.deque_no = 0

function deque:initialize()
    self.head = nil
    self.tail = nil
    self.sz = 0
end

--[[ Append elements to tail.  ]]
function deque:append(item)
    if (not self.tail) then
        self.tail = {next = nil, prev = nil, value = item}
        self.head = self.tail
    else
        local new_tail = {next = nil, prev = self.tail, value = item}
        self.tail.next = new_tail
        self.tail = new_tail        
    end
    self.sz = self.sz + 1
end

--[[ Append element to head. 	]]
function deque:appendleft(item)
    if (not self.head) then
        self.head = {next = nil, prev = nil, value = item}
        self.tail = self.head
    else
        local new_head = {next = self.head, prev = nil, value = item}
        self.head.prev = new_head
        self.head = new_head   
    end
    self.sz = self.sz + 1
end

--[[ Removes element at tail and returns it. 	]]
function deque:pop()
    if (not self.tail) then
        return nil
    end
    local value = self.tail.value
    local new_tail = self.tail.prev
    if not new_tail then
        self.tail = nil
        self.head = nil
    else
        self.tail = new_tail
        self.tail.next = nil
    end
    self.sz = self.sz - 1
    return value
end

--[[ Removes element at head and returns it. 	]]
function deque:popleft()
    if (not self.head) then
        return nil
    end
    local value = self.head.value
    local new_head = self.head.next
    if (not new_head) then
        self.head = nil
        self.tail = nil
    else
        new_head.prev = nil
        self.head = new_head        
    end
    self.sz = self.sz - 1
    return value
end

function deque:size() return self.sz end

--[[ Find length of all elements in deque combined.  Slow.]]
function deque:strlen()
    local l = self.head
    if (not l) then
        return 0
    else
        local sz = 0
        while (l) do
            sz = l.value:len() + sz
            l = l.next            
        end
	return sz
    end
end

--[[ Concat all elements in deque.  Slow.]]
function deque:concat()
    local l = self.head
    if (not l) then
        return ""
    else
        local sz = 0
        while (l) do
            sz = l.value:len() + sz
            l = l.next            
        end
        local buf = ffi.new("char[?]", sz)
        l = self.head
        local i = 0
        while (l) do
            local len = l.value:len()
            ffi.copy(buf + i, l.value, len)
            i = i + len
            l = l.next        
        end
        return ffi.string(buf, sz) or ""
    end
end

function deque:getn(pos)
    local l = self.head
    if not l then
        return nil
    end
    while pos ~= 0 do
        l = l.next
        if not l then
            return nil
        end
        pos = pos - 1
    end
    return l.value
end

function deque:__concat(source)
    if (type(self) == "string") then
        self = self .. source:concat()
    end
    return self
end

--[[ To string metamethod.   ]]
function deque:__tostring() return self:concat() end
--[[ Returns element at tail. 	]]
function deque:peeklast() return self.tail.value end
--[[ Returns element at head. 	]]
function deque:peekfirst() return self.head.value end


function deque:not_empty()
    return self.head ~= nil
end

return deque

