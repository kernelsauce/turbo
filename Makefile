LUA_MODULEDIR = /usr/local/share/lua/5.1/
LUA_LIBRARYDIR = /usr/local/lib/lua/5.1/	

clean:
	cd 3rdparty/http-parser; make clean

install:
	sudo cp -R nonsence/* $(LUA_MODULEDIR)
	cd 3rdparty/http-parser; sudo make install