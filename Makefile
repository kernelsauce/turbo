########
## Turbo.lua Makefile for installation.
## Copyright (C) 2013 John Abrahamsen. 
## See LICENSE file for license information.
########

MAJVER=  1
MINVER=  0
MICVER=  0
TVERSION= $(MAJVER).$(MINVER).$(MICVER)

CC ?= gcc

HTTP_PARSERDIR = ./deps/http-parser
PREFIX ?= /usr/local
INSTALL_LIB ?= $(PREFIX)/lib
LUAJIT_VERSION ?= 2.0.2
LUAJIT_LIBRARYDIR = $(PREFIX)/lib/lua/5.1
LUAJIT_MODULEDIR = $(PREFIX)/share/luajit-$(LUAJIT_VERSION)
LUA_MODULEDIR = $(PREFIX)/share/lua/5.1
LUA_LIBRARYDIR = $(PREFIX)/lib/lua/5.1	

CFLAGS = -O3 -Wall -I$(HTTP_PARSERDIR)/
LDFLAGS = -lcrypto -lssl

LIBTFFI_SOSHORT = libtffi_wrap.so
LIBTFFI_SONAME = $(LIBTFFI_SOSHORT).$(TVERSION)

all: 
	make -C $(HTTP_PARSERDIR) library
	$(CC) $(CFLAGS) -shared -fPIC $(HTTP_PARSERDIR)/libhttp_parser.o \
		./deps/turbo_ffi_wrap.c -o $(LIBTFFI_SOSHORT) $(LDFLAGS)

clean:
	make -C $(HTTP_PARSERDIR) clean
	rm -f $(LIBTFFI_SOSHORT)

test:
	@echo "==== Running tests for Turbo.lua. NOTICE: busted module is required ===="
	cd ./test && busted run_all_test.lua

install: all installmsg install_libtffi_wrap install_luamodules
	@echo "==== Successfully installed Turbo.lua v$(TVERSION) to $(PREFIX) ===="
	
uninstall:
	@echo "==== Uninstalling Turbo.lua ===="
	rm -rf $(INSTALL_LIB)/$(LIBTFFI_SOSHORT) \
		$(INSTALL_LIB)/$(LIBTFFI_SONAME) \
		$(LUAJIT_MODULEDIR)/turbo \
		$(LUA_MODULEDIR)/turbo \
		$(LUA_MODULEDIR)/turbo.lua \
		$(LUAJIT_MODULEDIR)/turbo.lua
	ldconfig -n $(INSTALL_LIB)
	@echo "==== Turbo.lua uninstalled. Welcome back. ===="

installmsg:
	@echo "==== Installing Turbo.lua v$(TVERSION) to: $(PREFIX) ===="
	@echo "==== $(LUAJIT_LIBRARYDIR) and ===="
	@echo "==== $(LUAJIT_MODULEDIR) ===="

install_libtffi_wrap:
	mkdir -p $(INSTALL_LIB)
	test -f $(LIBTFFI_SOSHORT) && \
	install -m 0755 $(LIBTFFI_SOSHORT) $(INSTALL_LIB)/$(LIBTFFI_SONAME) && \
	ldconfig -n $(INSTALL_LIB) && \
	ln -sf $(INSTALL_LIB)/$(LIBTFFI_SONAME) $(INSTALL_LIB)/$(LIBTFFI_SOSHORT)

install_luamodules:
	mkdir -p $(LUA_MODULEDIR) $(LUAJIT_MODULEDIR)/turbo
	cp -R turbo/* $(LUA_MODULEDIR)/turbo
	cp turbo.lua $(LUA_MODULEDIR)
	cp -R turbo/* $(LUAJIT_MODULEDIR)/turbo
	cp turbo.lua $(LUAJIT_MODULEDIR)

