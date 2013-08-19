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
INSTALL_TFFI_WRAP_SOSHORT= ltffi_wrap.so
INSTALL_TFFI_WRAP_SONAME= $(INSTALL_TFFI_WRAP_SOSHORT).$(TVERSION)
INSTALL_TFFI_WRAP_DYN= $(INSTALL_LIB)/$(INSTALL_TFFI_WRAP_SONAME)
INSTALL_TFFI_WRAP_SHORT= $(INSTALL_LIB)/$(INSTALL_TFFI_WRAP_SOSHORT)
TEST_DIR = tests
LUA_MODULEDIR = $(PREFIX)/share/lua/5.1
LUA_LIBRARYDIR = $(PREFIX)/lib/lua/5.1	
INC = -I$(HTTP_PARSERDIR)/
LDFLAGS = -lcrypto -lssl

LUAJIT_VERSION?=2.0.2
LUAJIT_LIBRARYDIR = $(PREFIX)/lib/lua/5.1
LUAJIT_MODULEDIR = $(PREFIX)/share/luajit-$(LUAJIT_VERSION)

all:
	make -C deps/http-parser library

clean:
	make -C deps/http-parser clean
	$(RM) $(INSTALL_TFFI_WRAP_SOSHORT)

uninstall:
	@echo "==== Uninstalling Turbo.lua ===="
	$(UNINSTALL) $(INSTALL_TFFI_WRAP_SHORT) $(INSTALL_TFFI_WRAP_DYN)
	$(LDCONFIG) $(INSTALL_LIB)
	$(UNINSTALL) $(LUA_MODULEDIR)/turbo/
	$(UNINSTALL) $(LUAJIT_MODULEDIR)/turbo/
	$(RM) $(LUA_MODULEDIR)/turbo.lua
	$(RM) $(LUAJIT_MODULEDIR)/turbo.lua
	@echo "==== Turbo.lua uinstalled. Welcome back. ===="

install:
	@echo "==== Installing Turbo.lua v$(TVERSION) to: ===="
	@echo "==== $(LUAJIT_LIBRARYDIR) and ===="
	@echo "==== $(LUAJIT_MODULEDIR) ===="
	
	$(MKDIR) $(LUA_MODULEDIR)/turbo
	$(MKDIR) $(LUAJIT_MODULEDIR)/turbo
	$(CP_R) turbo/* $(LUA_MODULEDIR)/turbo
	$(CP_R) turbo.lua $(LUA_MODULEDIR)
	$(CP_R) -R turbo/* $(LUAJIT_MODULEDIR)/turbo
	$(CP_R) turbo.lua $(LUAJIT_MODULEDIR)
	@echo "==== Building 3rdparty modules ===="
	make -C $(HTTP_PARSERDIR) library
	$(CC) $(INC) -shared -fPIC -O3 -Wall $(HTTP_PARSERDIR)/libhttp_parser.o $(TDEPS)/turbo_ffi_wrap.c -o $(INSTALL_TFFI_WRAP_SOSHORT) $(LDFLAGS)
	@echo "==== Installing libturbo_parser ===="
	test -f $(INSTALL_TFFI_WRAP_SOSHORT) && \
	$(INSTALL_X) $(INSTALL_TFFI_WRAP_SOSHORT) $(INSTALL_TFFI_WRAP_DYN) && \
	$(LDCONFIG) $(INSTALL_LIB) && \
	$(SYMLINK) $(INSTALL_TFFI_WRAP_SONAME) $(INSTALL_TFFI_WRAP_SHORT)
	@echo "==== Successfully installed Turbo.lua $(TVERSION) to $(PREFIX) ===="
	
test:
	@echo "==== Running tests for Turbo.lua. NOTICE: busted module is required ===="
	cd $(TEST_DIR) && busted run_all_test.lua
