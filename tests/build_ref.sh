#!/bin/bash
# Builds the C reference (original Lua 5.1.4 sources) used by the comparison scripts:
#   $REFDIR/{win32,win64}/{lua5.1.dll,liblua5.1.a,lua.exe,luac.exe}   MinGW-w64 gcc -O2
#   $REFDIR/linux64/{liblua5.1.so.0,lua,luac}                         gcc -O2 (Linux only)
#   $REFDIR/linuxarm64/{liblua5.1.so.0,lua,luac}                      gcc -O2 (native on ARM64,
#                                                     else aarch64-linux-gnu-gcc)
#   $REFDIR/{macx64,macarm64}/{liblua5.1.dylib,lua,luac}             cc -O2 -arch x86_64 / arm64
#                                                     (macOS with the Xcode command-line tools)
# Linux reference: luaconf.h with LUA_USE_POSIX + LUA_USE_DLOPEN (as "make linux",
# without readline); lua is linked to liblua5.1.so.0 (found next to it) so a
# Pascal liblua5.1.so.0 can be dropped in; luac has Lua linked in.
# macOS reference: the same options (dlopen, not the old dyld API of "make macosx");
# liblua5.1.dylib has the install name @rpath/liblua5.1.dylib and lua finds it
# next to itself.
# usage: build_ref.sh /path/to/lua-5.1.4 [win32 win64 linux64 linuxarm64 macx64 macarm64]
set -e
. "$(dirname "$0")/env.sh"
SRC=$(cd "${1:?usage: build_ref.sh /path/to/lua-5.1.4 [targets]}/src" && pwd); shift
CORE="lapi.c lcode.c ldebug.c ldo.c ldump.c lfunc.c lgc.c llex.c lmem.c lobject.c lopcodes.c
lparser.c lstate.c lstring.c ltable.c ltm.c lundump.c lvm.c lzio.c lauxlib.c lbaselib.c ldblib.c
liolib.c lmathlib.c loslib.c ltablib.c lstrlib.c loadlib.c linit.c"
cd "$SRC"
TARGETS=${*:-"win32 win64"}
for tgt in $TARGETS; do
  if [ "$tgt" = linux64 ] || [ "$tgt" = linuxarm64 ]; then
    CC=gcc
    if [ "$tgt" = linuxarm64 ] && [ "$(uname -m)" != aarch64 ]; then CC=aarch64-linux-gnu-gcc; fi
    O=$REFDIR/$tgt; mkdir -p "$O"; D="-O2 -DLUA_USE_POSIX -DLUA_USE_DLOPEN"
    $CC $D -fPIC -shared -Wl,-soname,liblua5.1.so.0 -o "$O/liblua5.1.so.0" $CORE -lm -ldl
    ln -sf liblua5.1.so.0 "$O/liblua5.1.so"
    $CC $D -o "$O/lua" lua.c -L"$O" -llua5.1 -Wl,-rpath,'$ORIGIN' -lm
    $CC $D -o "$O/luac" luac.c print.c $CORE -lm
    echo "built $O"; continue
  fi
  if [ "$tgt" = macx64 ] || [ "$tgt" = macarm64 ]; then
    [ "$tgt" = macx64 ] && CC="cc -arch x86_64" || CC="cc -arch arm64"
    O=$REFDIR/$tgt; mkdir -p "$O"; D="-O2 -DLUA_USE_POSIX -DLUA_USE_DLOPEN"
    $CC $D -dynamiclib -install_name @rpath/liblua5.1.dylib -o "$O/liblua5.1.dylib" $CORE
    $CC $D -o "$O/lua" lua.c -L"$O" -llua5.1 -Wl,-rpath,@executable_path
    $CC $D -o "$O/luac" luac.c print.c $CORE
    echo "built $O"; continue
  fi
  case $tgt in win32) a="i686 win32";; win64) a="x86_64 win64";; esac
  set -- $a; O=$REFDIR/$2; mkdir -p "$O"
  $1-w64-mingw32-gcc -O2 -DLUA_BUILD_AS_DLL -shared -o "$O/lua5.1.dll" $CORE \
      -Wl,--out-implib,"$O/liblua5.1.a" -static-libgcc
  $1-w64-mingw32-gcc -O2 -DLUA_BUILD_AS_DLL -o "$O/lua.exe" lua.c "$O/liblua5.1.a"
  $1-w64-mingw32-gcc -O2 -o "$O/luac.exe" luac.c print.c $CORE
  echo "built $O"
done
