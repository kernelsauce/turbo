########
## Turbo.lua Makefile for installation.
## Copyright (C) 2013 John Abrahamsen.
## See LICENSE file for license information.
########

CC ?= gcc
RM= rm -f
UNINSTALL= rm -rf
MKDIR= mkdir -p
RMDIR= rmdir 2>/dev/null
SYMLINK= ln -sf
INSTALL_X= install -m 0755
INSTALL_F= install -m 0644
CP_R= cp -r
LDCONFIG= ldconfig -n
PREFIX ?= /usr/local

MAJVER=  1
MINVER=  0
MICVER=  0
TVERSION= $(MAJVER).$(MINVER).$(MICVER)
TDEPS= deps
HTTP_PARSERDIR = $(TDEPS)/http-parser
INSTALL_LIB= $(PREFIX)/lib
INSTALL_BIN= $(PREFIX)/bin
INSTALL_TFFI_WRAP_SOSHORT= libtffi_wrap.so
INSTALL_TFFI_WRAP_SONAME= $(INSTALL_TFFI_WRAP_SOSHORT).$(TVERSION)
INSTALL_TFFI_WRAP_DYN= $(INSTALL_LIB)/$(INSTALL_TFFI_WRAP_SONAME)
INSTALL_TFFI_WRAP_SHORT= $(INSTALL_LIB)/$(INSTALL_TFFI_WRAP_SOSHORT)
TEST_DIR = tests
LUA_MODULEDIR = $(PREFIX)/share/lua/5.1
LUA_LIBRARYDIR = $(PREFIX)/lib/lua/5.1
INC = -I$(HTTP_PARSERDIR)/
CFLAGS=

ifeq ($(SSL), none)
	# No SSL option.
	CFLAGS += -DTURBO_NO_SSL=1
endif
ifeq ($(SSL),)
	# Default to OpenSSL
	SSL=openssl
endif
ifeq ($(SSL), openssl)
	# Link OpenSSL
	LDFLAGS += -lcrypto -lssl
endif

LUAJIT_VERSION?=2.0.2
LUAJIT_LIBRARYDIR = $(PREFIX)/lib/lua/5.1
LUAJIT_MODULEDIR = $(PREFIX)/share/luajit-$(LUAJIT_VERSION)

all:
	make -C deps/http-parser library
	$(CC) $(INC) -shared -fPIC -O3 -Wall $(CFLAGS) $(HTTP_PARSERDIR)/libhttp_parser.o $(TDEPS)/turbo_ffi_wrap.c -o $(INSTALL_TFFI_WRAP_SOSHORT) $(LDFLAGS)

clean:
	make -C deps/http-parser clean
	$(RM) $(INSTALL_TFFI_WRAP_SOSHORT)

uninstall:
	@echo "==== Uninstalling Turbo.lua ===="
	$(UNINSTALL) $(INSTALL_TFFI_WRAP_SHORT) $(INSTALL_TFFI_WRAP_DYN)
	$(LDCONFIG) $(INSTALL_LIB)
	$(UNINSTALL) $(LUA_MODULEDIR)/turbo/
	$(UNINSTALL) $(LUAJIT_MODULEDIR)/turbo/
	$(UNINSTALL) $(INSTALL_BIN)/turbovisor
	$(RM) $(LUA_MODULEDIR)/turbo.lua
	$(RM) $(LUAJIT_MODULEDIR)/turbo.lua
	$(RM) $(LUAJIT_MODULEDIR)/turbovisor.lua
	@echo "==== Turbo.lua uinstalled. Welcome back. ===="

install:
	@echo "==== Installing Turbo.lua v$(TVERSION) to: ===="
	@echo "==== $(LUAJIT_LIBRARYDIR) and ===="
	@echo "==== $(LUAJIT_MODULEDIR) ===="
	$(MKDIR) $(INSTALL_LIB)
	$(MKDIR) $(LUA_MODULEDIR)/turbo
	$(MKDIR) $(LUAJIT_MODULEDIR)/turbo
	$(CP_R) turbo/* $(LUA_MODULEDIR)/turbo
	$(CP_R) turbo.lua $(LUA_MODULEDIR)
	$(CP_R) turbovisor.lua $(LUA_MODULEDIR)
	$(CP_R) -R turbo/* $(LUAJIT_MODULEDIR)/turbo
	$(CP_R) turbo.lua $(LUAJIT_MODULEDIR)
	$(CP_R) turbovisor.lua $(LUAJIT_MODULEDIR)
	$(INSTALL_X) bin/turbovisor $(INSTALL_BIN)
	@echo "==== Building 3rdparty modules ===="
	make -C $(HTTP_PARSERDIR) library
	$(CC) $(INC) -shared -fPIC -O3 -Wall $(CFLAGS) $(HTTP_PARSERDIR)/libhttp_parser.o $(TDEPS)/turbo_ffi_wrap.c -o $(INSTALL_TFFI_WRAP_SOSHORT) $(LDFLAGS)
	@echo "==== Installing libturbo_parser ===="
	test -f $(INSTALL_TFFI_WRAP_SOSHORT) && \
	$(INSTALL_X) $(INSTALL_TFFI_WRAP_SOSHORT) $(INSTALL_TFFI_WRAP_DYN) && \
	$(LDCONFIG) $(INSTALL_LIB) && \
	$(SYMLINK) $(INSTALL_TFFI_WRAP_SONAME) $(INSTALL_TFFI_WRAP_SHORT)
	@echo "==== Successfully installed Turbo.lua $(TVERSION) to $(PREFIX) ===="

test:
	@echo "==== Running tests for Turbo.lua. NOTICE: busted module is required ===="
	cd $(TEST_DIR) && busted -l /usr/local/bin/luajit run_all_test.lua
	luajit examples/helloworld.lua &
	sleep 1
	wget http://127.0.0.1:8888/
	test -f index.html
	rm -f index.html
	pkill luajit
	@echo "==== Successfully ran all tests for Turbo.lua $(TVERSION) ===="
