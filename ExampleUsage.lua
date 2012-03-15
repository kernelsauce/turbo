--[[
	
	Nonsence Asynchronous event based Lua Web server.
	Author: John Abrahamsen < JhnAbrhmsn@gmail.com >
	
	https://github.com/JohnAbrahamsen/nonsence-ng/
	
	Many of the modules in the software package are derivatives of the 
	Tornado web server. Tornado is also licensed under Apache 2.0 license.
	For more details on Tornado please see:
	
	http://www.tornadoweb.org/
	
	
	Copyright 2011 John Abrahamsen

	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.


			.;''-.
		      .' |    `._
		     /`  ;       `'.
		   .'     \         \
		  ,'\|    `|         |
		  | -'_     \ `'.__,J
		 ;'   `.     `'.__.'
		 |      `"-.___ ,'
		 '-,           /
		 |.-`-.______-|
		 }      __.--'L
		 ;   _,-  _.-"`\         ___
		 `7-;"   '  _,,--._  ,-'`__ `.
		  |/      ,'-     .7'.-"--.7 |        _.-'
		  ;     ,'      .' .'  .-. \/       .'
		   ;   /       / .'.-     ` |__   .'
		    \ |      .' /  |    \_)-   `'/   _.-'``
		     _,.--../ .'     \_) '`_      \'`
		   '`f-'``'.`\;;'    ''`  '-`      |
		      \`.__. ;;;,   )              /
		       `-._,|;;;,, /\            ,'
			/ /<_;;;;'   `-._    _,-'
		       | '- /;;;;;,      `t'` \. I like nonsence.
		       `'-'`_.|,';;;,      '._/| It wakes up the brain cells!
		       ,_.-'  \ |;;;;;    `-._/
			     / `;\ |;;;,  `"     - Theodor Seuss Geisel -
			   .'     `'`\;;, /
			  '           ;;;'|
			      .--.    ;.:`\    _.--,
			     |    `'./;' _ '_.'     |
			      \_     `"7f `)       /
			      |`   _.-'`t-'`"-.,__.'
			      `'-'`/;;  | |   \ mx
				  ;;;  ,' |    `
				      /   '

	
]]--

local nonsence = require('nonsence') -- Require nonsence.

--
-- Create new Handler with heritage from RequestHandler
--
local ExampleHandler = nonsence.web.RequestHandler:new() 
function ExampleHandler:get(id) -- Handler for GET method requests.
	self:write( { Result = self:get_arguments() } )
end
function ExampleHandler:post() -- Handler for POST method requests.
	self:write('Hello another world!')
end

--
-- Create new Handler with heritage from RequestHandler
--
local ItemHandler = nonsence.web.RequestHandler:new() 
function ItemHandler:get() -- Handler for GET method requests.
	self:write( { Result = self:get_arguments() } )
end

--
-- Create a new application with your RequestHandler as parameter.
-- 
local application = nonsence.web.Application:new({ 
	['/'] = ExampleHandler,
	['/item/([0-9]+)/([0-9]+)'] = ItemHandler
})

--
-- Tell the application to listen to defined port.
--
application:listen(8888)

--
-- Start the endless IO loop.
--
nonsence.ioloop.start()
