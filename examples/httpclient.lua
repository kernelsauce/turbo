--[[ Nonsence Async HTTP client example

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

_G.NW_CONSOLE = 1
local nonsence = require "nonsence"

local TwitterFeedHandler = class("TwitterFeed", nonsence.web.RequestHandler)

function TwitterFeedHandler:get(path)
    self:set_auto_finish(false)
    nonsence.async.HTTPClient:new():fetch("http://search.twitter.com/search.json?q=Twitter&result_type=mixed",
	"GET",
	function(headers, data)
		if headers:get_status_code() == 200 then
		     local res = nonsence.escape.json_decode(data)
		     local top_search_result = res.results[1]
		     local text = top_search_result.text
		     local pic = top_search_result.profile_image_url
		     self:write(string.format([[
			<h1>Search for Twitter on Twitter gave this tweet:</h1>
			<img src="%s">
			<p>%s</p>
		     ]], pic, text))
		else
		     error(nonsence.web.HTTPError(500), "Twitter did not respond with 200?!")
		end
		self:finish()
	end, function(err)
		-- Could not connect?
		error(nonsence.web.HTTPError(500), "Could not load data from Twitter API")
	end)
end
 
local application = nonsence.web.Application:new({
	{"(.+)", TwitterFeedHandler}
})

application:listen(8888)
nonsence.ioloop.instance():start()