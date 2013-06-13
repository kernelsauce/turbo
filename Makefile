LUA_MODULEDIR = /usr/local/share/lua/5.1/
LUA_LIBRARYDIR = /usr/local/lib/lua/5.1/	

clean:
	cd 3rdparty/http-parser; make clean

install:
	sudo mkdir -p $(LUA_MODULEDIR)turbo
	sudo cp -R turbo/* $(LUA_MODULEDIR)turbo
	sudo cp turbo.lua $(LUA_MODULEDIR)
	cd 3rdparty/http-parser; sudo make install
