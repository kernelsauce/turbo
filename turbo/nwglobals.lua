--[[ Turbo Global counters module

Copyright John Abrahamsen 2011, 2012, 2013 < JhnAbrhmsn@gmail.com >

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
SOFTWARE."             ]]

local log = require "turbo.log"

if not _G.NW_GLOBAL_COUNTER then
    _G.NW_GLOBAL_COUNTER = {
        tcp_recv_bytes = 0,
        tcp_send_bytes = 0,
        tcp_open_sockets = 0,
        tcp_total_connects = 0,
        httpserver_recv_body_bytes = 0,
        httpserver_send_body_bytes = 0,
        httpserver_recv_headers_bytes = 0,
        httpserver_send_headers_bytes = 0,
        httpserver_total_req_count = 0,
        httpserver_errors_count = 0,
        iostream_queue_bytes = 0,
        ioloop_callbacks_run = 0,
        ioloop_callbacks_queue = 0,
        ioloop_callbacks_error_count = 0,
        ioloop_fd_count = 0,
        ioloop_add_handler_count = 0,
        ioloop_update_handler_count = 0,
        ioloop_handlers_total = 0,
        ioloop_handlers_called = 0,
        ioloop_handlers_errors_count = 0,
        ioloop_timeout_count = 0,
        ioloop_interval_count = 0,
        ioloop_iteration_count = 0,
        static_cache_objects = 0,
        static_cache_bytes = 0,
    }
end

local NGC = _G.NW_GLOBAL_COUNTER

local function _noop() end

local function _ngc_set_real(key, i)
    NGC[key] = i
end

local function _ngc_incr_real(key, n)
    NGC[key] = NGC[key] + n
end

local function _ngc_decr_real(key, n)
    NGC[key] = NGC[key] - n
end

if _G.NW_DEBUG or _G.NW_CONSOLE then
    return {
        inc = _ngc_incr_real,
        dec = _ngc_decr_real,
        set = _ngc_set_real,
        ret = function() return NGC end
    }
else
    return {
        inc = _noop,
        dec = _noop,
        set = _noop,
        ret = _noop
        
    }    
end
