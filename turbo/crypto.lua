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
    void OPENSSL_add_all_algorithms_noconf(void);
    void SSL_load_error_strings(void);
    void ERR_free_strings(void);
    int SSL_library_init(void);
    void EVP_cleanup(void);

    /* Typedef structs to void as we never access their members and they are massive
    in ifdef's etc. */
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
   
    SSL_CTX *SSL_CTX_new(const SSL_METHOD *meth);
    void SSL_CTX_free(SSL_CTX *);
    int	SSL_CTX_use_PrivateKey_file(SSL_CTX *ctx, const char *file, int type);
    int	SSL_CTX_use_certificate_file(SSL_CTX *ctx, const char *file, int type);

    SSL *SSL_new(SSL_CTX *ctx);
    int	SSL_set_fd(SSL *s, int fd);
    int SSL_accept(SSL *ssl);
    void SSL_free(SSL *ssl);
    int	SSL_accept(SSL *ssl);
    int	SSL_connect(SSL *ssl);
    int	SSL_read(SSL *ssl,void *buf,int num);
    int	SSL_peek(SSL *ssl,void *buf,int num);
    int	SSL_write(SSL *ssl,const void *buf,int num);
    
    void ERR_clear_error(void);
    char *ERR_error_string(unsigned long e,char *buf);
    void ERR_error_string_n(unsigned long e, char *buf, size_t len);
    const char *ERR_lib_error_string(unsigned long e);
    const char *ERR_func_error_string(unsigned long e);
    const char *ERR_reason_error_string(unsigned long e);
    ]]
end

crypto.X509_FILETYPE_PEM =	1
crypto.X509_FILETYPE_ASN1 = 	2
crypto.X509_FILETYPE_DEFAULT =	3
crypto.SSL_FILETYPE_ASN1 =	crypto.X509_FILETYPE_ASN1
crypto.SSL_FILETYPE_PEM	=	crypto.X509_FILETYPE_PEM

-- Initialize the SSL library.
function crypto.ssl_init()
   if not _G._TURBO_SSL_INITED then
	_TURBO_SSL_INITED = true
	lssl.SSL_load_error_strings()
	lssl.SSL_library_init()
	lssl.OPENSSL_add_all_algorithms_noconf()
    end
end

function crypto.ERR_error_string(rc)
    local buf = ffi.new("char[100]")
    lssl.ERR_error_string_n(rc, buf, ffi.sizeof(buf))
    return ffi.string(buf)
end

-- Simplified SSL_CTX constructor.
function crypto.ssl_create_context(cert_file, prv_file)
    if (not cert_file) then
	error("No SSL certitificate file provided.")
    elseif (not prv_file) then
	error("No SSL private key file provided.")
    end
    local meth = lssl.SSLv3_server_method()
    if (meth == nil) then
	error("Could not create SSLv3 server method.")
    end
    local ctx = lssl.SSL_CTX_new(meth)
    if (ctx == nil) then
	error("Could not create new SSL context.")
    else
	ffi.gc(ctx, lssl.SSL_CTX_free)
    end
    if (lssl.SSL_CTX_use_certificate_file(ctx, cert_file, crypto.SSL_FILETYPE_PEM) <= 0) then
	error("Could not load SSL certificate file: " .. cert_file)
    end
    if (lssl.SSL_CTX_use_PrivateKey_file(ctx, prv_file, crypto.SSL_FILETYPE_PEM) <= 0) then
	error("Could not load SSL private key file: " .. prv_file)
    end
    return ctx
end

function crypto.ssl_wrap_sock(fd, ctx)
    local ssl = lssl.SSL_new(ctx)
    local rc = 0
    if (ssl == nil) then
	return -1, "Could not create new SSL struct."
    else
	ffi.gc(ssl, lssl.SSL_free)
    end
    rc = lssl.SSL_set_fd(ssl, fd)
    if (rc <= 0) then
	return -1, "Could not set fd."
    end
    rc = lssl.SSL_accept(ssl)
    if (rc <= 0) then
	return -1, "Could not do SSL handshake"
    end
    return rc, ssl;
end

function crypto.ssl_write(ssl, buf, sz) return lssl.SSL_write(ssl, buf, sz) end
function crypto.ssl_read(ssl, buf, sz)
    return lssl.SSL_read(ssl, buf, sz)
end

return crypto