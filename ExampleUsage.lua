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

	
  ]]

package.path = package.path .. ";./nonsence/?.lua" -- Put base dir in path.
local nonsence = require('nonsence')

--[[
	
	Create new Handler with heritage from RequestHandler
  
  ]]
local ExampleHandler = class("ExampleHandler", nonsence.web.RequestHandler)
function ExampleHandler:get(id) -- Handler for GET method requests.
	self:write('Hello another world!')
end
function ExampleHandler:post() -- Handler for POST method requests.
	self:write('Hello another world!')
end

--[[
	
	Create a new application with your RequestHandler as parameter.
	
  ]]
local application = nonsence.web.Application:new({ 
	['/test'] = ExampleHandler
})

--[[

	Listen to port 8888
	and initiate the global ioloop.

  ]]
application:listen(8888)

nonsence.ioloop.instance():start()
