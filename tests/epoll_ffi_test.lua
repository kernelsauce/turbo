package.path = package.path.. ";../nonsence/?.lua"  
local log = require('log')
local nixio = require('nixio')
local epoll = require('epoll_ffi')
local dump = log.dump

local test_socket = nixio.socket('inet', 'stream')
test_socket:setblocking(false)
test_socket:bind('*', 8000)
test_socket:listen(2)
local test_fd = test_socket:fileno()

-- Create new epoll and store the returned fd
local epoll_fd = epoll.epoll_create()
-- Add a listener on the test_socket fd for EPOLLIN events
epoll.epoll_ctl(epoll_fd, epoll.EPOLL_CTL_ADD, test_fd, epoll.EPOLL_EVENTS.EPOLLIN)
-- Wait
local events = epoll.epoll_wait(epoll_fd, 10, -1)
-- Dump data
dump(events.data.fd)
dump(events.events)