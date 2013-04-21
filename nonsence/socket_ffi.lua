--[[ Socket FFI
Author: John Abrahamsen < JhnAbrhmsn@gmail.com >

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

local log = require "log"
local ffi = require "ffi"

if not _G.SOCKET_H then
    _G.SOCKET_H = 1
    ffi.cdef([[

    struct sockaddr {
        unsigned short    sa_family;    // address family, AF.AF_xxx
        char              sa_data[14];  // 14 bytes of protocol address
    };
    
    struct in_addr {
        unsigned long s_addr;          // load with inet_pton()
    };
    
    struct in6_addr {
        unsigned char   s6_addr[16];   // load with inet_pton()
    };
    
    // IPv4 AF.AF_INET sockets:
    
    struct sockaddr_in {
        short            sin_family;   // e.g. AF.AF_INET, AF.AF_INET6
        unsigned short   sin_port;     // e.g. htons(3490)
        struct in_addr   sin_addr;     // see struct in_addr, below
        char             sin_zero[8];  // zero this if you want to
    };   
    
    // IPv6 AF.AF_INET6 sockets:
    
    struct sockaddr_in6 {
        uint16_t       sin6_family;   // address family, AF.AF_INET6
        uint16_t       sin6_port;     // port number, Network Byte Order
        uint32_t       sin6_flowinfo; // IPv6 flow information
        struct in6_addr sin6_addr;     // IPv6 address
        uint32_t       sin6_scope_id; // Scope ID
    };

    typedef uint32_t socklen_t;
                 
    extern char *strerror(int errnum);
    extern int32_t socket (int32_t domain, int32_t type, int32_t protocol);
    extern int32_t bind (int32_t fd, const struct sockaddr * addr, socklen_t len);
    extern int32_t listen (int32_t fd, int32_t backlog);
    extern int32_t dup(int32_t oldfd);
    extern int32_t close (int fd);
    extern int32_t connect (int32_t fd, const struct sockaddr * addr, socklen_t len);
    extern int64_t send (int32_t fd, const void *buf, size_t n, int32_t flags);
    extern int64_t recv (int32_t fd, void *buf, size_t n, int32_t flags);
    extern int64_t sendto (int32_t fd, const void *buf, size_t n, int32_t flags, const struct sockaddr * addr, socklen_t addr_len);
    extern int64_t recvfrom (int32_t fd, void * buf, size_t n, int32_t flags, struct sockaddr * addr, socklen_t * addr_len);
    extern int32_t setsockopt (int32_t fd, int32_t level, int32_t optname, const void *optval, socklen_t optlen);
    extern int32_t getsockopt (int32_t fd, int32_t level, int32_t optname, void * optval, socklen_t * optlen);
    extern int32_t accept (int32_t fd, struct sockaddr * addr, socklen_t * addr_len);
    extern uint32_t ntohl (uint32_t netlong);
    extern uint32_t htonl (uint32_t hostlong);
    extern uint16_t ntohs (uint16_t netshort);
    extern uint16_t htons (uint16_t hostshort);
    extern int32_t inet_pton (int32_t af, const char *cp, void *buf);
    extern const char *inet_ntop (int32_t af, const void *cp, char *buf, socklen_t len);
    extern int32_t fcntl (int32_t fd, int32_t cmd, int32_t opt); /* Notice the non canonical form, int32_t instead of ...     */
    ]])
end

local octal = function (s) return tonumber(s, 8) end

--[[ Protocol families.  ]]
local PF = {}
PF.PF_UNSPEC =	0	--[[ Unspecified.  ]]
PF.PF_LOCAL =	1	--[[ Local to host (pipes and file-domain).  ]]
PF.PF_UNIX =		PF.PF_LOCAL --[[ POSIX name for PF.PF_LOCAL.  ]]
PF.PF_FILE =		PF.PF_LOCAL --[[ Another non-standard name for PF.PF_LOCAL.  ]]
PF.PF_INET =		2	--[[ IP protocol family.  ]]
PF.PF_AX25 =		3	--[[ Amateur Radio AX.25.  ]]
PF.PF_IPX =		4	--[[ Novell Internet Protocol.  ]]
PF.PF_APPLETALK =	5	--[[ Appletalk DDP.  ]]
PF.PF_NETROM	= 6	--[[ Amateur radio NetROM.  ]]
PF.PF_BRIDGE	= 7	--[[ Multiprotocol bridge.  ]]
PF.PF_ATMPVC	= 8	--[[ ATM PVCs.  ]]
PF.PF_X25 =		9	--[[ Reserved for X.25 project.  ]]
PF.PF_INET6 =	10	--[[ IP version 6.  ]]
PF.PF_ROSE =		11	--[[ Amateur Radio X.25 PLP.  ]]
PF.PF_DECnet =	12	--[[ Reserved for DECnet project.  ]]
PF.PF_NETBEUI =	13	--[[ Reserved for 802.2LLC project.  ]]
PF.PF_SECURITY =	14	--[[ Security callback pseudo AF.  ]]
PF.PF_KEY =		15	--[[ PF.PF_KEY key management API.  ]]
PF.PF_NETLINK =	 16
PF.PF_ROUTE =	PF.PF_NETLINK --[[ Alias to emulate 4.4BSD.  ]]
PF.PF_PACKET =	17	--[[ Packet family.  ]]
PF.PF_ASH =	 	18	--[[ Ash.  ]]
PF.PF_ECONET =	19	--[[ Acorn Econet.  ]]
PF.PF_ATMSVC =	20	--[[ ATM SVCs.  ]]
PF.PF_RDS =		21	--[[ RDS sockets.  ]]
PF.PF_SNA =		22	--[[ Linux SNA Project ]]
PF.PF_IRDA =		23	--[[ IRDA sockets.  ]]
PF.PF_PPPOX =	24	--[[ PPPoX sockets.  ]]
PF.PF_WANPIPE =	25	--[[ Wanpipe API sockets.  ]]
PF.PF_LLC =		26	--[[ Linux LLC.  ]]
PF.PF_CAN =		29	--[[ Controller Area Network.  ]]
PF.PF_TIPC =		30	--[[ TIPC sockets.  ]]
PF.PF_BLUETOOTH =	31	--[[ Bluetooth sockets.  ]]
PF.PF_IUCV =		32	--[[ IUCV sockets.  ]]
PF.PF_RXRPC =	33	--[[ RxRPC sockets.  ]]
PF.PF_ISDN =		34	--[[ mISDN sockets.  ]]
PF.PF_PHONET =	35	--[[ Phonet sockets.  ]]
PF.PF_IEEE802154 =	36	--[[ IEEE 802.15.4 sockets.  ]]
PF.PF_CAIF =		37	--[[ CAIF sockets.  ]]
PF.PF_ALG =		38	--[[ Algorithm sockets.  ]]
PF.PF_NFC =		39	--[[ NFC sockets.  ]]
PF.PF_MAX =		40	--[[ For now..  ]]


--[[ Address families.  ]]
local AF = {}
AF.AF_UNSPEC =	PF.PF_UNSPEC
AF.AF_LOCAL =	PF.PF_LOCAL
AF.AF_UNIX =		PF.PF_UNIX
AF.AF_FILE =		PF.PF_FILE
AF.AF_INET =		PF.PF_INET
AF.AF_AX25 =		PF.PF_AX25
AF.AF_IPX =		PF.PF_IPX
AF.AF_APPLETALK =	PF.PF_APPLETALK
AF.AF_NETROM =	PF.PF_NETROM
AF.AF_BRIDGE =	PF.PF_BRIDGE
AF.AF_ATMPVC =	PF.PF_ATMPVC
AF.AF_X25 =		PF.PF_X25
AF.AF_INET6 =	PF.PF_INET6
AF.AF_ROSE =		PF.PF_ROSE
AF.AF_DECnet =	PF.PF_DECnet
AF.AF_NETBEUI =	PF.PF_NETBEUI
AF.AF_SECURITY =	PF.PF_SECURITY
AF.AF_KEY =		PF.PF_KEY
AF.AF_NETLINK =	PF.PF_NETLINK
AF.AF_ROUTE =	PF.PF_ROUTE
AF.AF_PACKET =	PF.PF_PACKET
AF.AF_ASH =		PF.PF_ASH
AF.AF_ECONET =	PF.PF_ECONET
AF.AF_ATMSVC =	PF.PF_ATMSVC
AF.AF_RDS =		PF.PF_RDS
AF.AF_SNA =		PF.PF_SNA
AF.AF_IRDA =		PF.PF_IRDA
AF.AF_PPPOX =	PF.PF_PPPOX
AF.AF_WANPIPE =	PF.PF_WANPIPE
AF.AF_LLC =		PF.PF_LLC
AF.AF_CAN =		PF.PF_CAN
AF.AF_TIPC =		PF.PF_TIPC
AF.AF_BLUETOOTH =	PF.PF_BLUETOOTH
AF.AF_IUCV =		PF.PF_IUCV
AF.AF_RXRPC =	PF.PF_RXRPC
AF.AF_ISDN =		PF.PF_ISDN
AF.AF_PHONET =	PF.PF_PHONET
AF.AF_IEEE802154 =	PF.PF_IEEE802154
AF.AF_CAIF =		PF.PF_CAIF
AF.AF_ALG =		PF.PF_ALG
AF.AF_NFC =		PF.PF_NFC
AF.AF_MAX =		PF.PF_MAX

local SOL = {}
SOL.SOL_SOCKET =	1

local SO = {}
SO.SO_DEBUG =	1
SO.SO_REUSEADDR =	2
SO.SO_TYPE =		3
SO.SO_ERROR =	4
SO.SO_DONTROUTE =	5
SO.SO_BROADCAST	= 6
SO.SO_SNDBUF =	7
SO.SO_RCVBUF =	8
SO.SO_SNDBUFFORCE =	32
SO.SO_RCVBUFFORCE =	33
SO.SO_KEEPALIVE =	9
SO.SO_OOBINLINE =	10
SO.SO_NO_CHECK =	11
SO.SO_PRIORITY =	12
SO.SO_LINGER =	13
SO.SO_BSDCOMPAT =	14
SO.SO_PASSCRED =	16
SO.SO_PEERCRED =	17
SO.SO_RCVLOWAT =	18
SO.SO_SNDLOWAT =	19
SO.SO_RCVTIMEO =	20
SO.SO_SNDTIMEO =	21
--[[ Security levels - as per NRL IPv6 - don't actually do anything  ]]
SO.SO_SECURITY_AUTHENTICATION =		22
SO.SO_SECURITY_ENCRYPTION_TRANSPORT =	23
SO.SO_SECURITY_ENCRYPTION_NETWORK =		24
SO.SO_BINDTODEVICE =	25
--[[ Socket filtering   ]]
SO.SO_ATTACH_FILTER =	26
SO.SO_DETACH_FILTER =	27
SO.SO_PEERNAME =		28
SO.SO_TIMESTAMP =		29
SO.SCM_TIMESTAMP =		SO.SO_TIMESTAMP
SO.SO_ACCEPTCONN =		30
SO.SO_PEERSEC =		31
SO.SO_PASSSEC =		34
SO.SO_TIMESTAMPNS =		35
SCM_TIMESTAMPNS =		SO.SO_TIMESTAMPNS
SO.SO_MARK =			36
SO.SO_TIMESTAMPING =		37
SO.SCM_TIMESTAMPING=	SO.SO_TIMESTAMPING
SO.SO_PROTOCOL =		38
SO.SO_DOMAIN =		39
SO.SO_RXQ_OVFL =             40
SO.SO_WIFI_STATUS =		41
SO.SCM_WIFI_STATUS =	SO.SO_WIFI_STATUS
SO.SO_PEEK_OFF =		42
--[[ Instruct lower device to use last 4-bytes of skb data as FCS   ]]
SO.SO_NOFCS =		43

local SOCK = {}
SOCK.SOCK_STREAM = 1		--[[ Sequenced, reliable, connection-based
				   byte streams.  ]]

SOCK.SOCK_DGRAM = 2		--[[ Connectionless, unreliable datagrams
				   of fixed maximum length.  ]]
SOCK.SOCK_RAW = 3			--[[ Raw protocol interface.  ]]
SOCK.SOCK_RDM = 4			--[[ Reliably-delivered messages.  ]]
SOCK.SOCK_SEQPACKET = 5		--[[ Sequenced, reliable, connection-based,
				   datagrams of fixed maximum length.  ]]
SOCK.SOCK_DCCP = 6		--[[ Datagram Congestion Control Protocol.  ]]
SOCK.SOCK_PACKET = 10		--[[ Linux specific way of getting packets
				   at the dev level.  For writing rarp and
				   other similar things on the user level. ]]

--[[ Flags to be ORed into the type parameter of socket and socketpair and
   used for the flags parameter of paccept.  ]]

SOCK.SOCK_CLOEXEC = 02000000	--[[ Atomically set close-on-exec flag for the
				   new descriptor(s).  ]]
SOCK.SOCK_NONBLOCK = 04000		--[[ Atomically mark descriptor(s) as
				   non-blocking.  ]]

local O = {}
O.O_ACCMODE = octal("0003")
O.O_RDONLY = octal("00")
O.O_WRONLY = octal("01")
O.O_RDWR = octal("02")
O.O_CREAT = octal("0100")	
O.O_EXCL = octal("0200")	
O.O_NOCTTY = octal("0400")	
O.O_TRUNC = octal("01000")
O.O_APPEND = octal("02000")
O.O_NONBLOCK = octal("04000")
O.O_NDELAY = O.O_NONBLOCK
O.O_SYNC = octal("04010000")
O.O_FSYNC = O.O_SYNC
O.O_ASYNC = octal("020000")

local F = {}
F.F_DUPFD =		0	--[[ Duplicate file descriptor.  ]]
F.F_GETFD =		1	--[[ Get file descriptor flags.  ]]
F.F_SETFD =		2	--[[ Set file descriptor flags.  ]]
F.F_GETFL =		3	--[[ Get file status flags.  ]]
F.F_SETFL =		4	--[[ Set file status flags.  ]]

local function strerror(errno)
    local cstr = ffi.C.strerror(errno);
    return ffi.string(cstr);
end

local EAGAIN = 11
local EWOULDBLOCK = EAGAIN

return {
    EWOULDBLOCK = EWOULDBLOCK,
    EAGAIN = EAGAIN,
    inet_pton = ffi.C.inet_pton,
    inet_ntop = ffi.C.inet_ntop,
    ntohl = ffi.C.ntohl,
    htonl = ffi.C.htonl,
    ntohs = ffi.C.ntohs,
    htons = ffi.C.htons,
    fcntl = ffi.C.fcntl,
    INADDR_ANY = 0x00000000,
    INADDR_BROADCAST = 0xffffffff,
    INADDR_NONE =	0xffffffff,
    strerror = strerror,
    socket = ffi.C.socket,
    dup = ffi.C.dup,
    bind = ffi.C.bind,
    listen = ffi.C.listen,
    connect = ffi.C.connect,
    send = ffi.C.send,
    close = ffi.C.close,
    recv = ffi.C.recv,
    sendto = ffi.C.sendto,
    recvfrom = ffi.C.recvfrom,
    setsockopt = ffi.C.setsockopt,
    getsockopt = ffi.C.getsockopt,
    accept = ffi.C.accept,
    SOCK = SOCK,
    
    F = F,
    O = O,
    AF = AF,
    PF = PF,
    SOL = SOL,
    SO = SO
}