--[[ Epoll bindings through the LuaJIT FFI Library
Author: John Abrahamsen < JhnAbrhmsn@gmail.com >

This module "epoll_ffi" is a part of the Nonsence Web server.
For the complete stack hereby called "software package" please see:

https://github.com/JohnAbrahamsen/nonsence-ng/

Many of the modules in the software package are derivatives of the 
Tornado web server. Tornado is licensed under Apache 2.0 license.
For more details on Tornado please see:

http://www.tornadoweb.org/

However, this module, epoll_ffi is not a derivate of Tornado and are
hereby licensed under the MIT license.

http://www.opensource.org/licenses/mit-license.php >:

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
SOFTWARE."			]]

local ffi = require "ffi"
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

local epoll = {
	EPOLL_CTL_ADD = 1,
	EPOLL_CTL_DEL = 2, 
	EPOLL_CTL_MOD = 3, 
	EPOLL_EVENTS = {
		EPOLLIN  = 0x001,
		EPOLLPRI = 0x002,
		EPOLLOUT = 0x004,
		EPOLLERR = 0x008,
		EPOLLHUP = 0x0010,
	}
}


--[[ Create a new epoll fd. Returns the fd of the created epoll instance and -1 and errno on error.   
Note on max_events: Since Linux 2.6.8, the size argument is unused, but must be greater than zero. 
(The kernel dynamically sizes the required data structures without needing this initial hint.)	]]
function epoll.epoll_create(max_events)
	max_events = max_events or 100
	local fd = ffi.C.epoll_create(max_events)

	if fd == -1 then
		return -1, ffi.errno()
	end

	return fd
end


--[[ Control a epoll fd.  		
EPOLL_CTL_ADD
	Register the target file descriptor fd on the epoll 
	instance referred to by the file descriptor epfd and 
	associate the event event with the internal file linked 
	to fd.

EPOLL_CTL_MOD
	Change the event event associated with the target file 
	descriptor fd.

EPOLL_CTL_DEL
	Remove (deregister) the target file descriptor fd from 
	the epoll instance referred to by epfd.  The event is 
	ignored and can be NULL.
	
Returns 0 on success and -1 on error together with errno.   ]]
function epoll.epoll_ctl(epfd, op, fd, epoll_events)
	local event = ffi.new("epoll_event", epoll_events)
	event.data.fd = fd
	local rc = ffi.C.epoll_ctl(epfd, op, fd, event)
	if (rc == -1) then
		return -1, ffi.errno()
	end
	return rc
end



--[[ Wait for events on a epoll instance.    
The epoll_wait() system call waits for events on the epoll 
instance referred to by the file descriptor epfd.  The 
memory area pointed to by events will contain the events 
that will be available for the caller.  Up to maxevents are 
returned by epoll_wait().  The maxevents argument must be 
greater than zero.

The call waits for a maximum time of timeout milliseconds.  
Specifying a timeout of -1 makes epoll_wait() wait 
indefinitely, while specifying a timeout equal to zero makes 
epoll_wait() to return immediately even if no events are 
available (return code equal to zero).

Returns a structure containing all of the fd's and their events:
	{{fd, events}, {fd, events}}
On error -1 and errno are returned.      ]]
function epoll.epoll_wait(epfd, timeout, max_events)
	max_events = max_events or 100
	local events = ffi.new("struct epoll_event["..max_events.."]")
	ffi.fill(events, ffi.sizeof(events), 0)
	local num_events = ffi.C.epoll_wait(epfd, events, max_events, timeout)
	
	if num_events == -1 then
		return -1, ffi.errno()
	end
	  
	local events_t = {}
	if num_events == 0 then
		return events_t
	end

	local num_events_base_1 = num_events - 1

	for i = 0, num_events_base_1 do
		events_t[#events_t + 1 ] = {events[i].data.fd, events[i].events} 
	end

	return events_t
end

return epoll
