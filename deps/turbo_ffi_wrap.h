/* Wrapper for FFI calls from Turbo.lua, where its is difficult because
of long header file, macros, define's etc.

Copyright 2013 John Abrahamsen < JhnAbrhmsn@gmail.com >

This module "http_parser_ffi_wrap" is a part of the Turbo Web server.
For the complete stack hereby called "software package" please see:

https://github.com/JohnAbrahamsen/turbo-ng/

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
SOFTWARE."          */

#include <stdint.h>
#include <stdlib.h>

#ifndef TURBO_NO_SSL
#include <openssl/ssl.h>
#endif
#include <stdbool.h>
#include "http-parser/http_parser.h"

// http-parser wrapper functions.

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

struct turbo_parser_wrapper{
    int32_t url_rc;
    size_t parsed_sz;
    bool headers_complete;
    enum header_state _state; ///< Used internally

    const char *url_str; ///< Offset for passed in char ptr
    size_t url_sz;
    size_t hkv_sz;
    size_t hkv_mem ;  ///< We allocate in chunks of 10 structs at a time.
    struct turbo_key_value_field **hkv;
    struct http_parser parser;
    struct http_parser_url url;
};

struct turbo_parser_wrapper *turbo_parser_wrapper_init(
        const char* data,
        size_t len,
        int32_t type);

void turbo_parser_wrapper_exit(struct turbo_parser_wrapper *src);

int32_t http_parser_parse_url(
        const char *buf,
        size_t buflen,
        int32_t is_connect,
        struct http_parser_url *u);

/** Check if a given field is set in http_parser_url  */
bool url_field_is_set(
        const struct http_parser_url *url,
        enum http_parser_url_fields prop);
char *url_field(
        const char *url_str,
        const struct http_parser_url *url,
        enum http_parser_url_fields prop);
bool turbo_parser_check(struct turbo_parser_wrapper *s);

char* turbo_websocket_mask(const char *mask32, const char* in, size_t sz);
uint64_t turbo_bswap_u64(uint64_t swap);

// OpenSSL wrapper functions.
#ifndef TURBO_NO_SSL
#define MatchFound 0
#define MatchNotFound 1
#define NoSANPresent 2
#define MalformedCertificate 3
#define Error 4

/** Validate a X509 cert against provided hostname. */
int32_t validate_hostname(const char *hostname, const SSL *server);
#endif
