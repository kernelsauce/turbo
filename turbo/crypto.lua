--- Turbo Web Cryto module
-- C defs for LuaJIT FFI and wrappers.
--
-- Copyright 2011, 2012, 2013 John Abrahamsen
-- Inclusion of axTLS library in 2013 by Jeff Solinsky
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

if not _G.TURBO_SSL and not _G.TURBO_AXTLS then
    return setmetatable({},
    {
    __index = function(t, k)
        error("TURBO_SSL is not defined and you are trying to use SSL.")
    end,
    __call  = function(t, k)
        error("TURBO_SSL is not defined and you are trying to use SSL.")
    end
    })
end

-- __Global value__ _G.TURBO_SSL allows the user to enable the SSL module.
-- __Global value__ _G.TURBO_AXTLS allows the user to enable axTLS instead of OpenSSL
if not (_G.TURBO_SSL or _G.TURBO_AXTLS) then
    return true
end

local ffi = require "ffi"

local crypto = {} -- crypto namespace
require "turbo.cdef"

local lssl  -- will load openssl or axtls library as lssl



if _G.TURBO_AXTLS then
    _G.TURBO_SSL = true -- make both flags true when using AXTLS
                        -- to prevent needing to check both flags
            -- in other places
    local util = require"turbo.util"

    -- to be compatible with the way openssl works in non-blocking mode
    -- must return this error when no bytes can be read
    -- since it is checked in iostream to determine that the read would block
    crypto.SSL_ERROR_WANT_READ =        2

    -- AXTLS crypto library
    lssl = ffi.load "axtls"
    local SSL_SERVER_VERIFY_LATER = 0x00020000 -- use for client mode, certificate verified later with ssl_verify_cert
    local SSL_CONNECT_IN_PARTS = 0x00800000  -- for non-blocking operation
    local SSL_DISPLAY_BYTES = 0x00100000
    local SSL_DISPLAY_CERTS = 0x00200000

    local SSL_OBJ_X509_CERT = 1
    local SSL_OBJ_X509_CACERT = 2
    local SSL_OBJ_RSA_KEY = 3
    local SSL_OK = 0
    local SSL_NOT_OK = -1
    local SSL_ERROR_DEAD = -2
    local SSL_CLOSE_NOTIFY = -3

    local SSL_X509_CERT_COMMON_NAME             = 0
    local SSL_X509_CERT_ORGANIZATION            = 1
    local SSL_X509_CERT_ORGANIZATIONAL_NAME     = 2
    local SSL_X509_CA_CERT_COMMON_NAME          = 3
    local SSL_X509_CA_CERT_ORGANIZATION         = 4
    local SSL_X509_CA_CERT_ORGANIZATIONAL_NAME  = 5

    function crypto.ssl_create_context(cert_file, prv_file, sslv, ctx_options)
        local ctx
        local err = 0
        if not ctx_options then
            ctx_options = SSL_CONNECT_IN_PARTS
        else
            bit.bor(ctx_options, SSL_CONNECT_IN_PARTS)
        end

        ctx = lssl.ssl_ctx_new(ctx_options, 5)

        if ctx == 0 then
            return (-272), "can't load our key/certificate pair, so die"
        end
        ffi.gc(ctx, lssl.ssl_ctx_free)

        -- if certifactes are set, load them and verify.
        if type(cert_file) == "string" and type(prv_file) == "string" then
            -- load certificate file
            err = lssl.ssl_obj_load(ctx, SSL_OBJ_X509_CERT, cert_file, ffi.cast("const char*",0))
            if err ~= SSL_OK then
                lssl.ssl_display_error(err)
                return err, "can't load cert file: " .. cert_file
            end
            -- load private key file
            err = lssl.ssl_obj_load(ctx, SSL_OBJ_RSA_KEY, prv_file, ffi.cast("const char*",0))
            if err ~= SSL_OK then
                lssl.ssl_display_error(err)
                return err, "Can't load private key file: " .. prv_file
            end
            -- TODO: if cert doesn't exist
            -- TODO:    generate x509 cert from private key file
            -- TODO: else
            -- TODO:    Check if pub and priv key matches each other similar to OpenSSL's SSL_CTX_check_private_key(ctx)
        end

        return err, ctx
    end

    --- Create a client type SSL context.
    -- @param cert_file (optional) Certificate file
    -- @param prv_file (optional) Key file
    -- @param ca_cert_path (optional) Path to CA certificates, or the system wide
    -- in /etc/ssl/certs/ca-certificates.crt will be used.
    -- @param verify (optional) Verify the hosts certificate with CA.
    -- @param sslv (optional) SSL version to use.
    -- @return Return code. 0 if successfull, else a error code and a SSL
    -- error string, or -1 and a error string.
    -- @return Allocated SSL_CTX *. Must not be freed. It is garbage collected.
    function crypto.ssl_create_client_context(cert_file, prv_file, ca_cert_path, verify, sslv)
        local err, ctx
        local ctx_options = 0 -- SSL_DISPLAY_BYTES  -- display bytes for debugging

        -- Use standardish path to ca-certificates if not specified by user.
        -- May not be present on all Unix systems.
        ca_cert_path = ca_cert_path or "/etc/ssl/certs/ca-certificates.crt"

        if not verify then
            -- doesn't stop handshake if cert doesn't verify
            -- verification can still happen later by calling ssl_verify_cert
            -- without this option verification will happen automatically
            -- during the handshake

            --
            bit.bor(ctx_options, SSL_SERVER_VERIFY_LATER)
        end

        err, ctx = crypto.ssl_create_context(cert_file, prv_file, sslv, ctx_options)

        if err == SSL_OK then
            -- if verify is set
            if verify then
                -- load all the CA certificates in ca_cert_path
                err = lssl.ssl_obj_load(ctx, SSL_OBJ_X509_CACERT, ca_cert_path, ffi.cast("char*",0));
                if err ~= SSL_OK then
                    lssl.ssl_display_error(err)
                    return err, "can't load CA cert file: " .. ca_cert_path
                end
            end
        end
        return err, ctx
    end

    --- Create a server type SSL context.
    -- @param cert_file Certificate file (public key)
    -- @param prv_file Key file (private key)
    -- @param sslv (optional) SSL version to use.
    -- @return Return code. 0 if successfull, else a OpenSSL error code and a SSL
    -- error string, or -1 and a error string.
    -- @return Allocated SSL_CTX *. Must not be freed. It is garbage collected.
    function crypto.ssl_create_server_context(cert_file, prv_file, sslv)
        local ctx
        local ctx_options = 0 -- SSL_DISPLAY_BYTES + SSL_DISPLAY_CERTS -- display bytes and certs for debugging
        local err = 0

        if not cert_file then
            return -1, "No cert file given in arguments";
        elseif not prv_file then
            return -1, "No priv file given in arguments";
        end
        err, ctx = crypto.ssl_create_context(cert_file, prv_file, sslv, ctx_options)

        return err, ctx;
    end

    function crypto.ssl_new(ctx, fd_sock, client)
        local ssl
        -- local err

        if client then
            -- last two params are const uint8_t *session_id, uint8_t sess_id_size
            -- may want to support sessions for faster repeated client requests
            ssl = lssl.ssl_client_new(ctx, fd_sock, ffi.cast("char *",0), 0)
        else
            ssl = lssl.ssl_server_new(ctx, fd_sock)
        end
        if ssl == nil then
            error(string.format(
                    "Could not do SSL handshake. Failed to create SSL*. %s",
                    "(no error code available)"))
        end
        ffi.gc(ssl, lssl.ssl_free)

        return ssl
    end

    -- return true if hostname is valid, else return false
    function crypto.validate_hostname(hostname, ssl_server)
        local dnsname
        local dnsindex
        local wildhostname

        -- check for hostname matching subjective alt dnsnames
        dnsindex = 0
        while true do
            dnsname = lssl.ssl_get_cert_subject_alt_dnsname(ssl_server, dnsindex)
            if dnsname == ffi.cast("const char*",0) then
                break
            end

            dnsindex = dnsindex + 1
            dnsname = ffi.string(dnsname)

            -- if starting with *. (wildcard) indicating wildcard subdomain
            if (string.byte(dnsname,1) == string.byte'*') and
               (string.byte(dnsname,2) == string.byte'.') then
                if not wildhostname then
                    -- get the wildcard hostname by stripping off the leading component
                    wildhostname = string.match(hostname,"[.](.*)$")
                end

                if ( util.strcasecmp(wildhostname,
                            string.sub(dnsname,3)) == 0 ) then
                    return true
                end
            else
                if util.strcasecmp(hostname,dnsname) == 0 then
                    return true
                end
            end
        end

        -- check if the host name matches the common name
        dnsname = lssl.ssl_get_cert_dn(ssl_server, SSL_X509_CERT_COMMON_NAME)
        dnsname = ffi.string(dnsname)
        if util.strcasecmp(hostname,dnsname) == 0 then
            return true
        end
        return false
    end

    function crypto.ssl_do_handshake(SSLIOStream)
    local client = SSLIOStream._ssl_options._type == 1
    local ssl = SSLIOStream._ssl
    local err

    -- call read to continue the handshaking
    err = lssl.ssl_read(ssl, NULL)
    if err == SSL_OK then
        -- check the handshake status to see that the handshake is complete
        err = lssl.ssl_handshake_status(ssl)
        if err == SSL_OK then
            if client and SSLIOStream._ssl_verify then
                -- verify that the hostname is valid by
                --       checking that the host name SSLIOStream._ssl_hostname
                --       matches the domain name or alt domain names in the
                --       x509 cert received from the server which can be retrieved
                --       using:
                --         const char* ssl_get_cert_dn(const SSL *ssl, int component)
                --         where component = SSL_X509_CERT_COMMON_NAME
                --         const char* ssl_get_cert_subject_alt_dnsname(const SSL *ssl, int dnsindex)
                --         where dnsindex starts at 0 and increases in a loop until the function returns null

                if not crypto.validate_hostname(SSLIOStream._ssl_hostname, ssl) then
                    error("SSL certficate hostname validation failed")
                end
            end
            return true
        end
    end

    if err ~= SSL_NOT_OK then
        lssl.ssl_display_error(err)
        if err == SSL_ERROR_DEAD then
            error("SSL connection died during handshake")
        else
            error("Could not do SSL handshake. err = "..err)
        end
    end

    return false
    end

    --- Initialize the SSL library.
    -- Can be called multiple times without causing any pain. If the library is
    -- already loaded it will pass.
    function crypto.ssl_init()
        if not _G._TURBO_SSL_INITED then
            _TURBO_SSL_INITED = true
            -- NOTE: may want to load error strings here to use with error codes
        end
    end

    --- Write data to a SSL connection.
    -- @param ssl (SSL *) OpenSSL struct SSL ptr.
    -- @param buf (const char *) Buffer to send.
    -- @param sz (Number) Bytes to send from buffer.
    function crypto.SSL_write(ssl, buf, sz)
        local ret
        if ssl == nil or buf == nil then
            error("SSL_write passed null pointer.")
        end

        ret = lssl.ssl_write(ssl, buf, sz)
        if ret <= 0 then
            crypto.last_err = ret
            return -1
        end
        return ret
    end

    --- Read data from a SSL connection.
    -- @param ssl (SSL *) OpenSSL struct SSL ptr.
    -- @param buf (char *) Buffer to read to.
    -- @param sz (Number) Bytes to maximum read into buffer.
    function crypto.SSL_read(ssl, buf, sz)
        local len
        if ssl == nil or buf == nil then
            error("SSL_read passed null pointer.")
        end

        ppbuf = ffi.new("char*[1]")
        len = lssl.ssl_read(ssl,ppbuf)
        if len <= 0 then
            if len == 0 then
                crypto.last_err = crypto.SSL_ERROR_WANT_READ
            elseif len == SSL_CLOSE_NOTIFY then
                return 0
            else
                crypto.last_err = len
            end
            return -1
        end
        if len > sz then
            len = sz
            -- probably want to trigger an error here since this would
            -- mean we are dropping bytes from the stream
            error("axTLS ERROR: ssl_read, read more bytes than calling buffer can hold, bytes would be dropped...")
        end
        -- copy out the bytes
        if len > 0 then
            ffi.copy(buf, ppbuf[0], len)
        end
        return len
    end

    function crypto.ERR_get_error()
        if not crypto.last_err then
            return 0
        end
        return crypto.last_err
    end

    --- Convert OpenSSL unsigned long error to string.
    -- @param rc unsigned long error from OpenSSL library.
    -- @returns Lua string.
    function crypto.ERR_error_string(rc)
        lssl.ssl_display_error(rc)
        if err == SSL_ERROR_DEAD then
            return "SSL connection died."
        end
        -- TODO: lookup error string or add a function to axTLS to get the error
        --       string rather than have it printed to stdout...
        return ""
    end
    function crypto.SSL_get_error(ssl,ret)
        local rc = crypto.ERR_get_error()
        if rc ~= crypto.SSL_ERROR_WANT_READ then
            crypto.ERR_error_string(rc)
        end
        return rc
    end
else
    lssl = ffi.load("ssl")
    local libtffi_loaded, libtffi = pcall(ffi.load, "tffi_wrap")
    if not libtffi_loaded then
        libtffi_loaded, libtffi =
            pcall(ffi.load, "/usr/local/lib/libtffi_wrap.so")
        if not libtffi_loaded then
            error("Could not load libtffi_wrap.so. \
            Please run makefile and ensure that installation is done correct.")
        end
    end

    crypto.X509_FILETYPE_PEM =          1
    crypto.X509_FILETYPE_ASN1 =         2
    crypto.X509_FILETYPE_DEFAULT =      3
    crypto.SSL_FILETYPE_ASN1 =          crypto.X509_FILETYPE_ASN1
    crypto.SSL_FILETYPE_PEM =           crypto.X509_FILETYPE_PEM
    crypto.SSL_ERROR_NONE =             0
    crypto.SSL_ERROR_SSL =              1
    crypto.SSL_ERROR_WANT_READ =        2
    crypto.SSL_ERROR_WANT_WRITE =       3
    crypto.SSL_ERROR_WANT_X509_LOOKUP = 4
    crypto.SSL_ERROR_SYSCALL =          5
    crypto.SSL_ERROR_ZERO_RETURN =      6
    crypto.SSL_ERROR_WANT_CONNECT =     7
    crypto.SSL_ERROR_WANT_ACCEPT =      8
    -- use either SSL_VERIFY_NONE or SSL_VERIFY_PEER, the last 2 options are 'ored'
    -- with SSL_VERIFY_PEER if they are desired
    crypto.SSL_VERIFY_NONE =        0x00
    crypto.SSL_VERIFY_PEER =        0x01
    crypto.SSL_VERIFY_FAIL_IF_NO_PEER_CERT = 0x02
    crypto.SSL_VERIFY_CLIENT_ONCE =     0x04
    crypto.validate =
    {
        ["MatchFound"] = 0,
        ["MatchNotFound"] = 1,
        ["NoSANPresent"] = 2,
        ["MalformedCertificate"] = 3,
        ["Error"] = 4
    }

    crypto.ERR_get_error = lssl.ERR_get_error
    crypto.SSL_get_error = lssl.SSL_get_error
    crypto.lib = lssl

    --- Convert OpenSSL unsigned long error to string.
    -- @param rc unsigned long error from OpenSSL library.
    -- @returns Lua string.
    function crypto.ERR_error_string(rc)
        local buf = ffi.new("char[256]")
        lssl.ERR_error_string_n(rc, buf, ffi.sizeof(buf))
        return ffi.string(buf)
    end

    --- Initialize the SSL library.
    -- Can be called multiple times without causing any pain. If the library is
    -- already loaded it will pass.
    function crypto.ssl_init()
        if not _G._TURBO_SSL_INITED then
           _TURBO_SSL_INITED = true
            lssl.SSL_load_error_strings()
            lssl.SSL_library_init()
            lssl.OPENSSL_add_all_algorithms_noconf()
        end
    end
    if _G.TURBO_SSL then
        crypto.ssl_init()
    end

    --- Create a client type SSL context.
    -- @param cert_file (optional) Certificate file
    -- @param prv_file (optional) Key file
    -- @param ca_cert_path (optional) Path to CA certificates, or the system wide
    -- in /etc/ssl/certs/ca-certificates.crt will be used.
    -- @param verify (optional) Verify the hosts certificate with CA.
    -- @param sslv (optional) SSL version to use.
    -- @return Return code. 0 if successfull, else a OpenSSL error code and a SSL
    -- error string, or -1 and a error string.
    -- @return Allocated SSL_CTX *. Must not be freed. It is garbage collected.
    function crypto.ssl_create_client_context(cert_file, prv_file, ca_cert_path, verify, sslv)
        local meth
        local ctx
        local err = 0
        -- Use standardish path to ca-certificates if not specified by user.
        -- May not be present on all Unix systems.
        ca_cert_path = ca_cert_path or "/etc/ssl/certs/ca-certificates.crt"
        meth = sslv or lssl.SSLv23_client_method()
        if meth == nil then
            err = lssl.ERR_peek_error()
            lssl.ERR_clear_error()
            return err, crypto.ERR_error_string(err)
        end
        ctx = lssl.SSL_CTX_new(meth)
        if ctx == nil then
            err = lssl.ERR_peek_error()
            lssl.ERR_clear_error()
            return err, crypto.ERR_error_string(err)
        else
            ffi.gc(ctx, lssl.SSL_CTX_free)
        end
        -- If client certificates are set, load them and verify.
        if type(cert_file) == "string" and type(prv_file) == "string" then
            if lssl.SSL_CTX_use_certificate_file(ctx, cert_file,
                crypto.SSL_FILETYPE_PEM) <= 0 then
                err = lssl.ERR_peek_error()
                lssl.ERR_clear_error()
                return err, crypto.ERR_error_string(err)
            end
            if lssl.SSL_CTX_use_PrivateKey_file(ctx, prv_file,
                crypto.SSL_FILETYPE_PEM) <= 0 then
                err = lssl.ERR_peek_error()
                lssl.ERR_clear_error()
                return err, crypto.ERR_error_string(err)
            end
            -- Check if pub and priv key matches each other.
            if lssl.SSL_CTX_check_private_key(ctx) ~= 1 then
                return -1, "Private and public keys does not match"
            end
        end
        if verify == true then
            if lssl.SSL_CTX_load_verify_locations(ctx, ca_cert_path, nil) ~= 1 then
                err = lssl.ERR_peek_error()
                lssl.ERR_clear_error()
                return err, crypto.ERR_error_string(err)
            end
            lssl.SSL_CTX_set_verify(ctx, crypto.SSL_VERIFY_PEER, nil);
        end
        return err, ctx
    end

    --- Create a server type SSL context.
    -- @param cert_file Certificate file (public key)
    -- @param prv_file Key file (private key)
    -- @param sslv (optional) SSL version to use.
    -- @return Return code. 0 if successfull, else a OpenSSL error code and a SSL
    -- error string, or -1 and a error string.
    -- @return Allocated SSL_CTX *. Must not be freed. It is garbage collected.
    function crypto.ssl_create_server_context(cert_file, prv_file, sslv)
        local meth
        local ctx
        local err = 0

        if not cert_file then
            return -1, "No cert file given in arguments";
        elseif not prv_file then
            return -1, "No priv file given in arguments";
        end
        meth = sslv or lssl.SSLv23_server_method()
        if meth == nil then
            err = lssl.ERR_peek_error()
            lssl.ERR_clear_error()
            return err, crypto.ERR_error_string(err)
        end
        ctx = lssl.SSL_CTX_new(meth)
        if ctx == nil then
            err = lssl.ERR_peek_error()
            lssl.ERR_clear_error()
            return err, crypto.ERR_error_string(err)
        else
            ffi.gc(ctx, lssl.SSL_CTX_free)
        end
        if lssl.SSL_CTX_use_certificate_file(ctx, cert_file,
            crypto.SSL_FILETYPE_PEM) <= 0 then
            err = lssl.ERR_peek_error()
            lssl.ERR_clear_error()
            return err, crypto.ERR_error_string(err)
        end
        if lssl.SSL_CTX_use_PrivateKey_file(ctx, prv_file,
            crypto.SSL_FILETYPE_PEM) <= 0 then
            err = lssl.ERR_peek_error()
            lssl.ERR_clear_error()
            return err, crypto.ERR_error_string(err)
        end
        return err, ctx
    end

    function crypto.ssl_new(ctx, fd_sock, client)
        local ssl
        local err

        ssl = crypto.lib.SSL_new(ctx)
        if ssl == nil then
            err = crypto.lib.ERR_peek_error()
            crypto.lib.ERR_clear_error()
            error(string.format(
                "Could not do SSL handshake. Failed to create SSL*. %s",
                crypto.ERR_error_string(err)))
        end

        ffi.gc(ssl, crypto.lib.SSL_free)

        if crypto.lib.SSL_set_fd(ssl, fd_sock) <= 0 then
            err = crypto.lib.ERR_peek_error()
            crypto.lib.ERR_clear_error()
            error(string.format(
                "Could not do SSL handshake. \
                    Failed to set socket fd to SSL*. %s",
                crypto.ERR_error_string(err)))
        end

        if client then
            crypto.lib.SSL_set_connect_state(ssl)
        else
            crypto.lib.SSL_set_accept_state(ssl)
        end
        return ssl
    end

    function crypto.ssl_do_handshake(SSLIOStream)
        local err = 0
        local errno
        local rc = 0
        local ssl = SSLIOStream._ssl
        local client = SSLIOStream._ssl_options._type == 1

        -- This method might be called multiple times if we recieved EINPROGRESS
        -- or equaivalent on prior calls. The OpenSSL documentation states that
        -- SSL_do_handshake should be called again when its needs are satisfied.
        rc = crypto.lib.SSL_do_handshake(ssl)
        if rc <= 0 then
            if client and SSLIOStream._ssl_verify then
                local verify_err = crypto.lib.SSL_get_verify_result(ssl)
                if verify_err ~= 0 then
                    error(
                        string.format(
                            "SSL certificate chain validation failed: %s",
                            ffi.string(
                                crypto.lib.X509_verify_cert_error_string(
                                    verify_err))))
                end
            end
            err = crypto.lib.SSL_get_error(ssl, rc)
            -- In case the socket is O_NONBLOCK break out when we get
            -- SSL_ERROR_WANT_* or equal syscall return code.
            if err == crypto.SSL_ERROR_WANT_READ or
                err == crypto.SSL_ERROR_WANT_READ then
                return false
            elseif err == crypto.SSL_ERROR_SYSCALL then
                -- Error on socket.
                errno = ffi.errno()
                if errno == EWOULDBLOCK or errno == EINPROGRESS then
                    return false
                elseif errno ~= 0 then
                    local fd = SSLIOStream.socket
                    SSLIOStream:close()
                    error(
                        string.format("Error when reading from fd %d. \
                            Errno: %d. %s",
                            fd,
                            errno,
                            socket.strerror(errno)))
                else
                    -- Popular belief ties this branch to disconnects before
                    -- handshake is completed.
                    local fd = SSLIOStream.socket
                    SSLIOStream:close()
                    error(string.format(
                        "Could not do SSL handshake. Client connection closed.",
                        fd,
                        errno,
                        socket.strerror(errno)))
                end
            elseif err == crypto.SSL_ERROR_SSL then
                err = crypto.lib.ERR_peek_error()
                crypto.lib.ERR_clear_error()
                error(string.format("Could not do SSL handshake. SSL error. %s",
                    crypto.ERR_error_string(err)))
            else
                error(string.format(
                    "Could not do SSL handshake. SSL_do_hanshake returned %d",
                    err))
            end
        else
            if client and SSLIOStream._ssl_verify then
                rc = libtffi.validate_hostname(SSLIOStream._ssl_hostname, ssl)
                if rc ~= crypto.validate.MatchFound then
                    error("SSL certficate hostname validation failed, rc " ..
                    tonumber(rc))
                end
            end
        end
        return true
    end

    --- Write data to a SSL connection.
    -- @param ssl (SSL *) OpenSSL struct SSL ptr.
    -- @param buf (const char *) Buffer to send.
    -- @param sz (Number) Bytes to send from buffer.
    function crypto.SSL_write(ssl, buf, sz)
        if ssl == nil or buf == nil then
            error("SSL_write passed null pointer.")
        end
        return lssl.SSL_write(ssl, buf, sz)
    end

    --- Read data from a SSL connection.
    -- @param ssl (SSL *) OpenSSL struct SSL ptr.
    -- @param buf (char *) Buffer to read to.
    -- @param sz (Number) Bytes to maximum read into buffer.
        function crypto.SSL_read(ssl, buf, sz)
            if ssl == nil or buf == nil then
            error("SSL_read passed null pointer.")
        end
        return lssl.SSL_read(ssl, buf, sz)
    end
end

return crypto
