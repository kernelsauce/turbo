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

#include <malloc.h>
#include <string.h>
#include <assert.h>
#include <stdint.h>
#include <stdbool.h>

#include "http_parser.h"
#include "http_parser_ffi_wrap.h"


extern bool url_field_is_set(const struct http_parser_url *url, enum http_parser_url_fields prop)
{
    if (url->field_set & (1 << prop))
        return true;
    else
        return false;
}

extern char *url_field(const char *url_str, const struct http_parser_url *url, enum http_parser_url_fields prop)
{
    return strndup(url_str + url->field_data[prop].off, url->field_data[prop].len);
}


static int request_url_cb (http_parser *p, const char *buf, size_t len)
{
    struct nonsence_parser_wrapper *nw = (struct nonsence_parser_wrapper*)p->data;
    int32_t rc;

    nw->url_str = strndup(buf, len);
    if (!nw->url_str)
        return -1;

    rc = http_parser_parse_url(buf, len, 0, &nw->url);
    nw->http_parsed_with_rc = rc;

    return 0;
}

static int header_field_cb (http_parser *p, const char *buf, size_t len)
{
    struct nonsence_parser_wrapper *nw = (struct nonsence_parser_wrapper*)p->data;
    struct nonsence_key_value_field *kv_field;
    void *ptr;

    switch(nw->header_state){
    case NOTHING:
    case VALUE:
        ptr = realloc(nw->header_key_values, sizeof(struct nonsence_key_value_field *) * (nw->header_key_values_sz + 1));
        if (ptr){
            nw->header_key_values = ptr;
        }
        else
            return -1;

        kv_field = malloc(sizeof(struct nonsence_key_value_field));
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

static int header_value_cb (http_parser *p, const char *buf, size_t len)
{
    struct nonsence_parser_wrapper *nw = (struct nonsence_parser_wrapper*)p->data;
    struct nonsence_key_value_field *kv_field;
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


static int body_cb (http_parser *p, const char *buf, size_t len)
{
    struct nonsence_parser_wrapper *nw = (struct nonsence_parser_wrapper*)p->data;

    nw->body = strndup(buf, len);
    if (!nw->body)
        return -1;

    return 0;
}


int headers_complete_cb (http_parser *p)
{
    struct nonsence_parser_wrapper *nw = (struct nonsence_parser_wrapper*)p->data;
    nw->headers_complete = true;
    return 0;
}

int message_complete_cb (http_parser *p)
{
    struct nonsence_parser_wrapper *nw = (struct nonsence_parser_wrapper*)p->data;
    nw->finished = true;
    return 0;
}



static http_parser_settings settings =
  {.on_message_begin = 0
  ,.on_header_field = header_field_cb
  ,.on_header_value = header_value_cb
  ,.on_url = request_url_cb
  ,.on_body = body_cb
  ,.on_headers_complete = headers_complete_cb
  ,.on_message_complete = message_complete_cb
  };


extern size_t nonsence_parser_wrapper_init(struct nonsence_parser_wrapper *dest, const char* data, size_t len)
{
    size_t parsed_sz;

    dest->parser.data = dest;
    dest->body = 0;
    dest->url_str = 0;
    dest->header_key_values = 0;
    dest->header_key_values_sz = 0;
    dest->header_state = NOTHING;

    http_parser_init(&dest->parser, HTTP_REQUEST);
    parsed_sz = http_parser_execute(&dest->parser, &settings, data, len);

    return parsed_sz;
}

extern void nonsence_parser_wrapper_exit(struct nonsence_parser_wrapper *src)
{
    int32_t i = 0;
    free(src->body);
    free(src->url_str);
    for (; i < src->header_key_values_sz; i++){
        free(src->header_key_values[i]->value);
        free(src->header_key_values[i]->key);
        free(src->header_key_values[i]);
    }
    free(src->header_key_values);

#ifdef PARANOID
    if (src){
        memset(src, 0, sizeof(struct nonsence_parser_wrapper));
    }
#endif

}
