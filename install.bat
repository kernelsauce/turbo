SET CURRENT_PATH_PREINSTALL=%CD%
setx PATH "%PATH%;C:\turbo.lua;C:\turbo.lua\luarocks\2.2" /M
@powershell -NoProfile -ExecutionPolicy unrestricted -Command "iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))" && SET PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin
choco install visualstudio2013professional git mingw openssl.light gnuwin
SET PATH=%PATH%;C:\Program Files (x86)\Git\cmd;C:\GnuWin\bin;C:\tools\mingw64\bin;C:\Program Files (x86)\Windows Kits\8.1\bin\x64;C:\turbo.lua;C:\turbo.lua\luarocks\2.2
SET VS120COMNTOOLS=C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\Tools\
rm -rf C:\turbo.lua
mkdir C:\turbo.lua
cd C:\turbo.lua
mkdir src
cd src

git clone https://github.com/kernelsauce/turbo.git
cd C:\turbo.lua\src\turbo
mingw32-make SSL=none
mv libtffi_wrap.so libtffi_wrap.dll
setx TURBO_LIBTFFI "C:\turbo.lua\src\turbo\libtffi_wrap.dll" /M
setx TURBO_LIBSSL "C:\Program Files\OpenSSL\libeay32.dll" /M
SET TURBO_LIBTFFI=C:\turbo.lua\src\turbo\libtffi_wrap.dll
SET TURBO_LIBSSL=C:\Program Files\OpenSSL\libeay32.dll


cd C:\turbo.lua\src
git clone http://luajit.org/git/luajit-2.0.git
cd C:\turbo.lua\src\luajit-2.0\src
call "C:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\vcvarsall.bat" amd64
call msvcbuild
cp luajit.exe C:\turbo.lua
cp lua51.dll C:\turbo.lua

cd C:\turbo.lua\src
git clone https://github.com/keplerproject/luarocks.git
cd C:\turbo.lua\src\luarocks
SET LUA_PATH=C:\turbo.lua\rocks\share\lua\5.1\?.lua;C:\turbo.lua\rocks\share\lua\5.1\?\init.lua;C:\turbo.lua\src\turbo\?.lua;C:\turbo.lua\src\turbo\turbo\?.lua
SET LUA_CPATH=C:\turbo.lua\rocks\lib\lua\5.1\?.dll
setx LUA_PATH "%LUA_PATH%" /M
setx LUA_CPATH "%LUA_CPATH%" /M
call install.bat /TREE C:\turbo.lua\rocks\ /P C:\turbo.lua\luarocks\ /INC C:\turbo.lua\src\luajit-2.0\src /LIB C:\turbo.lua\src\luajit-2.0\src /LUA C:\turbo.lua /Q
call luarocks install luasocket
call luarocks install luafilesystem

cd %CURRENT_PATH_PREINSTALL%
echo ===========================
echo Turbo is now installed. Try it by running 'luajit C:\turbo.lua\src\turbo\examples\helloworld.lua' and point your browser to http://localhost:8888.
echo Have a nice day!
echo ===========================

