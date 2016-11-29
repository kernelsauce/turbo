--- Turbo.lua Unit test
--
-- Copyright 2013 John Abrahamsen
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


local turbo = require "turbo"
math.randomseed(turbo.util.gettimeofday())

describe("turbo.structs Namespace", function()

    describe("Buffer class", function()
        it("should be constructed right", function()
            local buf = turbo.structs.buffer()
            assert.truthy(instanceOf(turbo.structs.buffer, buf))
        end)
        it("should append correctly", function()
            local buf = turbo.structs.buffer()
            buf:append_luastr_right("Long string")
            buf:append_luastr_right(" that is expected to")
            buf:append_luastr_right(" equal a constant")
            assert.equal(tostring(buf), "Long string that is expected to equal a constant")
        end)
        it("should prepend correctly", function()
            local buf = turbo.structs.buffer()
            buf:append_luastr_left(" equal a constant")
            buf:append_luastr_left(" that is expected to")
            buf:append_luastr_left("Long string")
            assert.equal(tostring(buf), "Long string that is expected to equal a constant")
        end)
        it("should handle mixed append/prepend", function()
            local buf = turbo.structs.buffer()
            local cmp = ""
            for i = 0, 300 do
                local dice = math.random() * 10
                if dice > 5 then
                    cmp = tostring(dice) .. cmp
                    buf:append_luastr_left(tostring(dice))
                else
                    cmp = cmp .. tostring(dice)
                    buf:append_luastr_right(tostring(dice))
                end
            end
            assert.equal(cmp, tostring(buf))
            assert.equal(cmp:len(), buf:len())
        end)
        it("should support == operator", function()
            local buf = turbo.structs.buffer()
            buf:append_luastr_right("two equal string should equal!")
            local buf2 = turbo.structs.buffer()
            buf2:append_luastr_right("two equal string should equal!")
            assert.truthy(buf == buf2)
            buf2:clear()
            assert.truthy(buf ~= buf2)
        end)
        it("should pop correctly", function()
            local buf = turbo.structs.buffer()
            for i = 1, 10000 do
                buf:append_luastr_right("much data in here")
            end
            buf:pop_right(string.len("much data in here") * 10000)
            assert.equal(buf:len(), 0)
            for i = 1, 10000 do
                buf:append_luastr_left("much data in here")
            end
            assert.has_error(function()
                buf:pop_right(string.len("much data in here") * 10001)
            end)
            buf:shrink()
            while buf:len() ~= 0 do
                buf:pop_left(1)
            end
            assert.equal(tostring(buf), "")
            buf:clear()
        end)
        it("should support method chaining", function()
            local buf = turbo.structs.buffer()
            buf:append_luastr_left("test"):append_luastr_left("test")
            assert.equal(tostring(buf), "testtest")
        end)
    end)

    describe("Deque class", function()
        local d
        it("should be constructed right", function()
           d = turbo.structs.deque:new()
           assert.truthy(instanceOf(turbo.structs.deque, d))
        end)

        local append_n_elements = 200
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

        it("should behave logically", function()
            local q = turbo.structs.deque:new()
            local str = ""
            local n = 0

            for i=0, 1000 do
                math.randomseed(os.time() + i)
                local action = math.random(0,4)
                if (action == 0) then
                    q:append("a dog")
                    n = n + 1
                elseif (action == 1) then
                    q:appendleft("a cat")
                    n = n + 1
                elseif (action == 2) then
                    if (q:not_empty()) then
                        q:popleft()
                        n = n - 1
                    else
                        assert.equal(nil, q:popleft())
                    end
                elseif (action == 3) then
                    if (q:not_empty()) then
                        q:pop()
                        n = n - 1
                    else
                        assert.equal(nil, q:pop())
                    end
                elseif (action == 4) then
                    assert.equal(q:size(), n)
                end
            end
        end)
    end)

end)
