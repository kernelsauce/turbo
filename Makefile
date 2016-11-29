########
## Turbo.lua Makefile for installation.
## Copyright (C) 2013 John Abrahamsen.
## See LICENSE file for license information.
########

uname_S := $(shell sh -c 'uname -s 2>/dev/null || echo not')

CC= gcc
ifeq ($(uname_S),Darwin)
CC= clang
endif

RM= rm -f
UNINSTALL= rm -rf
MKDIR= mkdir -p
RMDIR= rmdir 2>/dev/null
SYMLINK= ln -sf
INSTALL_X= install -m 0755
INSTALL_F= install -m 0644
CP_R= cp -r
LDCONFIG= ldconfig -n
TAR = tar -zcvf

rwildcard=$(wildcard $1$2) $(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2))
ALL_LUA_FILES := $(call rwildcard,./,*.lua)
ALL_LUAC_FILES := $(call rwildcard,./,*.luac)
MAJVER=  2
MINVER=  1
MICVER=  0
TVERSION= $(MAJVER).$(MINVER).$(MICVER)
PREFIX ?= /usr/local
TDEPS= deps
HTTP_PARSERDIR = $(TDEPS)/http-parser
INSTALL_LIB= $(PREFIX)/lib
INSTALL_BIN= $(PREFIX)/bin
TEST_DIR = tests
PACKAGE_DIR = package/turbo
LUA_MODULEDIR = $(PREFIX)/share/lua/5.1
LUA_LIBRARYDIR = $(PREFIX)/lib/lua/5.1
LUAJIT_VERSION?=2.0.4
LUAJIT_LIBRARYDIR = $(PREFIX)/lib/lua/5.1
LUAJIT_MODULEDIR = $(PREFIX)/share/luajit-$(LUAJIT_VERSION)
INC = -I$(HTTP_PARSERDIR)/
CFLAGS = -O3 -Wall -g
MYCFLAGS = $(CFLAGS)
MYCPPFLAGS = $(CPPFLAGS)
MYLDFLAGS = $(LDFLAGS)

# For Windows builds.
INSTALL_TFFI_WRAP_SOSHORT= libtffi_wrap.dll

ifeq ($(uname_S),Linux)
	INSTALL_TFFI_WRAP_SOSHORT= libtffi_wrap.so
	MYCPPFLAGS += -fPIC
endif

ifeq ($(uname_S),Darwin)
	INSTALL_TFFI_WRAP_SOSHORT= libtffi_wrap.dylib
	MYCPPFLAGS += -I/usr/include/malloc
endif
INSTALL_TFFI_WRAP_SONAME= $(INSTALL_TFFI_WRAP_SOSHORT).$(TVERSION)
INSTALL_TFFI_WRAP_DYN= $(INSTALL_LIB)/$(INSTALL_TFFI_WRAP_SONAME)
INSTALL_TFFI_WRAP_SHORT= $(INSTALL_LIB)/$(INSTALL_TFFI_WRAP_SOSHORT)

ifeq ($(SSL), axTLS)
# axTLS only uses axtls lib from luajit
# Don't link with crypto or ssl if using axTLS
# C wrapper needs TURBO_NO_SSL set in order
# to not include any of the OpenSSL wrapper
	MYCPPFLAGS += -DTURBO_NO_SSL=1
endif
ifeq ($(SSL), none)
	# No SSL option.
	MYCPPFLAGS += -DTURBO_NO_SSL=1
endif
ifeq ($(SSL),)
	# Default to OpenSSL
	SSL=openssl
endif
ifeq ($(SSL), openssl)
	# Link OpenSSL
	MYLDFLAGS += -lcrypto -lssl
endif

all:
	$(MAKE) -C deps/http-parser library
	$(CC) $(INC) -shared $(MYCFLAGS) $(MYCPPFLAGS) $(HTTP_PARSERDIR)/libhttp_parser.o $(TDEPS)/turbo_ffi_wrap.c -o $(INSTALL_TFFI_WRAP_SOSHORT) $(MYLDFLAGS)

clean:
	$(MAKE) -C deps/http-parser clean
	$(RM) $(INSTALL_TFFI_WRAP_SOSHORT)
	rm -rf $(PACKAGE_DIR)
	$(RM) $(ALL_LUAC_FILES)
	rm -rf *.dSYM

uninstall:
	@echo "==== Uninstalling Turbo.lua ===="
ifeq ($(uname_S),Linux)
	$(UNINSTALL) $(INSTALL_TFFI_WRAP_SHORT) $(INSTALL_TFFI_WRAP_DYN)
	$(LDCONFIG) $(INSTALL_LIB)
endif
ifeq ($(uname_S),Darwin)
	$(UNINSTALL) $(INSTALL_TFFI_WRAP_SHORT)
endif
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
	$(MKDIR) $(INSTALL_BIN)
	$(MKDIR) $(LUA_MODULEDIR)/turbo
	$(MKDIR) $(LUAJIT_MODULEDIR)/turbo
	$(CP_R) turbo/* $(LUA_MODULEDIR)/turbo
	$(CP_R) turbo.lua $(LUA_MODULEDIR)
	$(CP_R) turbovisor.lua $(LUA_MODULEDIR)
	$(CP_R) turbo/* $(LUAJIT_MODULEDIR)/turbo
	$(CP_R) turbo.lua $(LUAJIT_MODULEDIR)
	$(CP_R) turbovisor.lua $(LUAJIT_MODULEDIR)
	$(INSTALL_X) bin/turbovisor $(INSTALL_BIN)
	@echo "==== Building 3rdparty modules ===="
	make -C deps/http-parser library
	$(CC) $(INC) -shared $(MYCFLAGS) $(MYCPPFLAGS) $(HTTP_PARSERDIR)/libhttp_parser.o $(TDEPS)/turbo_ffi_wrap.c -o $(INSTALL_TFFI_WRAP_SOSHORT) $(MYLDFLAGS)
	@echo "==== Installing libtffi_wrap ===="
ifeq ($(uname_S),Linux)
	test -f $(INSTALL_TFFI_WRAP_SOSHORT) && \
	$(INSTALL_X) $(INSTALL_TFFI_WRAP_SOSHORT) $(INSTALL_TFFI_WRAP_DYN) && \
	$(LDCONFIG) $(INSTALL_LIB) && \
	$(SYMLINK) $(INSTALL_TFFI_WRAP_SONAME) $(INSTALL_TFFI_WRAP_SHORT)
endif
ifeq ($(uname_S),Darwin)
	$(INSTALL_X) $(INSTALL_TFFI_WRAP_SOSHORT) $(INSTALL_TFFI_WRAP_SHORT)
endif
	@echo "==== Successfully installed Turbo.lua $(TVERSION) to $(PREFIX) ===="

bytecode:
	@echo "==== Creating bytecode for Turbo.lua v$(TVERSION) ===="
	for f in $(ALL_LUA_FILES); do \
		luajit -b -g "$$f" "$$f"c; \
	done
	@echo "==== Successfully created bytecode for Turbo.lua v$(TVERSION) ===="

minimize: bytecode
	rm -rf package
	@echo "==== Creating minimal Turbo.lua v$(TVERSION) ===="
	$(MKDIR) $(PACKAGE_DIR)/turbo/structs
	$(CP_R) $(INSTALL_TFFI_WRAP_SOSHORT) $(PACKAGE_DIR)
	$(CP_R) turbo.luac $(PACKAGE_DIR)
	$(CP_R) turbovisor.luac $(PACKAGE_DIR)
	$(CP_R) turbo/*.luac $(PACKAGE_DIR)/turbo
	$(CP_R) turbo/structs/*.luac $(PACKAGE_DIR)/turbo/structs
	$(MKDIR) $(PACKAGE_DIR)/turbo/3rdparty/middleclass
	$(CP_R) turbo/3rdparty/*.luac $(PACKAGE_DIR)/turbo/3rdparty/
	$(CP_R) turbo/3rdparty/middleclass/*.luac $(PACKAGE_DIR)/turbo/3rdparty/middleclass
	rename "s/\.luac$$/\.lua/" $(PACKAGE_DIR)/*.luac $(PACKAGE_DIR)/turbo/*.luac $(PACKAGE_DIR)/turbo/3rdparty/*.luac $(PACKAGE_DIR)/turbo/3rdparty/middleclass/*.luac $(PACKAGE_DIR)/turbo/structs/*.luac
	@echo "==== Successfully created minimal Turbo.lua $(TVERSION) ===="

bcodeinstall: package
	@echo "==== Installing Turbo.lua v$(TVERSION) by bytecode to: ===="
	@echo "==== $(LUAJIT_LIBRARYDIR) and ===="
	@echo "==== $(LUAJIT_MODULEDIR) ===="
	$(MKDIR) $(INSTALL_LIB)
	$(MKDIR) $(LUA_MODULEDIR)/turbo
	$(MKDIR) $(LUAJIT_MODULEDIR)/turbo
	$(CP_R) package/turbo/* $(LUA_MODULEDIR)
	$(CP_R) package/turbo/* $(LUAJIT_MODULEDIR)
	$(INSTALL_X) bin/turbovisor $(INSTALL_BIN)
	@echo "==== Building 3rdparty modules ===="
	make -C deps/http-parser library
	$(CC) $(INC) -shared $(MYCFLAGS) $(MYCPPFLAGS) $(HTTP_PARSERDIR)/libhttp_parser.o $(TDEPS)/turbo_ffi_wrap.c -o $(INSTALL_TFFI_WRAP_SOSHORT) $(MYLDFLAGS)
	@echo "==== Installing libturbo_parser ===="
	test -f $(INSTALL_TFFI_WRAP_SOSHORT) && \
	$(INSTALL_X) $(INSTALL_TFFI_WRAP_SOSHORT) $(INSTALL_TFFI_WRAP_DYN) && \
	$(LDCONFIG) $(INSTALL_LIB) && \
	$(SYMLINK) $(INSTALL_TFFI_WRAP_SONAME) $(INSTALL_TFFI_WRAP_SHORT)
	@echo "==== Successfully installed Turbo.lua $(TVERSION) to $(PREFIX) ===="

package: all minimize
	@echo "==== Packaging minimal Turbo.lua v$(TVERSION) ===="
	$(TAR) turbo.$(MAJVER).$(MINVER).$(MICVER).tar.gz package
	@echo "==== Created turbo.$(MAJVER).$(MINVER).$(MICVER).tar.gz package: ===="
	md5sum turbo.$(MAJVER).$(MINVER).$(MICVER).tar.gz

test:
	@echo "==== Running tests for Turbo.lua. NOTICE: busted module is required ===="
	export TURBO_TEST_SSL=1; valgrind busted
	luajit examples/helloworld.lua &
	sleep 1
	wget http://127.0.0.1:8888/
	test -f index.html
	rm -f index.html
	pkill luajit
	@echo "==== Successfully ran all tests for Turbo.lua $(TVERSION) ===="
