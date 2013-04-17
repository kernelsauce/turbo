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
local httputil = require "httputil"
local log = require "log"
local method_map = {
    "GET",
    "HEAD",
    "POST",
    "PUT",
    "CONNECT",
    "OPTIONS",
    "TRACE",
    "COPY",
    "LOCK",
    "MKCOL",
    "MOVE",
    "PROPFIND",
    "PROPPATCH",
    "SEARCH",
    "UNLOCK",
    "REPORT",
    "MKACTIVITY",
    "CHECKOUT",
    "MERGE",
    "MSEARCH",
    "NOTIFY",
    "SUBSCRIBE",
    "UNSUBSCRIBE",
    "PATCH",
    "PURGE"
}
method_map[0] = "DELETE" -- Base 1 problems again!


local function parse_headers(buf, len)
    local nw = ffi.new("struct nonsence_parser_wrapper")
    local sz = libnonsence_parser.nonsence_parser_wrapper_init(nw, buf, len)
    
    if (sz > 0) then
        local header = httputil.HTTPHeaders:new()
        
        -- version
        local major_version = nw.parser.http_major
        local minor_version = nw.parser.http_major
        local version_str = string.format("%d.%d", major_version, minor_version)
        header:set_version(version_str)
        
        -- uri
        header:set_uri(ffi.string(nw.url_str))
        
        -- content-length
        header:set_content_length(tonumber(nw.parser.content_length))
        
        -- method
        header:set_method(method_map[tonumber(nw.parser.method)])
        
        -- header key value fields
        local keyvalue_sz = tonumber(nw.header_key_values_sz) - 1
        for i = 0, keyvalue_sz, 1 do
            local key = ffi.string(nw.header_key_values[i].key)
            local value = ffi.string(nw.header_key_values[i].value)
            header:set(key, value)    
        end
        
        libnonsence_parser.nonsence_parser_wrapper_exit(nw)
        return header, sz
    end
    
    libnonsence_parser.nonsence_parser_wrapper_exit(nw)
    return -1;
end

return {
    parse_headers = parse_headers
}