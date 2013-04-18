/* Wrapper for http_parser.c
Copyright 2013 John Abrahamsen < JhnAbrhmsn@gmail.com >

This module "http_parser_ffi_wrap" is a part of the Nonsence Web server.
For the complete stack hereby called "software package" please see:

https://github.com/JohnAbrahamsen/nonsence-ng/

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
SOFTWARE."			*/

#include <stdint.h>
#include "http_parser.h"


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
extern char *url_field(const char *url_str, const struct http_parser_url *url, enum http_parser_url_fields prop);
