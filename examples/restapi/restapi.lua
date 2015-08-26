-- turbo.lua REST API example with enabled CORS
local turbo = require("turbo")

-- http://localhost:8888/api
local api = class("api", turbo.web.RequestHandler)

  -- see sendJson.html
  -- or e.g. in python3.4
  -- import json, requests
  -- >>> requests.post('http://localhost:8888/api', json.dumps({'Hello': 'Json'}))
  -- <Response [200]>
  function api:post()
    self:add_header('Access-Control-Allow-Origin','*')
    local json = self:get_json(true)
    for key,value in pairs(json) do print(key,value) end -- output in terminal!
  end
  
  -- see receiveJson.html
  -- or e.g. in python3.4
  -- import json, requests
  -- >>> requests.get('http://localhost:8888/api').content
  -- b'{"hello":"json"}'
  function api:get()
    self:add_header('Access-Control-Allow-Origin','*')
    self:write({hello="json"}) -- return json in browser
  end
  
  -- CORS preflight request
  function api:options()
    self:add_header('Access-Control-Allow-Methods', 'POST')
    self:add_header('Access-Control-Allow-Headers', 'content-type')
    self:add_header('Access-Control-Allow-Origin', '*')
  end
  
  
turbo.web.Application({
    {"/api", api}
}):listen(8888)
turbo.ioloop.instance():start()