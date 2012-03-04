--[[
	
	Epoll bindings through the LuaJIT FFI Library
	Author: John Abrahamsen < JhnAbrhmsn@gmail.com >
	
	This module "epoll_ffi" is a part of the Nonsence Web server.
	< https://github.com/JohnAbrahamsen/nonsence-ng/ >
	
	Nonsence is licensed under the MIT license < http://www.opensource.org/licenses/mit-license.php >:

	"Permission is hereby granted, free of charge, to any person obtaining a copy of
	this software and associated documentation files (the "Software"), to deal in
	the Software without restriction, including without limitation the rights to
	use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
	of the Software, and to permit persons to whom the Software is furnished to do
	so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE."

	
  ]]

-------------------------------------------------------------------------
-- Load modules
local ffi = require("ffi")
local log = require("log")
-------------------------------------------------------------------------
-- Table to be returned
local epoll = {}
-------------------------------------------------------------------------
-- Epoll defines from epoll.h
--
MAX_EVENTS = 2000
epoll.EPOLL_CTL_ADD = 1 --	/* Add a file decriptor to the interface */
epoll.EPOLL_CTL_DEL = 2 --	/* Remove a file decriptor from the interface */
epoll.EPOLL_CTL_MOD = 3 --	/* Change file decriptor epoll_event structure */
epoll.EPOLL_EVENTS = {
	['EPOLLIN']  = 0x001,
	['EPOLLPRI'] = 0x002,
	['EPOLLOUT'] = 0x004,
	['EPOLLERR'] = 0x008,
	['EPOLLHUP'] = 0x0010,
}
-------------------------------------------------------------------------

-------------------------------------------------------------------------	
-- C defs.
ffi.cdef[[

	typedef union epoll_data {
		void        *ptr;
		int          fd;
		uint32_t     u32;
		uint64_t     u64;
	} epoll_data_t;

	struct epoll_event {
		uint32_t     events;      /* Epoll events */
		epoll_data_t data;        /* User data variable */
	} __attribute__ ((__packed__));

	typedef struct epoll_event epoll_event;

	int epoll_create(int size);
	int epoll_ctl(int epfd, int op, int fd, struct epoll_event* event);
	int epoll_wait(int epfd, struct epoll_event *events, int maxevents, int timeout);
	
]]
-------------------------------------------------------------------------

function epoll.epoll_create()
	local epfd = ffi.C.epoll_create(MAX_EVENTS)
	return epfd
end

function epoll.epoll_ctl(epfd, op, fd, epoll_events)
	local events = ffi.new("epoll_event", epoll_events)
	events.data.fd = fd
	local rc = ffi.C.epoll_ctl(epfd, op, fd, events)
	return rc
end

function epoll.epoll_wait(epfd, maxevents, timeout)
	local events = ffi.new("struct epoll_event[".. MAX_EVENTS.."]")
	local num_events = ffi.C.epoll_wait(epfd, events, maxevents, timeout)
	local events_t = {}
	for i=0, num_events do
		if events[i].data.fd > 0 then
			events_t[#events_t + 1 ] = events[i].data.fd
			events_t[#events_t + 1 ] = events[i].events
		end
	end
	events = nil
	return events_t
end

return epoll