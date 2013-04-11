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

local HTTP_PARSER_STRICT = _G.HTTP_PARSER_STRICT or true
local PROXY_CONNECTION = "proxy-connection"
local CONNECTION = "connection"
local CONTENT_LENGTH = "content-length"
local TRANSFER_ENCODING = "transfer-encoding"
local UPGRADE = "upgrade"
local CHUNKED = "chunked"
local KEEP_ALIVE = "keep-alive"
local CLOSE = "close"
--[[ Tokens as defined by rfc 2616. Also lowercases them.
         token       = 1*<any CHAR except CTLs or separators>
      separators     = "(" | ")" | "<" | ">" | "@"
                     | "," | ";" | ":" | "\" | <">
                     | "/" | "[" | "]" | "?" | "="
                     | "{" | "}" | SP | HT
 ]]--
local function BIT_AT(a, i) return (not not(a[bit.rshift(i, 3)] and (bit.lshift(1, (bit.band(i, 7)))))) end
local T = HTTP_PARSER_STRICT and function(v) return v end or function(v) return 0 end
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



local function parse_http_header(buf)

end

return {
    VERSION_MAJOR = 1,
    VERSION_MINOR = 0,
    parse_http_header = parse_http_header
}