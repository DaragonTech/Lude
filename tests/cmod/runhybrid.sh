#!/bin/bash
# Hybrid test: runs t_ctest.lua in demo_hybrid.exe (Lua linked into the EXE,
# LuaHostExports) with ctest.dll loaded through the shim lua5.1.dll - once
# linked against lua5.1.dll, once against lua51.dll (proxy -> shim) - and
# compares with the C lua.exe + C lua5.1.dll.
# usage: runhybrid.sh win32|win64 [hybrid-dir]   (default $PASDIR/<arch>/hybrid)
. "$(dirname "$0")/../env.sh"
A=$1; H=$(cd "${2:-$PASDIR/$A/hybrid}" && pwd)
HERE=$(cd "$(dirname "$0")" && pwd)
CC=$([ "$A" = win32 ] && echo i686 || echo x86_64)-w64-mingw32-gcc
LUAINC=${LUAINC:-$ROOT/../lua-5.1.4/src}
norm() { sed -E 's/0x[0-9a-fA-F]+|[0-9A-Fa-f]{8,16}/ADDR/g; s/e([+-])0([0-9]{2})/e\1\2/g;
  s/-?1\.#INF|-?inf/INF/g; s/-?1\.#IND|-?nan(\(ind\))?/NAN/g; s/\r//g'; }
W=$TMPW/hybrid_$A; rm -rf "$W"; mkdir -p "$W/c" "$W/h"
$CC -O2 -shared -I"$LUAINC" -o "$W/ctest_lua5.1.dll" "$HERE/ctest.c" "$REFDIR/$A/liblua5.1.a" || exit 1
$CC -O2 -shared -I"$LUAINC" -o "$W/ctest_lua51.dll" "$HERE/ctest.c" "$H/lua51.dll" || exit 1
cp "$REFDIR/$A/lua.exe" "$REFDIR/$A/lua5.1.dll" "$HERE/t_ctest.lua" "$W/c/"; cp "$W/ctest_lua5.1.dll" "$W/c/ctest.dll"
(cd "$W/c" && $WINE ./lua.exe t_ctest.lua 2>&1 | norm > out.txt)
cp "$H"/demo_hybrid.exe "$H"/lua5.1.dll "$H"/lua51.dll "$HERE/t_ctest.lua" "$W/h/"
for v in lua5.1 lua51; do
  cp "$W/ctest_$v.dll" "$W/h/ctest.dll"
  (cd "$W/h" && $WINE ./demo_hybrid.exe t_ctest.lua 2>&1 | norm > out_$v.txt)
  if diff "$W/c/out.txt" "$W/h/out_$v.txt" > /dev/null; then echo "hybrid $A, module linked to $v.dll: IDENTICAL to C"
  else echo "hybrid $A, module linked to $v.dll: DIFFERENT"; diff "$W/c/out.txt" "$W/h/out_$v.txt" | head -20; fi
done
