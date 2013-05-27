--[[ Turbo Async HTTP client example

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

local turbo = require "turbo"
local httpclient = turbo.async.HTTPClient:new()
local TwitterFeedHandler = class("TwitterFeed", turbo.web.RequestHandler)

function TwitterFeedHandler:get()
	local httpresponse, err = coroutine.yield(httpclient:fetch("http://search.twitter.com/search.json", {
		method = "GET",
		params = "q=Twitter&result_type=mixed"
	}))
	
	if (err ~= nil) then
		error(turbo.web.HTTPError:new(500, "Could not download from twitter.com"))
	end
	
	local headers = httpresponse:get_reponse_headers()
	if headers:get_status_code() == 200 then
		local res = turbo.escape.json_decode(httpresponse:get_data())
		local top_search_result = res.results[1]
		local text = top_search_result.text
		local pic = top_search_result.profile_image_url
		self:write(string.format([[
			<h1>Search for Twitter on Twitter gave this tweet:</h1>
			<img src="%s">
			<p>%s</p>
		]], pic, text))
	else
		error(turbo.web.HTTPError:new(headers:get_status_code(), "Something bad happened!"))
	end
end

local application = turbo.web.Application:new({
	{"/tweet$", TwitterFeedHandler}
})

application:listen(8888)
turbo.ioloop.instance():start()