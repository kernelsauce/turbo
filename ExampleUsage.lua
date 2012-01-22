--[[

	"Nonsence" Lua web server
	Author: John Abrahamsen (jhnabrhmsn@gmail.com).
	License: MIT.

	The ultra fast cached web server written in Lua.


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

	Purpose: To show noobs how to use this web server.
	
]]--

local nonsence = require('nonsence') -- Require nonsence.

--
-- Create new Handler with heritage from RequestHandler
--
local ExampleHandler = nonsence.web.RequestHandler:new() 
function ExampleHandler:get(id) -- Handler for GET method requests.
	dump(id)
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
