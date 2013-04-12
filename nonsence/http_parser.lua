--[[ Lua Fast HTTP parser

Copyright 2013 John Abrahamsen
Based on http_parser.c from Node copyright Joyent.
Based on src/http/ngx_http_parse.c from NGINX copyright Igor Sysoev
Additional changes are licensed under the same terms as NGINX and
copyright Joyent, Inc. and other Node contributors. All rights reserved.

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

require "bit"
local b = string.byte
local log = require "log"

local VERSION_MAJOR = 1
local VERSION_MINOR = 0
local HTTP_PARSER_STRICT = _G.HTTP_PARSER_STRICT or true
local PROXY_CONNECTION = "proxy-connection"
local CONNECTION = "connection"
local CONTENT_LENGTH = "content-length"
local TRANSFER_ENCODING = "transfer-encoding"
local UPGRADE = "upgrade"
local CHUNKED = "chunked"
local KEEP_ALIVE = "keep-alive"
local CLOSE = "close"
local CR = '\r'
local LF = '\n'
local CRLF = CR..LF
local function BIT_AT(a, i) return (not not(a[bit.rshift(i, 3)] and (bit.lshift(1, (bit.band(i, 7)))))) end
local T = HTTP_PARSER_STRICT and function(v) return v end or function(v) return 0 end


--[[ Tokens as defined by rfc 2616. Also lowercases them.
         token       = 1*<any CHAR except CTLs or separators>
      separators     = "(" | ")" | "<" | ">" | "@"
                     | "," | ";" | ":" | "\" | <">
                     | "/" | "[" | "]" | "?" | "="
                     | "{" | "}" | SP | HT
 ]]--
local tokens = {
--[[   0 nul    1 soh    2 stx    3 etx    4 eot    5 enq    6 ack    7 bel  ]]--
        0,       0,       0,       0,       0,       0,       0,       0,
--[[   8 bs     9 ht    10 nl    11 vt    12 np    13 cr    14 so    15 si   ]]--
        0,       0,       0,       0,       0,       0,       0,       0,
--[[  16 dle   17 dc1   18 dc2   19 dc3   20 dc4   21 nak   22 syn   23 etb ]]--
        0,       0,       0,       0,       0,       0,       0,       0,
--[[  24 can   25 em    26 sub   27 esc   28 fs    29 gs    30 rs    31 us  ]]--
        0,       0,       0,       0,       0,       0,       0,       0,
--[[  32 sp    33  !    34  "    35  #    36  $    37  %    38  &    39  b'  ]]--
        0,      b'!',      0,      b'#',     b'$',     b'%',     b'&',    b'\'',
--[[  40  (    41  )    42  *    43  +    44  ,    45  -    46  .    47  /  ]]--
        0,       0,      b'*',     b'+',      0,      b'-',     b'.',      0,
--[[  48  0    49  1    50  2    51  3    52  4    53  5    54  6    55  7  ]]--
       b'0',     b'1',     b'2',     b'3',     b'4',     b'5',     b'6',     b'7',
--[[  56  8    57  9    58  :    59  ;    60  <    61  =    62  >    63  ?  ]]--
       b'8',     b'9',      0,       0,       0,       0,       0,       0,
--[[  64  @    65  A    66  B    67  C    68  D    69  E    70  F    71  G  ]]--
        0,      b'a',     b'b',     b'b',     b'd',     b'e',     b'f',     b'g',
--[[  72  H    73  I    74  J    75  K    76  L    77  M    78  N    79  O  ]]--
       b'h',     b'i',     b'j',     b'k',     b'l',     b'm',     b'n',     b'o',  
--[[  80  P    81  Q    82  R    83  S    84  T    85  U    86  V    87  W  ]]--
       b'p',     b'q',     b'r',     b's',     b't',     b'u',     b'v',     b'w',
--[[  88  X    89  Y    90  Z    91  [    92  \    93  ]    94  ^    95  _  ]]--
       b'x',     b'y',     b'z',      0,       0,       0,      b'^',     b'_',
--[[  96  `    97  a    98  b    99  c   100  d   101  e   102  f   103  g  ]]--
       b'`',     b'a',     b'b',     b'b',     b'd',     b'e',     b'f',     b'g',
--[[ 104  h   105  i   106  j   107  k   108  l   109  m   110  n   111  o  ]]--
       b'h',     b'i',     b'j',     b'k',     b'l',     b'm',     b'n',     b'o',
--[[ 112  p   113  q   114  r   115  s   116  t   117  u   118  v   119  w  ]]--
       b'p',     b'q',     b'r',     b's',     b't',     b'u',     b'v',     b'w',
--[[ 120  x   121  y   122  z   123  {   124  |   125  }   126  ~   127 del ]]--
       b'x',     b'y',     b'z',      0,      b'|',      0,      b'~',       0 }


local unhex =
  {-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
  ,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
  ,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
  , 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,-1,-1,-1,-1,-1,-1
  ,-1,10,11,12,13,14,15,-1,-1,-1,-1,-1,-1,-1,-1,-1
  ,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
  ,-1,10,11,12,13,14,15,-1,-1,-1,-1,-1,-1,-1,-1,-1
  ,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
  };
  
  
local normal_url_char = {
    --[[   0 nul   1 soh    2 stx    3 etx    4 eot    5 enq    6 ack    7 bel  ]]
    bit.bor(0, bit.bor(0, bit.bor(0, bit.bor(0, bit.bor(0, bit.bor(0, bit.bor(0,0))))))),
    --[[   8 bs     9 ht    10 nl    11 vt    12 np    13 cr    14 so    15 si  ]]
    bit.bor(0, bit.bor(T(2), bit.bor(0, bit.bor(0, bit.bor(T(16), bit.bor(0, bit.bor(0,0))))))),
    --[[  16 dle   17 dc1   18 dc2   19 dc3   20 dc4   21 nak   22 syn   23 etb ]]
    bit.bor(0, bit.bor(0, bit.bor(0, bit.bor(0, bit.bor(0, bit.bor(0, bit.bor(0,0))))))),
    --[[  24 can   25 em    26 sub   27 esc   28 fs    29 gs    30 rs    31 us  ]]
    bit.bor(0, bit.bor(0, bit.bor(0, bit.bor(0, bit.bor(0, bit.bor(0, bit.bor(0,0))))))),
    --[[  32 sp    33  !    34  "    35  #    36  $    37  %    38  &    39  '  ]]
    bit.bor(0, bit.bor(2, bit.bor(4, bit.bor(0, bit.bor(16, bit.bor(32, bit.bor(64,128))))))),
    --[[  40  (    41  )    42  *    43  +    44  ,    45  -    46  .    47  /  ]]
    bit.bor(1, bit.bor(2, bit.bor(4, bit.bor(8, bit.bor(16, bit.bor(32, bit.bor(64,128))))))),
    --[[  48  0    49  1    50  2    51  3    52  4    53  5    54  6    55  7  ]]
    bit.bor(1, bit.bor(2, bit.bor(4, bit.bor(8, bit.bor(16, bit.bor(32, bit.bor(64,128))))))),
    --[[  56  8    57  9    58  :    59  ;    60  <    61  =    62  >    63  ?  ]]
    bit.bor(1, bit.bor(2, bit.bor(4, bit.bor(8, bit.bor(16, bit.bor(32, bit.bor(64,0))))))),
    --[[  64  @    65  A    66  B    67  C    68  D    69  E    70  F    71  G  ]]
    bit.bor(1, bit.bor(2, bit.bor(4, bit.bor(8, bit.bor(16, bit.bor(32, bit.bor(64,128))))))),
    --[[  72  H    73  I    74  J    75  K    76  L    77  M    78  N    79  O  ]]
    bit.bor(1, bit.bor(2, bit.bor(4, bit.bor(8, bit.bor(16, bit.bor(32, bit.bor(64,128))))))),
    --[[  80  P    81  Q    82  R    83  S    84  T    85  U    86  V    87  W  ]]
    bit.bor(1, bit.bor(2, bit.bor(4, bit.bor(8, bit.bor(16, bit.bor(32, bit.bor(64,128))))))),
    --[[  88  X    89  Y    90  Z    91  [    92  \    93  ]    94  ^    95  _  ]]
    bit.bor(1, bit.bor(2, bit.bor(4, bit.bor(8, bit.bor(16, bit.bor(32, bit.bor(64,128))))))),
    --[[  96  `    97  a    98  b    99  c   100  d   101  e   102  f   103  g  ]]
    bit.bor(1, bit.bor(2, bit.bor(4, bit.bor(8, bit.bor(16, bit.bor(32, bit.bor(64,128))))))),
    --[[ 104  h   105  i   106  j   107  k   108  l   109  m   110  n   111  o  ]]
    bit.bor(1, bit.bor(2, bit.bor(4, bit.bor(8, bit.bor(16, bit.bor(32, bit.bor(64,128))))))),
    --[[ 112  p   113  q   114  r   115  s   116  t   117  u   118  v   119  w  ]]
    bit.bor(1, bit.bor(2, bit.bor(4, bit.bor(8, bit.bor(16, bit.bor(32, bit.bor(64,128))))))),
    --[[ 120  x   121  y   122  z   123  {   124  |   125  }   126  ~   127 del ]]
    bit.bor(1, bit.bor(2, bit.bor(4, bit.bor(8, bit.bor(16, bit.bor(32, bit.bor(64,0)))))))
}

--[[ Parser states.  Used internally only. ]]
local state =
  { s_dead = 1
   
  , s_start_req_or_res = 2
  , s_res_or_resp_H = 3
  , s_start_res = 4
  , s_res_H = 5
  , s_res_HT = 6
  , s_res_HTT = 7
  , s_res_HTTP = 8
  , s_res_first_http_major = 9
  , s_res_http_major = 10
  , s_res_first_http_minor = 11
  , s_res_http_minor = 12
  , s_res_first_status_code = 13
  , s_res_status_code = 14
  , s_res_status = 15
  , s_res_line_almost_done = 16
 
  , s_start_req = 17
 
  , s_req_method = 18
  , s_req_spaces_before_url = 19
  , s_req_schema = 20
  , s_req_schema_slash = 21
  , s_req_schema_slash_slash = 22
  , s_req_server_start = 23
  , s_req_server = 24
  , s_req_server_with_at = 25
  , s_req_path = 26
  , s_req_query_string_start = 27
  , s_req_query_string = 28
  , s_req_fragment_start = 29
  , s_req_fragment = 30
  , s_req_http_start = 31
  , s_req_http_H = 32
  , s_req_http_HT = 33
  , s_req_http_HTT = 34
  , s_req_http_HTTP = 35
  , s_req_first_http_major = 36
  , s_req_http_major = 37
  , s_req_first_http_minor = 38
  , s_req_http_minor = 39
  , s_req_line_almost_done = 40

  , s_header_field_start = 41
  , s_header_field = 42
  , s_header_value_start = 43
  , s_header_value = 44
  , s_header_value_lws = 45

  , s_header_almost_done = 46
  
  , s_chunk_size_start = 47
  , s_chunk_size = 48
  , s_chunk_parameters = 49
  , s_chunk_size_almost_done = 50

  , s_headers_almost_done = 51
  , s_headers_done = 52

  --[[Important: 's_headers_done' must be the last 'header' state. All
    states beyond this must be 'body' states. It is used for overflow
    checking. See the PARSING_HEADER() macro.
   ]]

  , s_chunk_data = 53
  , s_chunk_data_almost_done = 54
  , s_chunk_data_done = 55

  , s_body_identity = 56
  , s_body_identity_eof = 57

  , s_message_done = 58
  };
  
local header_states = 
  { h_general = 0
  , h_C = 1
  , h_CO = 2
  , h_CON = 3

  , h_matching_connection = 4
  , h_matching_proxy_connection = 5
  , h_matching_content_length = 6
  , h_matching_transfer_encoding = 7
  , h_matching_upgrade = 8

  , h_connection = 9 
  , h_content_length = 10
  , h_transfer_encoding = 11
  , h_upgrade = 12

  , h_matching_transfer_encoding_chunked = 13
  , h_matching_connection_keep_alive = 14
  , h_matching_connection_close = 15

  , h_transfer_encoding_chunked = 16
  , h_connection_keep_alive = 17
  , h_connection_close = 18
  };

local http_host_state = 
  {
    s_http_host_dead = 1
  , s_http_userinfo_start = 2
  , s_http_userinfo = 3
  , s_http_host_start = 4
  , s_http_host_v6_start = 5
  , s_http_host = 6
  , s_http_host_v6 = 7
  , s_http_host_v6_end = 8
  , s_http_host_port_start = 9
  , s_http_host_port = 10
};

local function PARSING_HEADER(state) return (state <= state.s_headers_done) end

--[[ Functions for character classes; depends on strict-mode.   ]]
local function LOWER(c) return (bit.bor(c, 0x20)) end 
local function IS_ALPHA(c) return (LOWER(c) >= b'a' and LOWER(c) <= b'z') end
local function IS_NUM(c) return ((c) >= b'0' and (c) <= b'9') end
local function IS_ALPHANUM(c) return (IS_ALPHA(c) or IS_NUM(c)) end
local function IS_HEX(c) return (IS_NUM(c) or (LOWER(c) >= b'a' and LOWER(c) <= b'f')) end
local function IS_MARK(c) return ((c) == b'-' or (c) == b'_' or (c) == b'.' or 
  (c) == b'!' or (c) == b'~' or (c) == b'*' or (c) == b'\'' or (c) == b'(' or
  (c) == b')') end
local function IS_USERINFO_CHAR(c) return (IS_ALPHANUM(c) or IS_MARK(c) or (c) == b'%' or 
  (c) == b';' or (c) == b':' or (c) == b'&' or (c) == b'=' or (c) == b'+' or 
  (c) == b'$' or (c) == b',') end
local TOKEN, IS_URL_CHAR, IS_HOST_CHAR
if HTTP_PARSER_STRICT then
    TOKEN = function(c) return (tokens[c]) end
    IS_URL_CHAR = function(c) return (BIT_AT(normal_url_char, c)) end
    IS_HOST_CHAR = function(c) return (IS_ALPHANUM(c) or (c) == b'.' or (c) == b'-') end
else
    TOKEN = function(c) return ((c == b' ') and b' ' or tokens[c]) end
    IS_URL_CHAR = function(c) return (BIT_AT(normal_url_char, c) or (bit.band((c), 0x80))) end
    IS_HOST_CHAR = function(c) return (IS_ALPHANUM(c) or (c) == b'.' or (c) == b'-' or (c) == b'_') end
end


--[[Our URL parser.
 
  This is designed to be shared by http_parser_execute() for URL validation,
  hence it has a state transition + byte-for-byte interface. In addition, it
  is meant to be embedded in http_parser_parse_url(), which does the dirty
  work of turning state transitions URL components for its API.
 
  This function should only be invoked with non-space characters. It is
  assumed that the caller cares about (and can detect) the transition between
  URL and non-URL states by looking for these.    ]]--
local function parse_url_char(s, ch)
    if (ch == b' ' or ch == b'\r' or ch == b'\n') then
      return state.s_dead
    end
  
    if HTTP_PARSER_STRICT then
        if (ch == b'\t' or ch == b'\f') then
            return state.s_dead;
        end
    end
    
    for i=0, 1 do
        if (s == state.s_req_spaces_before_url) then
            if (ch == b'/' or ch == b'*') then 
              return state.s_req_path;
            end
            
            if (IS_ALPHA(ch)) then
                return state.s_req_schema;
            end
            
            break
            
        end
        
        if (s == state.s_req_schema) then
            if (IS_ALPHA(ch)) then
                return s
            end
            
            if (ch == b':') then
                return state.s_req_schema_slash
            end
            
            break
        end
        
        if (s == state.s_req_schema_slash) then
            if (ch == b'/') then
                return state.s_req_schema_slash_slash
            end
            
            break
            
        end
        
        if (s == state.s_req_schema_slash_slash) then
            if (ch == b'/') then
                return state.s_req_server_start
            end
            
            break
            
        end
        
        if (s == state.s_req_server_with_at) then
            if (ch == b'@') then
                return state.s_dead
            end
        end
        
        --[[ Fallthrough.  ]]
        if (s == state.s_req_server_start or s_req_server) then
            if (ch == b'/') then
                return state.s_req_path
            end
            
            if (ch == b'?') then
                return state.s_req_query_string_start
            end
        
            if (ch == b'@') then
                return state.s_req_server_with_at
            end
            
            if (IS_USERINFO_CHAR(ch) or ch == b'[' or ch == b']') then
                return state.s_req_server;
            end
            
            break
        end
        
        if (s == state.s_req_path) then
            if (IS_URL_CHAR(ch)) then
                return s;
            end

            if (ch == b'?') then 
                return state.s_req_query_string_start
            end
      
            if (ch == b'#') then
                return state.s_req_fragment_start
            end
            
            break
        end
        
        if (s == state.s_req_query_string_start or s == state.s_req_query_string) then
            if (IS_URL_CHAR(ch)) then
                return state.s_req_query_string
            end
      
            if (ch == b'?') then
                --[[ allow extra '?' in query string ]]
                return state.s_req_query_string;
            end
            
            if (ch == b'#') then
                return state.s_req_fragment_start
            end
      
            break
        end
    
        if (s == state.s_req_fragment_start) then
            if (IS_URL_CHAR(ch)) then
                return state.s_req_fragment
            end
          
            if (ch == b'?') then
                return state.s_req_fragment
            end
            if (ch == b'#') then
                return s;
            end
            
            break
        end
        
        if (s == state.s_req_fragment) then
            if (IS_URL_CHAR(ch)) then
                return s;
            end
      
            if (ch == b'?' or ch == b'#') then
                return s
            end
      
            break
        end
        
        break
    end

  --[[ We should never fall out of the switch above unless there's an error   ]]
    return state.s_dead;
end


return {
    VERSION_MAJOR = VERSION_MAJOR,
    VERSION_MINOR = VERSION_MINOR,
}