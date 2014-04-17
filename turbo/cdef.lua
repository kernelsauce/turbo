--- Turbo.lua C function declarations
--
-- Copyright 2013 John Abrahamsen
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

local ffi = require "ffi"


--- ******* stdlib *******
ffi.cdef [[
typedef int32_t pid_t;

void *malloc(size_t sz);
void *realloc (void* ptr, size_t size);
void free(void *ptr);
int sprintf(char * str, const char * format, ...);
int printf(const char *format, ...);
void *memmove(void * destination, const void * source, size_t num);
int memcmp(const void * ptr1, const void * ptr2, size_t num);
void *memchr(void * ptr, int value, size_t num);
int strncasecmp(const char *s1, const char *s2, size_t n);
int snprintf(char *s, size_t n, const char *format, ...);
pid_t fork();
pid_t wait(int32_t *status);
pid_t waitpid(pid_t pid, int *status, int options);
pid_t getpid();
int execvp(const char *path, char *const argv[]);
]]

--- ******* Socket *******
ffi.cdef([[
typedef int32_t socklen_t;

struct sockaddr {
  unsigned short    sa_family;    // address family, AF.AF_xxx
  char              sa_data[14];  // 14 bytes of protocol address
};

struct sockaddr_storage {
  unsigned short int ss_family;
  unsigned long int __ss_align;
  char __ss_padding[128 - (2 * sizeof(unsigned long int))];
};

struct in_addr {
  unsigned long s_addr;
};

struct in6_addr {
    unsigned char   s6_addr[16];
};

// IPv4 AF.AF_INET sockets:

struct sockaddr_in {
    short            sin_family;   // e.g. AF.AF_INET, AF.AF_INET6
    unsigned short   sin_port;     // e.g. htons(3490)
    struct in_addr   sin_addr;     // see struct in_addr, below
    char             sin_zero[8];  // zero this if you want to
} __attribute__ ((__packed__));

// IPv6 AF.AF_INET6 sockets:

struct sockaddr_in6 {
    uint16_t       sin6_family;   // address family, AF.AF_INET6
    uint16_t       sin6_port;     // port number, Network Byte Order
    uint32_t       sin6_flowinfo; // IPv6 flow information
    struct in6_addr sin6_addr;     // IPv6 address
    uint32_t       sin6_scope_id; // Scope ID
};

extern char *strerror(int errnum);
extern int32_t socket (int32_t domain, int32_t type, int32_t protocol);
extern int32_t bind (int32_t fd, const struct sockaddr * addr, socklen_t len);
extern int32_t listen (int32_t fd, int32_t backlog);
extern int32_t dup(int32_t oldfd);
extern int32_t close (int32_t fd);
extern int32_t connect (int32_t fd, const struct sockaddr * addr, socklen_t len);
extern int32_t setsockopt (int32_t fd, int32_t level, int32_t optname, const void *optval, socklen_t optlen);
extern int32_t getsockopt (int32_t fd, int32_t level, int32_t optname, void * optval, socklen_t * optlen);
extern int32_t accept (int32_t fd, struct sockaddr * addr, socklen_t * addr_len);
extern uint32_t ntohl (uint32_t netlong);
extern uint32_t htonl (uint32_t hostlong);
extern uint16_t ntohs (uint16_t netshort);
extern uint16_t htons (uint16_t hostshort);
extern int32_t inet_pton (int32_t af, const char *cp, void *buf);
extern const char *inet_ntop (int32_t af, const void *cp, char *buf, socklen_t len);
extern char *inet_ntoa (struct in_addr in);
extern int32_t fcntl (int32_t fd, int32_t cmd, int32_t opt); /* Notice the non canonical form, int32_t instead of ...     */
]])

if ffi.abi("32bit") then
ffi.cdef [[
    extern int32_t send (int32_t fd, const void *buf, size_t n, int32_t flags);
    extern int32_t recv (int32_t fd, void *buf, size_t n, int32_t flags);
    extern int32_t sendto (int32_t fd, const void *buf, size_t n, int32_t flags, const struct sockaddr * addr, socklen_t addr_len);
    extern int32_t recvfrom (int32_t fd, void * buf, size_t n, int32_t flags, struct sockaddr * addr, socklen_t * addr_len);
]]
elseif ffi.abi("64bit") then
ffi.cdef [[
    extern int64_t send (int32_t fd, const void *buf, size_t n, int32_t flags);
    extern int64_t recv (int32_t fd, void *buf, size_t n, int32_t flags);
    extern int64_t sendto (int32_t fd, const void *buf, size_t n, int32_t flags, const struct sockaddr * addr, socklen_t addr_len);
    extern int64_t recvfrom (int32_t fd, void * buf, size_t n, int32_t flags, struct sockaddr * addr, socklen_t * addr_len);
]]
end


--- ******* epoll.h *******
ffi.cdef[[
typedef union epoll_data {
    void        *ptr;
    int          fd;
    uint32_t     u32;
    uint64_t     u64;
} epoll_data_t;
]]
if (ffi.abi("32bit")) then
-- struct epoll_event is declared packed on 64 bit,
-- but not on 32 bit.
ffi.cdef[[
struct epoll_event {
    uint32_t     events;      /* Epoll events */
    epoll_data_t data;        /* User data variable */
};
]]
else
ffi.cdef[[
struct epoll_event {
    uint32_t     events;      /* Epoll events */
    epoll_data_t data;        /* User data variable */
} __attribute__ ((__packed__));
]]
end
ffi.cdef[[
typedef struct epoll_event epoll_event;

int32_t epoll_create(int32_t size);
int32_t epoll_ctl(int32_t epfd, int32_t op, int32_t fd, struct epoll_event* event);
int32_t epoll_wait(int32_t epfd, struct epoll_event *events, int32_t maxevents, int32_t timeout);
]]


if _G.TURBO_AXTLS then
    -- axTLS interface functions
    ffi.cdef [[
typedef void SSL_CTX;
typedef void SSL;

SSL_CTX *ssl_ctx_new(uint32_t options, int num_sessions);
void ssl_ctx_free(SSL_CTX *ssl_ctx);
SSL *ssl_server_new(SSL_CTX *ssl_ctx, int client_fd);
SSL *ssl_client_new(SSL_CTX *ssl_ctx, int client_fd, const uint8_t *session_id, uint8_t sess_id_size);
void ssl_free(SSL *ssl);
int ssl_read(SSL *ssl, uint8_t **in_data);
int ssl_write(SSL *ssl, const uint8_t *out_data, int out_len);
int ssl_handshake_status(const SSL *ssl);
void ssl_display_error(int error_code);
const char *ssl_get_cert_dn(const SSL *ssl, int component);
const char *ssl_get_cert_subject_alt_dnsname(const SSL *ssl, int dnsindex);
int ssl_obj_load(SSL_CTX *ssl_ctx, int obj_type, const char *filename, const char *password);


/* axTLS Hash functions */
typedef struct
{
  uint32_t state[4];        /* state (ABCD) */
  uint32_t count[2];        /* number of bits, modulo 2^64 (lsb first) */
  uint8_t buffer[64];       /* input buffer */
} MD5_CTX;
typedef struct
{
    uint32_t Intermediate_Hash[20/4]; /* Message Digest */
    uint32_t Length_Low;            /* Message length in bits */
    uint32_t Length_High;           /* Message length in bits */
    uint16_t Message_Block_Index;   /* Index into message block array   */
    uint8_t Message_Block[64];      /* 512-bit message blocks */
} SHA1_CTX;

void SHA1_Init(SHA1_CTX *ctx);
void SHA1_Update(SHA1_CTX *ctx, const uint8_t *msg, int len);
void SHA1_Final(uint8_t *digest, SHA1_CTX *ctx);

void MD5_Init(MD5_CTX *ctx);
void MD5_Update(MD5_CTX *ctx, const uint8_t * msg, int len);
void MD5_Final(uint8_t *digest, MD5_CTX *ctx);

/* note: digest length is fixed at 20 bytes (160-bit) */
void hmac_sha1(const uint8_t *msg, int length, const uint8_t *key,
               int key_len, uint8_t *digest);

]]

elseif _G.TURBO_SSL then
--- ******* OpenSSL *******
-- Note: Typedef SSL structs to void as we never access their members and they are
-- massive in ifdef's etc and are best left as blackboxes!
ffi.cdef [[
typedef void SSL_METHOD;
typedef void SSL_CTX;
typedef void SSL;
typedef void X509;
typedef void X509_NAME;
typedef void X509_NAME_ENTRY;
typedef void ASN1_STRING;

const SSL_METHOD *SSLv3_server_method(void);  /* SSLv3 */
const SSL_METHOD *SSLv3_client_method(void);  /* SSLv3 */
const SSL_METHOD *SSLv23_method(void);        /* SSLv3 but can rollback to v2 */
const SSL_METHOD *SSLv23_server_method(void); /* SSLv3 but can rollback to v2 */
const SSL_METHOD *SSLv23_client_method(void); /* SSLv3 but can rollback to v2 */
const SSL_METHOD *TLSv1_method(void);         /* TLSv1.0 */
const SSL_METHOD *TLSv1_server_method(void);  /* TLSv1.0 */
const SSL_METHOD *TLSv1_client_method(void);  /* TLSv1.0 */
const SSL_METHOD *TLSv1_1_method(void);       /* TLSv1.1 */
const SSL_METHOD *TLSv1_1_server_method(void);/* TLSv1.1 */
const SSL_METHOD *TLSv1_1_client_method(void);/* TLSv1.1 */
const SSL_METHOD *TLSv1_2_method(void);       /* TLSv1.2 */
const SSL_METHOD *TLSv1_2_server_method(void);/* TLSv1.2 */
const SSL_METHOD *TLSv1_2_client_method(void);/* TLSv1.2 */

/* From openssl/ssl.h */
void OPENSSL_add_all_algorithms_noconf(void);
void SSL_load_error_strings(void);
void ERR_free_strings(void);
int SSL_library_init(void);
void EVP_cleanup(void);
SSL_CTX *SSL_CTX_new(const SSL_METHOD *meth);
void SSL_CTX_free(SSL_CTX *);
int SSL_CTX_use_PrivateKey_file(SSL_CTX *ctx, const char *file, int type);
int SSL_CTX_use_certificate_file(SSL_CTX *ctx, const char *file, int type);
int SSL_CTX_load_verify_locations(SSL_CTX *ctx, const char *CAfile,
    const char *CApath);
int SSL_CTX_check_private_key(const SSL_CTX *ctx);

SSL *SSL_new(SSL_CTX *ctx);
void SSL_set_connect_state(SSL *s);
void SSL_set_accept_state(SSL *s);
int SSL_do_handshake(SSL *s);
int SSL_set_fd(SSL *s, int fd);
int SSL_accept(SSL *ssl);
void SSL_free(SSL *ssl);
int SSL_accept(SSL *ssl);
int SSL_connect(SSL *ssl);
int SSL_read(SSL *ssl,void *buf,int num);
int SSL_peek(SSL *ssl,void *buf,int num);
int SSL_write(SSL *ssl,const void *buf,int num);
void SSL_set_verify(SSL *s, int mode,int (*callback)(int ok,void *ctx));
int SSL_set_cipher_list(SSL *s, const char *str);
int SSL_get_error(const SSL *s, int ret_code);
void SSL_CTX_set_verify_depth(SSL_CTX *ctx, int depth);
void SSL_CTX_set_verify(SSL_CTX *ctx, int mode, void *);
X509 *SSL_get_peer_certificate(const SSL *s);
long SSL_get_verify_result(const SSL *ssl);
const char *X509_verify_cert_error_string(long n);

/* From openssl/err.h  */
unsigned long ERR_get_error(void);
unsigned long ERR_peek_error(void);
unsigned long ERR_peek_error_line(const char **file,int *line);
unsigned long ERR_peek_error_line_data(const char **file,int *line,
                       const char **data,int *flags);
unsigned long ERR_peek_last_error(void);
unsigned long ERR_peek_last_error_line(const char **file,int *line);
unsigned long ERR_peek_last_error_line_data(const char **file,int *line,
                       const char **data,int *flags);
void ERR_clear_error(void );
char *ERR_error_string(unsigned long e,char *buf);
void ERR_error_string_n(unsigned long e, char *buf, size_t len);
const char *ERR_lib_error_string(unsigned long e);
const char *ERR_func_error_string(unsigned long e);
const char *ERR_reason_error_string(unsigned long e);

/* OpenSSL Hash functions */
typedef unsigned int SHA_LONG;
typedef void EVP_MD;
typedef struct SHAstate_st{
  SHA_LONG h0,h1,h2,h3,h4;
  SHA_LONG Nl,Nh;
  SHA_LONG data[16];
  unsigned int num;
  } SHA_CTX;

const EVP_MD *EVP_sha1(void);
unsigned char *SHA1(const unsigned char *d, size_t n, unsigned char *md);
int32_t SHA1_Init(SHA_CTX *c);
int32_t SHA1_Update(SHA_CTX *c, const void *data, size_t len);
int32_t SHA1_Final(unsigned char *md, SHA_CTX *c);
unsigned char *MD5(const unsigned char *d, size_t n, unsigned char *md);
unsigned char *HMAC(const EVP_MD *evp_md, const void *key,
               int key_len, const unsigned char *d, int n,
               unsigned char *md, unsigned int *md_len);

/* only want validate_hostname for OPENSSL, axTLS does this in lua code */
int32_t validate_hostname(const char *hostname, const SSL *server);
]]
end

--- ******* Signals *******
ffi.cdef([[
typedef void (*sighandler_t) (int32_t);
extern sighandler_t signal (int32_t signum, sighandler_t handler);
extern int kill(pid_t pid, int sig);
]])
-- signalfd
ffi.cdef(string.format([[
typedef struct {
    unsigned long int __val[%d];
} __sigset_t;
typedef __sigset_t sigset_t;
int sigemptyset(sigset_t *set);
int sigfillset(sigset_t *set);
int sigaddset(sigset_t *set, int signum);
int sigdelset(sigset_t *set, int signum);
int sigismember(const sigset_t *set, int signum);
int sigprocmask(int how, const sigset_t *set, sigset_t *oldset);
struct signalfd_siginfo
{
  uint32_t ssi_signo;
  int32_t ssi_errno;
  int32_t ssi_code;
  uint32_t ssi_pid;
  uint32_t ssi_uid;
  int32_t ssi_fd;
  uint32_t ssi_tid;
  uint32_t ssi_band;
  uint32_t ssi_overrun;
  uint32_t ssi_trapno;
  int32_t ssi_status;
  int32_t ssi_int;
  uint64_t ssi_ptr;
  uint64_t ssi_utime;
  uint64_t ssi_stime;
  uint64_t ssi_addr;
  uint8_t __pad[48];
};
int signalfd(int fd, const sigset_t *mask, int flags);
]], (1024 / (8 * ffi.sizeof("unsigned long")))))

--- ******* Time *******
ffi.cdef([[
typedef long time_t ;
typedef long suseconds_t ;
struct timeval
{
    time_t tv_sec;      /* Seconds.  */
    suseconds_t tv_usec;    /* Microseconds.  */
};
struct timezone
{
    int tz_minuteswest;     /* Minutes west of GMT.  */
    int tz_dsttime;     /* Nonzero if DST is ever in effect.  */
};
struct tm
{
  int tm_sec;           /* Seconds. [0-60] (1 leap second) */
  int tm_min;           /* Minutes. [0-59] */
  int tm_hour;          /* Hours.   [0-23] */
  int tm_mday;          /* Day.     [1-31] */
  int tm_mon;           /* Month.   [0-11] */
  int tm_year;          /* Year - 1900.  */
  int tm_wday;          /* Day of week. [0-6] */
  int tm_yday;          /* Days in year.[0-365] */
  int tm_isdst;         /* DST.     [-1/0/1]*/
  long int __tm_gmtoff;     /* Seconds east of UTC.  */
  const char *__tm_zone;    /* Timezone abbreviation.  */
};
typedef struct timezone * timezone_ptr_t;

size_t strftime(char* ptr, size_t maxsize, const char* format, const struct tm* timeptr);
struct tm *localtime(const time_t *timer);
time_t time(time_t* timer);
int fputs(const char *str, void *stream); // Stream defined as void to avoid pulling in FILE.
int snprintf(char *s, size_t n, const char *format, ...);
int sprintf ( char * str, const char * format, ... );

struct tm * gmtime (const time_t * timer);
extern int gettimeofday (struct timeval *tv, timezone_ptr_t tz);

]])

--- ******* RealTime (for Monotonic time) *******
ffi.cdef([[
struct timespec
{
    time_t tv_sec;      /* Seconds.  */
    long tv_nsec;    /* Nanoseconds.  */
};
typedef uint32_t clockid_t;
enum clock_ids {
    CLOCK_REALTIME,
    CLOCK_MONOTONIC
};
int clock_gettime(clockid_t clk_id, struct timespec *tp);
]])

--- ******* Resolv *******
ffi.cdef [[
/* Description of data base entry for a single host.  */
struct hostent
{
    char *h_name;       /* Official name of host.  */
    char **h_aliases;   /* Alias list.  */
    int32_t h_addrtype; /* Host address type.  */
    int32_t h_length;   /* Length of address.  */
    char **h_addr_list; /* List of addresses from name server.  */
};

extern struct hostent *gethostbyname (const char *name);
]]


ffi.cdef[[

struct addrinfo {
  int     ai_flags;          // AI_PASSIVE, AI_CANONNAME, ...
  int     ai_family;         // AF_xxx
  int     ai_socktype;       // SOCK_xxx
  int     ai_protocol;       // 0 (auto) or IPPROTO_TCP, IPPROTO_UDP

  socklen_t  ai_addrlen;     // length of ai_addr
  struct sockaddr  *ai_addr; // binary address
  char   *ai_canonname;      // canonical name for nodename
  struct addrinfo  *ai_next; // next structure in linked list
};

int getaddrinfo(const char *nodename, const char *servname,
                const struct addrinfo *hints, struct addrinfo **res);
void freeaddrinfo(struct addrinfo *ai);
const char *gai_strerror(int ecode);

]]


--- ******* HTTP parser and libtffi *******
ffi.cdef[[
enum http_parser_url_fields
{ UF_SCHEMA           = 0
, UF_HOST             = 1
, UF_PORT             = 2
, UF_PATH             = 3
, UF_QUERY            = 4
, UF_FRAGMENT         = 5
, UF_USERINFO         = 6
, UF_MAX              = 7
};

struct http_parser {
/** PRIVATE **/
unsigned char type : 2;     /* enum http_parser_type */
unsigned char flags : 6;    /* F_* values from 'flags' enum; semi-public */
unsigned char state;        /* enum state from http_parser.c */
unsigned char header_state; /* enum header_state from http_parser.c */
unsigned char index;        /* index into current matcher */

uint32_t nread;          /* # bytes read in various scenarios */
uint64_t content_length; /* # bytes in body (0 if no Content-Length header) */

/** READ-ONLY **/
unsigned short http_major;
unsigned short http_minor;
unsigned short status_code; /* responses only */
unsigned char method;       /* requests only */
unsigned char http_errno : 7;

/* 1 = Upgrade header was present and the parser has exited because of that.
 * 0 = No upgrade header present.
 * Should be checked when http_parser_execute() returns in addition to
 * error checking.
 */
unsigned char upgrade : 1;

/** PUBLIC **/
void *data; /* A pointer to get hook to the "connection" or "socket" object */
};

struct http_parser_url {
  uint16_t field_set;           /* Bitmask of (1 << UF_*) values */
  uint16_t port;                /* Converted UF_PORT string */

  struct {
    uint16_t off;               /* Offset into buffer in which field starts */
    uint16_t len;               /* Length of run in buffer */
  } field_data[7];
};

struct turbo_key_value_field{
    /* Size of strings.  */
    size_t key_sz;
    size_t value_sz;
    /* These are offsets for passed in char ptr. */
    const char *key;       ///< Header key.
    const char *value;     ///< Value corresponding to key.
};

/** Used internally  */
enum header_state{
    NOTHING,
    FIELD,
    VALUE
};

/** Wrapper struct for http_parser.c to avoid using callback approach.   */
struct turbo_parser_wrapper{
    int32_t url_rc;
    size_t parsed_sz;
    bool headers_complete;
    enum header_state _state; ///< Used internally

    const char *url_str; ///< Offset for passed in char ptr
    size_t url_sz;
    size_t hkv_sz;
    size_t hkv_mem;
    struct turbo_key_value_field **hkv;
    struct http_parser parser;
    struct http_parser_url url;
};

struct turbo_parser_wrapper *turbo_parser_wrapper_init(
        const char* data,
        size_t len,
        int32_t type);

void turbo_parser_wrapper_exit(struct turbo_parser_wrapper *src);
bool turbo_parser_check(struct turbo_parser_wrapper *s);
int32_t http_parser_parse_url(const char *buf, size_t buflen, int32_t is_connect, struct http_parser_url *u);
extern bool url_field_is_set(const struct http_parser_url *url, enum http_parser_url_fields prop);
extern char *url_field(const char *url_str, const struct http_parser_url *url, enum http_parser_url_fields prop);
const char *http_errno_name(int32_t err);
const char *http_errno_description(int32_t err);
char* turbo_websocket_mask(const char* mask32, const char* in, size_t sz);
uint64_t turbo_bswap_u64(uint64_t swap);
]]


--- ******* inotify *******
ffi.cdef [[
struct inotify_event
{
    int wd;
    uint32_t mask;
    uint32_t cookie;
    uint32_t len;
    char name [];
};

extern int inotify_init (void) __attribute__ ((__nothrow__ , __leaf__));
extern int inotify_add_watch (int __fd, const char *__name, uint32_t __mask)
    __attribute__ ((__nothrow__ , __leaf__));
extern int inotify_rm_watch (int __fd, int __wd)
    __attribute__ ((__nothrow__ , __leaf__));
]]


--- ******* file system *******
ffi.cdef [[
typedef long int __ssize_t;
typedef __ssize_t ssize_t;
extern ssize_t read(int __fd, void *__buf, size_t __nbytes) ;
int syscall(int number, ...);
]]
-- stat structure is architecture dependent in Linux
if ffi.arch == "x86" then
    ffi.cdef[[
      struct stat {
        unsigned long  st_dev;
        unsigned long  st_ino;
        unsigned short st_mode;
        unsigned short st_nlink;
        unsigned short st_uid;
        unsigned short st_gid;
        unsigned long  st_rdev;
        unsigned long  st_size;
        unsigned long  st_blksize;
        unsigned long  st_blocks;
        unsigned long  st_atime;
        unsigned long  st_atime_nsec;
        unsigned long  st_mtime;
        unsigned long  st_mtime_nsec;
        unsigned long  st_ctime;
        unsigned long  st_ctime_nsec;
        unsigned long  __unused4;
        unsigned long  __unused5;
      };
    ]]
elseif ffi.arch =="x64" then
    ffi.cdef [[
      struct stat {
        unsigned long   st_dev;
        unsigned long   st_ino;
        unsigned long   st_nlink;
        unsigned int    st_mode;
        unsigned int    st_uid;
        unsigned int    st_gid;
        unsigned int    __pad0;
        unsigned long   st_rdev;
        long            st_size;
        long            st_blksize;
        long            st_blocks;
        unsigned long   st_atime;
        unsigned long   st_atime_nsec;
        unsigned long   st_mtime;
        unsigned long   st_mtime_nsec;
        unsigned long   st_ctime;
        unsigned long   st_ctime_nsec;
        long            __unused[3];
      };
    ]]
elseif ffi.arch == "ppc" then
    ffi.cdef[[
      struct stat {
        uint32_t  st_dev;
        uint32_t  st_ino;
        uint32_t st_mode;
        uint32_t st_nlink;
        uint32_t st_uid;
        uint32_t st_gid;
        uint32_t st_rdev;
        uint32_t st_size;
        uint32_t st_blksize;
        uint32_t  st_blocks;
        uint32_t  st_atime;
        uint32_t  st_atime_nsec;
        uint32_t  st_mtime;
        uint32_t  st_mtime_nsec;
        uint32_t  st_ctime;
        uint32_t  st_ctime_nsec;
        uint32_t  __unused4;
        uint32_t  __unused5;
      };
    ]]
end


--- ******* glob *******
ffi.cdef[[
typedef struct {
    long unsigned int gl_pathc;
    char **gl_pathv;
    long unsigned int gl_offs;
    int gl_flags;
    void (*gl_closedir)(void *);
    void *(*gl_readdir)(void *);
    void *(*gl_opendir)(const char *);
    int (*gl_lstat)(const char *restrict, void *restrict);
    int (*gl_stat)(const char *restrict, void *restrict);
} glob_t;
int glob(const char *pattern, int flag, int (*)(const char *, int), glob_t *pglob);
void globfree(glob_t *pglob);
]]
