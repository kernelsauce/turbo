--- Turbo.lua Multipart example
--
-- Copyright 2023 Gary Liu
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

local UploadHandler = class("Upload", turbo.web.RequestHandler)

function UploadHandler:post()
    local response = {}
    local form_args = self.request.connection.arguments
    for name, arg_parts in pairs(form_args) do
        for ind, arg in ipairs(arg_parts) do
            local tab = response[name] or {}
            if arg["content-type"] then
                tab[ind] = {
                    ["content-type"] = arg["content-type"],
                    ["content-disposition"] = arg["content-disposition"],
                    ["filepath"] = arg["filepath"],
                    ["filelen"] = arg["filelen"] or #arg[1],
                }
            else
                tab[ind] = arg[1]
            end
            response[name] = tab
        end
    end
    self:write(response)
end

turbo.web.Application({
    {"^/$", UploadHandler}
}):listen(8888, nil, {
streaming_multipart_bytes = 1*1024*1024,
large_body_bytes = 1024,
})
turbo.ioloop.instance():start()
