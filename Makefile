########
## Turbo.lua Makefile for installation.
## Copyright (C) 2013 John Abrahamsen. 
## See LICENSE file for license information.
########

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
HTTPPARSER= $(TDEPS)/http-parser
INSTALL_LIB= $(PREFIX)/lib
INSTALL_HTTPPARSER_SOSHORT= libturbo_parser.so
INSTALL_HTTPPARSER_SONAME= $(INSTALL_HTTPPARSER_SOSHORT).$(TVERSION)
INSTALL_HTTPPARSER_DYN= $(INSTALL_LIB)/$(INSTALL_HTTPPARSER_SONAME)
INSTALL_HTTPPARSER_SHORT= $(INSTALL_LIB)/$(INSTALL_HTTPPARSER_SOSHORT)
TEST_DIR = tests
LUA_MODULEDIR = $(PREFIX)/share/lua/5.1
LUA_LIBRARYDIR = $(PREFIX)/lib/lua/5.1	

LUAJIT_VERSION?=2.0.2
LUAJIT_LIBRARYDIR = $(PREFIX)/lib/lua/5.1
LUAJIT_MODULEDIR = $(PREFIX)/share/luajit-$(LUAJIT_VERSION)

all:
	make -C deps/http-parser

clean:
	make -C deps/http-parser  clean
	
uninstall:
	@echo "==== Uninstalling Turbo.lua ===="
	$(UNINSTALL) $(INSTALL_HTTPPARSER_SHORT) $(INSTALL_HTTPPARSER_DYN)
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
	make -C $(HTTPPARSER) library_turbo PREFIX=$(PREFIX)
	@echo "==== Installing libturbo_parser ===="
	cd $(HTTPPARSER) && test -f $(INSTALL_HTTPPARSER_SOSHORT) && \
	$(INSTALL_X) $(INSTALL_HTTPPARSER_SOSHORT) $(INSTALL_HTTPPARSER_DYN) && \
	$(LDCONFIG) $(INSTALL_LIB) && \
	$(SYMLINK) $(INSTALL_HTTPPARSER_SONAME) $(INSTALL_HTTPPARSER_SHORT)
	@echo "==== Successfully installed Turbo.lua $(TVERSION) to $(PREFIX) ===="
	
test:
	@echo "==== Running tests for Turbo.lua. NOTICE: busted module is required ===="
	cd $(TEST_DIR) && busted run_all_test.lua
