--[[ Nonsence Unit test

Copyright 2013 John Abrahamsen

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.     ]]

local nonsence = require 'nonsence'


describe("nonsence deque module", function()     
    local d
    it("should be constructed right", function()
       d = nonsence.deque:new()
       assert.truthy(instanceOf(nonsence.deque, d))
    end)
    
    local append_n_elements = 20000
    local string1 = "Some string that should be appended"
    local string2 = "Another string that should be appended"
    
    it("should append correctly", function() 
        for i = 1, append_n_elements, 1 do
                d:append(string1)
        end
        assert.equal(d:size(), append_n_elements)
    end)
    
    it("concat should give correct length", function()
        assert.equal(d:concat():len(), append_n_elements * string1:len())   
    end)
        
    it("should support appendleft", function()
       d:appendleft(string2)
       assert.equal(d:peekfirst(), string2)
    end)
        
    it("should support popleft", function()
        assert.equal(d:popleft(), string2)
        assert.equal(d:popleft(), string1)   
    end)

    it("should support pop", function()
       d:append(string1 .. string2)
       assert.equal(d:pop(), string1 .. string2)
       assert.equal(d:pop(), string1)
    end)
    
    it("must report not empty right", function()
        assert.truthy(d:not_empty())
        while d:not_empty() == true do
            d:pop()
        end
        assert.falsy(d:not_empty())
    end)
    
    it("getn should work correctly", function()
        d:appendleft("pos3")
        d:appendleft("pos2")
        d:appendleft("pos1")
        assert.equal(d:getn(0), "pos1")
        assert.equal(d:getn(1), "pos2")
        assert.equal(d:getn(2), "pos3")
    end)   
end)