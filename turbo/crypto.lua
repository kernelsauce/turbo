--[[ Turbo Web Cryto module

Copyright 2011, 2012, 2013 John Abrahamsen

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.		]]

local ffi = require "ffi"

local crypto = {} -- crypto namespace
local lssl = ffi.load("ssl")

if not _G._SSL_H then
_G._SSL_H = 1
ffi.cdef [[

/* Typedef structs to void as we never access their members and they are massive
in ifdef's etc and are best left as blackboxes! */
typedef void SSL_METHOD;
typedef void SSL_CTX;
typedef void SSL;

const SSL_METHOD *SSLv3_server_method(void);	/* SSLv3 */
const SSL_METHOD *SSLv3_client_method(void);	/* SSLv3 */
const SSL_METHOD *SSLv23_method(void);		/* SSLv3 but can rollback to v2 */
const SSL_METHOD *SSLv23_server_method(void);	/* SSLv3 but can rollback to v2 */
const SSL_METHOD *SSLv23_client_method(void);	/* SSLv3 but can rollback to v2 */
const SSL_METHOD *TLSv1_method(void);		/* TLSv1.0 */
const SSL_METHOD *TLSv1_server_method(void);	/* TLSv1.0 */
const SSL_METHOD *TLSv1_client_method(void);	/* TLSv1.0 */
const SSL_METHOD *TLSv1_1_method(void);		/* TLSv1.1 */
const SSL_METHOD *TLSv1_1_server_method(void);	/* TLSv1.1 */
const SSL_METHOD *TLSv1_1_client_method(void);	/* TLSv1.1 */    
const SSL_METHOD *TLSv1_2_method(void);		/* TLSv1.2 */
const SSL_METHOD *TLSv1_2_server_method(void);	/* TLSv1.2 */
const SSL_METHOD *TLSv1_2_client_method(void);	/* TLSv1.2 */

/* From openssl/ssl.h */
void OPENSSL_add_all_algorithms_noconf(void);
void SSL_load_error_strings(void);
void ERR_free_strings(void);
int SSL_library_init(void);
void EVP_cleanup(void);
SSL_CTX *SSL_CTX_new(const SSL_METHOD *meth);
void SSL_CTX_free(SSL_CTX *);
int	SSL_CTX_use_PrivateKey_file(SSL_CTX *ctx, const char *file, int type);
int	SSL_CTX_use_certificate_file(SSL_CTX *ctx, const char *file, int type);
int SSL_CTX_load_verify_locations(SSL_CTX *ctx, const char *CAfile, const char *CApath);

SSL *SSL_new(SSL_CTX *ctx);
void SSL_set_connect_state(SSL *s);
void SSL_set_accept_state(SSL *s);
int SSL_do_handshake(SSL *s);
int	SSL_set_fd(SSL *s, int fd);
int SSL_accept(SSL *ssl);
void SSL_free(SSL *ssl);
int	SSL_accept(SSL *ssl);
int	SSL_connect(SSL *ssl);
int	SSL_read(SSL *ssl,void *buf,int num);
int	SSL_peek(SSL *ssl,void *buf,int num);
int	SSL_write(SSL *ssl,const void *buf,int num);
void SSL_set_verify(SSL *s, int mode,int (*callback)(int ok,void *ctx));
int	SSL_set_cipher_list(SSL *s, const char *str);
int	SSL_get_error(const SSL *s,int ret_code);

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
]]
end

crypto.X509_FILETYPE_PEM =		1
crypto.X509_FILETYPE_ASN1 = 		2
crypto.X509_FILETYPE_DEFAULT =		3
crypto.SSL_FILETYPE_ASN1 =		crypto.X509_FILETYPE_ASN1
crypto.SSL_FILETYPE_PEM	=		crypto.X509_FILETYPE_PEM
crypto.SSL_ERROR_NONE =			0
crypto.SSL_ERROR_SSL =			1
crypto.SSL_ERROR_WANT_READ =		2
crypto.SSL_ERROR_WANT_WRITE =		3
crypto.SSL_ERROR_WANT_X509_LOOKUP =	4
crypto.SSL_ERROR_SYSCALL =		5 -- look at error stack/return value/errno
crypto.SSL_ERROR_ZERO_RETURN =		6
crypto.SSL_ERROR_WANT_CONNECT =		7
crypto.SSL_ERROR_WANT_ACCEPT =		8

crypto.ERR_get_error = lssl.ERR_get_error
crypto.SSL_get_error = lssl.SSL_get_error

--- Initialize the SSL library.
-- Can be called multiple times without causing any pain. If the
-- library is already loaded it will pass.
function crypto.ssl_init()
   if not _G._TURBO_SSL_INITED then
	_TURBO_SSL_INITED = true
	lssl.SSL_load_error_strings()
	lssl.SSL_library_init()
	lssl.OPENSSL_add_all_algorithms_noconf()
    end
end

--- Convert OpenSSL unsigned long error to string.
-- @param rc unsigned long error from OpenSSL library.
-- @returns Lua string.
function crypto.ERR_error_string(rc)
    local buf = ffi.new("char[100]")
    lssl.ERR_error_string_n(rc, buf, ffi.sizeof(buf))
    return ffi.string(buf)
end

--- Simplified SSL_CTX constructor.
-- This function raises errors on failure. If not caught they will exit your program.
-- @param cert_file Certificate file (public key)
-- @param prv_file Key file (private key)
-- @param sslver (optional) SSL version to use.
-- @return Return code. 0 if successfull.
-- @return Allocated SSL_CTX *. Must not be freed. It is garbage collected.
function crypto.ssl_create_server_context(cert_file, prv_file, sslv)
    local meth
    local ctx
    local err = 0
    
    if (not cert_file) then
	return -1;
    elseif (not prv_file) then
	err = lssl.ERR_peek_error()
	lssl.ERR_clear_error()
	return -1;
    end
    meth = sslv or lssl.SSLv23_server_method()
    if meth == nil then
	err = lssl.ERR_peek_error()
	lssl.ERR_clear_error()
	return err
    end
    ctx = lssl.SSL_CTX_new(meth)
    if ctx == nil then
	err = lssl.ERR_peek_error()
	lssl.ERR_clear_error()
	return err
    else
	ffi.gc(ctx, lssl.SSL_CTX_free)
    end    
    if lssl.SSL_CTX_use_certificate_file(ctx, cert_file, crypto.SSL_FILETYPE_PEM) <= 0 then
	err = lssl.ERR_peek_error()
	lssl.ERR_clear_error()
	return err
    end
    if lssl.SSL_CTX_use_PrivateKey_file(ctx, prv_file, crypto.SSL_FILETYPE_PEM) <= 0 then
	err = lssl.ERR_peek_error()
	lssl.ERR_clear_error()
	return err
    end
    return err, ctx
end

--- Wrap a already connected socket with SSL and do handshake.
-- @param fd A connected socket, not already wrapped with SSL.
-- @param ctx A struct SSL_CTX *
-- @return Return code, 0 if successfull. Use ERR_error_string to convert to string.
-- @return A allocated struct SSL *. Must not be freed! It is garbage collected.
function crypto.ssl_wrap_sock(fd, ctx, o_nonblock)
    local err = 0
    local rc = 0
    local ssl = lssl.SSL_new(ctx)
    
    if ssl == nil then
	err = lssl.ERR_peek_error()
	lssl.ERR_clear_error()
	return err
    else
	ffi.gc(ssl, lssl.SSL_free)
    end
    if lssl.SSL_set_fd(ssl, fd) <= 0 then
	err = lssl.ERR_peek_error()
	lssl.ERR_clear_error()
	return err
    end
    lssl.SSL_set_verify(ssl, 0x00, nil);
    lssl.SSL_set_accept_state(ssl)
    while true do
	rc = lssl.SSL_do_handshake(ssl)
	err = lssl.SSL_get_error(ssl, rc)
	-- In case the socket is O_NONBLOCK break out when we get SSL_ERROR_WANT_*.
	if err == crypto.SSL_ERROR_WANT_READ or err == crypto.SSL_ERROR_WANT_READ then
	    if o_nonbblock == true then
		break
	    end
	else
	    break
	end
    end
    if rc < 1 then
	return rc
    end
    return 0, ssl;
end

function crypto.ssl_write(ssl, buf, sz) return tonumber(lssl.SSL_write(ssl, buf, sz)) end
function crypto.ssl_read(ssl, buf, sz) return tonumber(lssl.SSL_read(ssl, buf, sz)) end

return crypto
