--[[
	
	Epoll bindings through the LuaJIT FFI Library
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
	SOFTWARE."

  ]]

-------------------------------------------------------------------------
-- Load modules
local ffi = require("ffi")
local log = require("log")
-------------------------------------------------------------------------
-- Module tabel to be returned
local epoll = {}

-------------------------------------------------------------------------
-- From epoll.h

epoll.EPOLL_CTL_ADD = 1 -- Add a file decriptor to the interface
epoll.EPOLL_CTL_DEL = 2 -- Remove a file decriptor from the interface
epoll.EPOLL_CTL_MOD = 3 -- Change file decriptor epoll_event structure
epoll.EPOLL_EVENTS = {
	['EPOLLIN']  = 0x001,
	['EPOLLPRI'] = 0x002,
	['EPOLLOUT'] = 0x004,
	['EPOLLERR'] = 0x008,
	['EPOLLHUP'] = 0x0010,
}

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

local MAX_EVENTS = 100

function epoll.epoll_create()
	--[[ 
	
		Create a new epoll "instance".
		
		From man epoll:
		
		Note on int MAX_EVENTS:
			Since Linux 2.6.8, the size argument is unused, but must 
			be greater than zero. (The kernel dynamically sizes the 
			required data structures without needing this initial 
			hint.)
		
		Returns the int of the created epoll and -1 on error with errno.
			
	--]]
	return ffi.C.epoll_create(MAX_EVENTS)
end

function epoll.epoll_ctl(epfd, op, fd, epoll_events)
	--[[
	
		Control a epoll instance.
		
		From man epoll:
		
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
			
		Returns 0 on success and -1 on error together with errno.
			
    --]]     
	local events = ffi.new("epoll_event", epoll_events)
	-- Add file_descriptor to data union.
	events.data.fd = fd
	return ffi.C.epoll_ctl(epfd, op, fd, events)
end

function epoll.epoll_wait(epfd, timeout)
	--[[
	
		Wait for events on a epoll instance.
		
		From man epoll:
		
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
       
		Returns number of file descriptors ready for the requested 
		I/O or -1 on error and errno is set.
       
    --]]
    
	local events = ffi.new("struct epoll_event[".. MAX_EVENTS.."]")
	local num_events = ffi.C.epoll_wait(epfd, events, MAX_EVENTS, timeout)
	-- epoll_wait() returned error...
	if num_events == -1 then
		return ffi.errno()
	end
	
	--[[ 
	
		From CDATA to Lua table that will be easier to use. 
		
		The table is structured as such:
		[{fd, events[i].events},{fd, events[i].events}]
		The number preceeding after the fd is the events for the fd.
		
	--]]
	  
	local events_t = {}
	if num_events == 0 then
		return events_t
	end

	for i=0, num_events do
		local fd = events[i].data.fd
		if fd == 0 then
			-- Termination of array.
			break
		elseif fd == -1 then
			-- Error on fd.
			ffi.errno()
			break
		end
		if events[i].events then
			events_t[#events_t + 1 ] = {fd, events[i].events} 
		end
	end

	return events_t
end

return epoll
