/* Wrapper for FFI calls from Turbo.lua, where its is difficult because
of long header file, macros, define's etc.

Copyright 2013 John Abrahamsen

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

#include <strings.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <stdbool.h>
#include <limits.h>

#include "http_parser.h"
#include "turbo_ffi_wrap.h"

#ifndef TURBO_NO_SSL
#include <openssl/x509v3.h>
#include <openssl/ssl.h>
#endif

#define MIN(a,b) (((a)<(b))?(a):(b))
#define MAX(a,b) (((a)>(b))?(a):(b))

#define ENDIAN_SWAP_U64(val) ((uint64_t) ( \
    (((uint64_t) (val) & (uint64_t) 0x00000000000000ff) << 56) | \
    (((uint64_t) (val) & (uint64_t) 0x000000000000ff00) << 40) | \
    (((uint64_t) (val) & (uint64_t) 0x0000000000ff0000) << 24) | \
    (((uint64_t) (val) & (uint64_t) 0x00000000ff000000) <<  8) | \
    (((uint64_t) (val) & (uint64_t) 0x000000ff00000000) >>  8) | \
    (((uint64_t) (val) & (uint64_t) 0x0000ff0000000000) >> 24) | \
    (((uint64_t) (val) & (uint64_t) 0x00ff000000000000) >> 40) | \
    (((uint64_t) (val) & (uint64_t) 0xff00000000000000) >> 56)))

#ifndef TURBO_NO_SSL

#pragma GCC diagnostic push 
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
static int matches_common_name(const char *hostname, const X509 *server_cert)
{
    int common_name_loc = -1;
    X509_NAME_ENTRY *common_name_entry = 0;
    ASN1_STRING *common_name_asn1 = 0;
    char *common_name_str = 0;

    common_name_loc = X509_NAME_get_index_by_NID(X509_get_subject_name(
                                                     (X509 *) server_cert),
                                                 NID_commonName, -1);
    if (common_name_loc < 0) {
        return Error;
    }
    common_name_entry = X509_NAME_get_entry(
                X509_get_subject_name(
                    (X509 *) server_cert),
                common_name_loc);
    if (!common_name_entry) {
        return Error;
    }
    common_name_asn1 = X509_NAME_ENTRY_get_data(common_name_entry);
    if (!common_name_asn1) {
        return Error;
    }
    common_name_str = (char *) ASN1_STRING_data(common_name_asn1);
    if (ASN1_STRING_length(common_name_asn1) != strlen(common_name_str)) {
        return MalformedCertificate;
    }
    if (!strcasecmp(hostname, common_name_str)) {
        return MatchFound;
    }
    else {
        return MatchNotFound;
    }
}

static int32_t matches_subject_alternative_name(
        const char *hostname,
        const X509 *server_cert)
{
    int32_t result = MatchNotFound;
    int32_t i;
    int32_t san_names_nb = -1;
    int32_t hostname_is_domain;
    const char *subdomain_offset;
    size_t dns_name_sz;
    size_t hostname_sz = strlen(hostname);
    STACK_OF(GENERAL_NAME) *san_names = 0;

    san_names = X509_get_ext_d2i(
                (X509 *) server_cert,
                NID_subject_alt_name,
                0,
                0);
    if (san_names == 0)
        return NoSANPresent;
    san_names_nb = sk_GENERAL_NAME_num(san_names);
    for (i=0; i<san_names_nb; i++){
        const GENERAL_NAME *current_name = sk_GENERAL_NAME_value(san_names, i);
        if (current_name->type == GEN_DNS){
            char *dns_name = (char *)ASN1_STRING_data(current_name->d.dNSName);
            dns_name_sz = strlen(dns_name);
            if (ASN1_STRING_length(current_name->d.dNSName) != dns_name_sz){
                result = MalformedCertificate;
                break;
            } else {
                if (strcasecmp(hostname, dns_name) == 0){
                    result = MatchFound;
                    break;
                }
                if (dns_name_sz <= 2)
                    continue;
                if (dns_name[0] == '*' && dns_name[1] == '.'){
                    // Wildcard subdomain.
                    subdomain_offset = strchr(hostname, '.');
                    if (!subdomain_offset)
                        continue;
                    hostname_is_domain = strchr(subdomain_offset, '.') ? 0 : 1;
                    if (hostname_is_domain){
                        if (strcasecmp(hostname, dns_name + 2) == 0){
                            result = MatchFound;
                            break;
                        }
                    } else {
                        if (hostname_sz - (subdomain_offset - hostname) > 0){
                            if (strcasecmp(
                                        subdomain_offset + 1,
                                        dns_name + 2) == 0){
                                result = MatchFound;
                                break;
                            }
                        }
                    }
                }
            }
        }
    }
    sk_GENERAL_NAME_pop_free(san_names, GENERAL_NAME_free);

    return result;
}

int32_t validate_hostname(const char *hostname, const SSL *server){
    int32_t result;
    X509 *server_cert = 0;

    if (!hostname || !server){
        return Error;
    }
    server_cert = SSL_get_peer_certificate(server);
    if (!server_cert){
        return Error;
    }
    result = matches_subject_alternative_name(hostname, server_cert);
    if (result == NoSANPresent) {
        result = matches_common_name(hostname, server_cert);
    }
    X509_free(server_cert);
    return result;
}
#pragma GCC diagnostic pop
#endif

bool url_field_is_set(
        const struct http_parser_url *url,
        enum http_parser_url_fields prop)
{
    if (url->field_set & (1 << prop))
        return true;
    else
        return false;
}

char *url_field(const char *url_str,
                const struct http_parser_url *url,
                enum http_parser_url_fields prop)
{
    char * urlstr = malloc(url->field_data[prop].len + 1);
    if (!urlstr)
        return NULL;
    memcpy(urlstr, url_str + url->field_data[prop].off, url->field_data[prop].len);
    urlstr[url->field_data[prop].len] = '\0';
    return urlstr;
}


static int32_t request_url_cb(http_parser *p, const char *buf, size_t len)
{
    struct turbo_parser_wrapper *nw = (struct turbo_parser_wrapper*)p->data;

    nw->url_str = buf;
    nw->url_sz = len;
    nw->url_rc = http_parser_parse_url(buf, len, 0, &nw->url);
    return 0;
}

static int32_t header_field_cb(http_parser *p, const char *buf, size_t len)
{
    struct turbo_parser_wrapper *nw = (struct turbo_parser_wrapper*)p->data;
    struct turbo_key_value_field *kv_field;
    void *ptr;

    switch(nw->_state){
    case NOTHING:
    case VALUE:
        if (nw->hkv_sz == nw->hkv_mem){
        ptr = realloc(
                        nw->hkv,
                    sizeof(struct turbo_key_value_field *) *
                        (nw->hkv_sz + 10));
            if (!ptr)
            return -1;
            nw->hkv = ptr;
            nw->hkv_mem += 10;
        }
        kv_field = malloc(sizeof(struct turbo_key_value_field));
        if (!kv_field)
            return -1;
        kv_field->key = buf;
        kv_field->key_sz = len;
        nw->hkv[nw->hkv_sz] = kv_field;
        break;
    case FIELD:
        break;
    }
    nw->_state = FIELD;
    return 0;
}

static int32_t header_value_cb(http_parser *p, const char *buf, size_t len)
{
    struct turbo_parser_wrapper *nw = (struct turbo_parser_wrapper*)p->data;
    struct turbo_key_value_field *kv_field;

    switch(nw->_state){
    case FIELD:
        kv_field = nw->hkv[nw->hkv_sz];
        kv_field->value = buf;
        kv_field->value_sz = len;
        nw->hkv_sz++;
        break;
    case VALUE:
    case NOTHING:
        break;
    }
    nw->_state = VALUE;
    return 0;
}

int32_t headers_complete_cb (http_parser *p)
{
    struct turbo_parser_wrapper *nw = (struct turbo_parser_wrapper*)p->data;
    nw->headers_complete = true;
    return 0;
}

static http_parser_settings settings =
{.on_message_begin = 0
 ,.on_header_field = header_field_cb
 ,.on_header_value = header_value_cb
 ,.on_url = request_url_cb
 ,.on_body = 0
 ,.on_headers_complete = headers_complete_cb
 ,.on_message_complete = 0
};

struct turbo_parser_wrapper *turbo_parser_wrapper_init(
        const char* data,
        size_t len,
        int32_t type)
{
    struct turbo_parser_wrapper *dest = malloc(
                sizeof(struct turbo_parser_wrapper));
    if (!dest)
        return 0;
    dest->parser.data = dest;
    dest->url_str = 0;
    dest->hkv = 0;
    dest->hkv_sz = 0;
    dest->hkv_mem = 0;
    dest->headers_complete = false;
    dest->_state = NOTHING;
    if (type == 0)
        http_parser_init(&dest->parser, HTTP_REQUEST);
    else
        http_parser_init(&dest->parser, HTTP_RESPONSE);
    dest->parsed_sz = http_parser_execute(&dest->parser, &settings, data, len);
    return dest;
}

void turbo_parser_wrapper_exit(struct turbo_parser_wrapper *src)
{
    size_t i = 0;
    for (; i < src->hkv_sz; i++){
        free(src->hkv[i]);
    }
    free(src->hkv);
    free(src);
}

bool turbo_parser_check(struct turbo_parser_wrapper *s)
{
    if (s->parser.http_errno != 0 || s->parsed_sz == 0)
        return false;
    else
        return true;
}


char* turbo_websocket_mask(const char* mask32, const char* in, size_t sz)
{
    size_t i = 0;
    char* buf = malloc(sz);

    if (!buf)
        return 0;
    for (i = 0; i < sz; i++) {
        buf[i] = in[i] ^ mask32[i % 4];
    }
    return buf;
 }

uint64_t turbo_bswap_u64(uint64_t swap)
{
    uint64_t swapped;

    swapped = ENDIAN_SWAP_U64(swap);
    return swapped;
}
