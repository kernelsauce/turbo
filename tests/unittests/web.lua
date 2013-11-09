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
turbo.log.categories.success = false -- turn of logging.

describe("turbo.web Namespace", function()

	before_each(function() 
		-- Make sure we start with a fresh global IOLoop to
		-- avoid random results.
		_G.io_loop_instance = nil 
	end)

	describe("Application and RequestHandler classes", function()
		-- Most of tests here use the turbo.async.HTTPClient, so any errors
		-- in that will also show in these tests...
		it("Accept hello world.", function() 
			local port = math.random(10000,40000)
			local io = turbo.ioloop.instance()
			local ExampleHandler = class("ExampleHandler", turbo.web.RequestHandler)
			function ExampleHandler:get()
				self:write("Hello World!")
			end
			turbo.web.Application({{"^/$", ExampleHandler}}):listen(port)

			io:add_callback(function() 
				local res = coroutine.yield(turbo.async.HTTPClient():fetch(
					"http://127.0.0.1:"..tostring(port).."/"))
				assert.falsy(res.error)
				assert.equal(res.body, "Hello World!")
				io:close()
			end)
			
			io:wait(5)
		end)

		it("Accept URL parameters", function()
			local port = math.random(10000,40000)
			local param = math.random(1000,10000)
			local io = turbo.ioloop.instance()
			local ExampleHandler = class("ExampleHandler", turbo.web.RequestHandler)
			function ExampleHandler:get(int, str)
				assert.equal(tonumber(int), param)
				assert.equal("testitem", str)
				self:write(int)
			end
			turbo.web.Application({
				{"^/(%d*)/(%a*)$", ExampleHandler}
			}):listen(port)

			io:add_callback(function() 
				local res = coroutine.yield(turbo.async.HTTPClient():fetch(
					"http://127.0.0.1:"..tostring(port).."/"..tostring(param).."/testitem"))
				assert.falsy(res.error)
				assert.equal(param, tonumber(res.body))
				io:close()
			end)
			
			io:wait(5)
		end)

		it("Accept GET parameters", function() 
			local port = math.random(10000,40000)
			local io = turbo.ioloop.instance()
			local ExampleHandler = class("ExampleHandler", turbo.web.RequestHandler)
			function ExampleHandler:get()
				assert.equal(self:get_argument("item1"), "Hello")
				assert.equal(self:get_argument("item2"), "World")
				assert.equal(self:get_argument("item3"), "!")
				assert.equal(self:get_argument("item4"), "StrangeØÆØÅØLÆLØÆL@½$@£$½]@£}½")
				self:write("Hello World!")
			end
			turbo.web.Application({{"^/$", ExampleHandler}}):listen(port)

			io:add_callback(function() 
				local res = coroutine.yield(turbo.async.HTTPClient():fetch(
					"http://127.0.0.1:"..tostring(port).."/",
					{
						params={
							item1="Hello",
							item2="World",
							item3="!",
							item4="StrangeØÆØÅØLÆLØÆL@½$@£$½]@£}½"
						}
					}))
				assert.falsy(res.error)
				assert.equal(res.body, "Hello World!")
				io:close()
			end)
			
			io:wait(5)
		end)

		it("Accept POST multipart", function() 
			local port = math.random(10000,40000)
			local io = turbo.ioloop.instance()
			local ExampleHandler = class("ExampleHandler", turbo.web.RequestHandler)
			function ExampleHandler:post()
				assert.equal(self:get_argument("item1"), "Hello")
				assert.equal(self:get_argument("item2"), "World")
				assert.equal(self:get_argument("item3"), "!")
				assert.equal(self:get_argument("item4"), "StrangeØÆØÅØLÆLØÆL@½$@£$½]@£}½")
				self:write("Hello World!")
			end
			turbo.web.Application({{"^/$", ExampleHandler}}):listen(port)

			io:add_callback(function() 
				local res = coroutine.yield(turbo.async.HTTPClient():fetch(
					"http://127.0.0.1:"..tostring(port).."/",
					{
						method="POST",
						params={
							item1="Hello",
							item2="World",
							item3="!",
							item4="StrangeØÆØÅØLÆLØÆL@½$@£$½]@£}½"
						}
					}))
				assert.falsy(res.error)
				assert.equal(res.body, "Hello World!")
				io:close()
			end)
			
			io:wait(5)
		end)


	end)

end)