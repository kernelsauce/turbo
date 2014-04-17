--- Turbo.lua Signal Module
--
-- Copyright John Abrahamsen 2011, 2012, 2013 < JhnAbrhmsn@gmail.com >
--
-- "Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE."           

local ffi = require "ffi"
require "turbo.cdef"

return {    
    signal = ffi.C.signal
    -- For sigprocmask(2)
    , SIG_BLOCK   = 0
    , SIG_UNBLOCK = 1
    , SIG_SETMASK = 2
    -- Fake signal functions.
    , SIG_ERR = ffi.cast("sighandler_t", -1)    --[[ Error return.  ]]
    , SIG_DFL = ffi.cast("sighandler_t", 0) --[[ Default action.  ]]
    , SIG_IGN = ffi.cast("sighandler_t", 1) --[[ Ignore signal.  ]]   
    -- Signals.
    ,   SIGHUP  =   1   --[[ Hangup (POSIX).  ]]
    ,   SIGINT  =   2   --[[ Interrupt (ANSI).  ]]
    ,   SIGQUIT =   3   --[[ Quit (POSIX).  ]]
    ,   SIGILL  =   4   --[[ Illegal instruction (ANSI).  ]]
    ,   SIGTRAP =   5   --[[ Trace trap (POSIX).  ]]
    ,   SIGABRT =   6   --[[ Abort (ANSI).  ]]
    ,   SIGIOT  =   6   --[[ IOT trap (4.2 BSD).  ]]
    ,   SIGBUS  =   7   --[[ BUS error (4.2 BSD).  ]]
    ,   SIGFPE  =   8   --[[ Floating-point exception (ANSI).  ]]
    ,   SIGKILL =   9   --[[ Kill, unblockable (POSIX).  ]]
    ,   SIGUSR1 =   10  --[[ User-defined signal 1 (POSIX).  ]]
    ,   SIGSEGV =   11  --[[ Segmentation violation (ANSI).  ]]
    ,   SIGUSR2 =   12  --[[ User-defined signal 2 (POSIX).  ]]
    ,   SIGPIPE =   13  --[[ Broken pipe (POSIX).  ]]
    ,   SIGALRM =   14  --[[ Alarm clock (POSIX).  ]]
    ,   SIGTERM =   15  --[[ Termination (ANSI).  ]]
    ,   SIGSTKFLT = 16  --[[ Stack fault.  ]]
    ,   SIGCLD  =   SIGCHLD --[[ Same as SIGCHLD (System V).  ]]
    ,   SIGCHLD =   17  --[[ Child status has changed (POSIX).  ]]
    ,   SIGCONT =   18  --[[ Continue (POSIX).  ]]
    ,   SIGSTOP =   19  --[[ Stop, unblockable (POSIX).  ]]
    ,   SIGTSTP =   20  --[[ Keyboard stop (POSIX).  ]]
    ,   SIGTTIN =   21  --[[ Background read from tty (POSIX).  ]]
    ,   SIGTTOU =   22  --[[ Background write to tty (POSIX).  ]]
    ,   SIGURG  =   23  --[[ Urgent condition on socket (4.2 BSD).  ]]
    ,   SIGXCPU =   24  --[[ CPU limit exceeded (4.2 BSD).  ]]
    ,   SIGXFSZ =   25  --[[ File size limit exceeded (4.2 BSD).  ]]
    ,   SIGVTALRM = 26  --[[ Virtual alarm clock (4.2 BSD).  ]]
    ,   SIGPROF =   27  --[[ Profiling alarm clock (4.2 BSD).  ]]
    ,   SIGWINCH =  28  --[[ Window size change (4.3 BSD, Sun).  ]]
    ,   SIGPOLL =   SIGIO   --[[ Pollable event occurred (System V).  ]]
    ,   SIGIO =     29  --[[ I/O now possible (4.2 BSD).  ]]
    ,   SIGPWR =    30  --[[ Power failure restart (System V).  ]]
    ,   SIGSYS =    31  --[[ Bad system call.  ]]
    ,   SIGUNUSED = 31
    ,   _NSIG   =   65  --[[ Biggest signal number + 1 (including real-time signals).  ]]
}
