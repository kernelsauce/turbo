--[[ Nonsence IOStream Unit test

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


describe("nonsence iostream module", function()     
    it("_double_prefix should work", function()
       local d = nonsence.deque:new()
       assert.truthy(instanceOf(nonsence.deque, d))
       
       d:append("a")
       d:append("b")
       d:append("c")
       d:append("word")
       d:append("long long word")
       nonsence.iostream._merge_prefix(d, 4)
       assert.equal(d:popleft(), "abcw")
       nonsence.iostream._merge_prefix(d, 3)
       assert.equal(d:popleft(), "ord")
       nonsence.iostream._merge_prefix(d, 14)
       assert.equal(d:popleft(), "long long word")
       assert.equal(d:not_empty(), false)
    end)
    
end)