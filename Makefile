PREFIX ?= /usr/local

LUA_MODULEDIR = $(PREFIX)/share/lua/5.1
LUA_LIBRARYDIR = $(PREFIX)/lib/lua/5.1	

LUAJIT_VERSION?=2.0.2
LUAJIT_LIBRARYDIR = $(PREFIX)/lib/lua/5.1
LUAJIT_MODULEDIR = $(PREFIX)/share/luajit-$(LUAJIT_VERSION)

all:
	make -C deps/http-parser

clean:
	make -C deps/http-parser  clean

install:
	mkdir -p $(LUA_MODULEDIR)/turbo
	mkdir -p $(LUAJIT_MODULEDIR)/turbo
	cp -R turbo/* $(LUA_MODULEDIR)/turbo
	cp turbo.lua $(LUA_MODULEDIR)
	cp -R turbo/* $(LUAJIT_MODULEDIR)/turbo
	cp turbo.lua $(LUAJIT_MODULEDIR)
	make -C deps/http-parser install PREFIX=$(PREFIX)
