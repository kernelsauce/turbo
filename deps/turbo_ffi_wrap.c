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
#include <malloc.h>
#include <string.h>
#include <assert.h>
#include <stdbool.h>
#include <limits.h>

#include "http_parser.h"
#include "turbo_ffi_wrap.h"

// not sure why our compiler doesn't seem to know about this prototype
char *strndup(const char *s, size_t n);

#ifndef TURBO_NO_SSL
#include <openssl/x509v3.h>
#include <openssl/ssl.h>

#define MIN(a,b) (((a)<(b))?(a):(b))
#define MAX(a,b) (((a)>(b))?(a):(b))

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

static int matches_subject_alternative_name(
        const char *hostname,
        const X509 *server_cert)
{
    int result = MatchNotFound;
    int i;
    int san_names_nb = -1;
    int hostname_is_domain;
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

int validate_hostname(const char *hostname, const SSL *server){
    int result;
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
    return strndup(url_str + url->field_data[prop].off,
                   url->field_data[prop].len);
}


static int request_url_cb(http_parser *p, const char *buf, size_t len)
{
    struct turbo_parser_wrapper *nw = (struct turbo_parser_wrapper*)p->data;
    int rc;

    nw->url_str = strndup(buf, len);
    if (!nw->url_str)
        return -1;
    rc = http_parser_parse_url(buf, len, 0, &nw->url);
    nw->http_parsed_with_rc = rc;
    return 0;
}

static int header_field_cb(http_parser *p, const char *buf, size_t len)
{
    struct turbo_parser_wrapper *nw = (struct turbo_parser_wrapper*)p->data;
    struct turbo_key_value_field *kv_field;
    void *ptr;

    switch(nw->header_state){
    case NOTHING:
    case VALUE:
        ptr = realloc(
                    nw->header_key_values,
                    sizeof(struct turbo_key_value_field *) *
                    (nw->header_key_values_sz + 1));
        if (ptr){
            nw->header_key_values = ptr;
        }
        else
            return -1;

        kv_field = malloc(sizeof(struct turbo_key_value_field));
        if (!kv_field)
            return -1;
        kv_field->key = strndup(buf, len);
        nw->header_key_values[nw->header_key_values_sz] = kv_field;
        break;
    case FIELD:
        break;
    }

    nw->header_state = FIELD;
    return 0;
}

static int header_value_cb(http_parser *p, const char *buf, size_t len)
{
    struct turbo_parser_wrapper *nw = (struct turbo_parser_wrapper*)p->data;
    struct turbo_key_value_field *kv_field;
    char *ptr;

    switch(nw->header_state){
    case FIELD:
        kv_field = nw->header_key_values[nw->header_key_values_sz];
        ptr = strndup(buf, len);
        if (!ptr)
            return -1;
        kv_field->value = ptr;
        nw->header_key_values_sz++;
        break;
    case VALUE:
    case NOTHING:
        break;
    }
    nw->header_state = VALUE;
    return 0;
}

int headers_complete_cb (http_parser *p)
{
    struct turbo_parser_wrapper *nw = (struct turbo_parser_wrapper*)p->data;
    nw->headers_complete = true;
    return 0;
}

int message_complete_cb (http_parser *p)
{
    struct turbo_parser_wrapper *nw = (struct turbo_parser_wrapper*)p->data;
    nw->finished = true;
    return 0;
}



static http_parser_settings settings =
{.on_message_begin = 0
 ,.on_header_field = header_field_cb
 ,.on_header_value = header_value_cb
 ,.on_url = request_url_cb
 ,.on_body = 0
 ,.on_headers_complete = headers_complete_cb
 ,.on_message_complete = message_complete_cb
};


size_t turbo_parser_wrapper_init(
        struct turbo_parser_wrapper *dest,
        const char* data, size_t len, int type)
{
    size_t parsed_sz;

    dest->parser.data = dest;
    dest->url_str = 0;
    dest->header_key_values = 0;
    dest->header_key_values_sz = 0;
    dest->header_state = NOTHING;
    if (type == 0)
        http_parser_init(&dest->parser, HTTP_REQUEST);
    else
        http_parser_init(&dest->parser, HTTP_RESPONSE);
    parsed_sz = http_parser_execute(&dest->parser, &settings, data, len);
    return parsed_sz;
}

void turbo_parser_wrapper_exit(struct turbo_parser_wrapper *src)
{
    int i = 0;
    free(src->url_str);
    for (; i < src->header_key_values_sz; i++){
        free(src->header_key_values[i]->value);
        free(src->header_key_values[i]->key);
        free(src->header_key_values[i]);
    }
    free(src->header_key_values);

#ifdef PARANOID
    if (src){
        memset(src, 0, sizeof(struct turbo_parser_wrapper));
    }
#endif

}

