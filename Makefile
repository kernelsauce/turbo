LUA_MODULEDIR = /usr/local/share/lua/5.1/
LUA_LIBRARYDIR = /usr/local/lib/lua/5.1/

all:
	cd nixio; make 

clean: 
	cd nixio; make clean

install:
	cd nixio; sudo make install
	sudo cp -R nonsence/* $(LUA_MODULEDIR)
	cd 3rdparty/http-parser; sudo make install