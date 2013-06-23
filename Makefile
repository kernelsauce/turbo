TURBO_PREFIX ?= /usr/local
LUA_MODULEDIR = $(TURBO_PREFIX)/share/lua/5.1
LUA_LIBRARYDIR = $(TURBO_PREFIX)/lib/lua/5.1	

all:
	make -C 3rdparty/http-parser

clean:
	make -C 3rdparty/http-parser  clean

install:
	sudo mkdir -p $(LUA_MODULEDIR)/turbo
	sudo cp -R turbo/* $(LUA_MODULEDIR)/turbo
	sudo cp turbo.lua $(LUA_MODULEDIR)
	cd 3rdparty/http-parser; sudo make install
