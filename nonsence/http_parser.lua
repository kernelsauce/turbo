local ffi = require "ffi"
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

struct nonsence_key_value_field{
    char *key; ///< Header key.
    char *value; ///< Value corresponding to key.
};

/** Used internally  */
enum header_state{
    NOTHING,
    FIELD,
    VALUE
};

/** Wrapper struct for http_parser.c to avoid using callback approach.   */
struct nonsence_parser_wrapper{
    struct http_parser parser;
    int32_t http_parsed_with_rc;
    struct http_parser_url url;

    bool finished; ///< Set on headers completely parsed, should always be true.
    char *url_str;
    char *body;
    const char *data; ///< Used internally.

    bool headers_complete;
    enum header_state header_state; ///< Used internally.
    int32_t header_key_values_sz; ///< Size of key values in header that is in header_key_values member.
    struct nonsence_key_value_field **header_key_values;

};

extern size_t nonsence_parser_wrapper_init(struct nonsence_parser_wrapper *dest, const char* data, size_t len);
/** Free memory and memset 0 if PARANOID is defined.   */
extern void nonsence_parser_wrapper_exit(struct nonsence_parser_wrapper *src);

/** Check if a given field is set in http_parser_url  */
extern bool url_field_is_set(const struct http_parser_url *url, enum http_parser_url_fields prop);
extern char *url_field(const char *url_str, const struct nonsence_parser_wrapper *wrapper, enum http_parser_url_fields prop);

]]

local libnonsence_parser = ffi.load("libnonsence_parser")

-- Test 
local raw_headers = 
        "GET /test/test.gif?param1=something&param2=somethingelse&param2=somethingelseelse HTTP/1.1\r\n"..
        "Host: somehost.no\r\n"..
        "Connection: keep-alive\r\n"..
        "Cache-Control: max-age=0\r\n"..
        "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.56 Safari/535.11\r\n"..
        "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\n"..
        "Accept-Encoding: gzip,deflate,sdch\r\n"..
        "Accept-Language: en-US,en;q=0.8\r\n"..
        "Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3\r\n"

local nw = ffi.new("struct nonsence_parser_wrapper")
local rc = libnonsence_parser.nonsence_parser_wrapper_init(nw, raw_headers, raw_headers:len())
libnonsence_parser.nonsence_parser_wrapper_exit(nw)
