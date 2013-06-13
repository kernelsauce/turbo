local turbo = require "turbo"

local socket = turbo.socket.new_nonblock_socket(turbo.socket.AF_INET, turbo.socket.SOCK_STREAM, 0)
local loop = turbo.ioloop.instance()
local stream = turbo.iostream.IOStream:new(socket)

local parse_headers = function(raw_headers)
	local HTTPHeader = raw_headers
	if HTTPHeader then
		-- Fetch HTTP Method.
		local method, uri = HTTPHeader:match("([%a*%-*]+)%s+(.-)%s")
		-- Fetch all header values by key and value
		local request_header_table = {}	
		for key, value  in HTTPHeader:gmatch("([%a*%-*]+):%s?(.-)[\r?\n]+") do
			request_header_table[key] = value
		end
	return { method = method, uri = uri, extras = request_header_table }
	end
end

function on_body(data)
	assert(data)
	stream:close()
	loop:close()
end

function on_headers(data)
	assert(data)
	local headers = parse_headers(data)
	local length = tonumber(headers.extras['Content-Length'])
	stream:read_bytes(length, on_body)
end

function send_request()
	stream:write("GET / HTTP/1.0\r\nHost: dagbladet.no\r\n\r\n")
	stream:read_until("\r\n\r\n", on_headers)
end

local rc,msg = stream:connect("127.0.0.1", 8888, turbo.socket.AF_INET, send_request)

loop:start()
