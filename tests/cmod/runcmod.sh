#!/bin/bash
# C extension module test: builds ctest (a C module that exercises most of the
# C API, including the varargs functions) and runs t_ctest.lua with the C lua
# and each Lua library given; outputs are normalised and compared with the first.
# Windows: the module is linked to the C reference's import library.
# Linux: the module is not linked to Lua; it uses the host's symbols.
# usage: runcmod.sh win32|win64|linux64|linuxarm64|macx64|macarm64 NAME=path/to/library [NAME=...]
# example: runcmod.sh win32 C=$REFDIR/win32/lua5.1.dll FPC=build/fpc/win32/lua5.1.dll
. "$(dirname "$0")/../env.sh"
A=$1; shift; plat $A
HERE=$(cd "$(dirname "$0")" && pwd)
modcc "$TMPW/ctest_$A.$MODEXT" "$HERE/ctest.c" || exit 1
norm() { sed -E 's/0x[0-9a-fA-F]+|[0-9A-Fa-f]{8,16}/ADDR/g; s/e([+-])0([0-9]{2})/e\1\2/g;
  s/-?1\.#INF|-?inf/INF/g; s/-?1\.#IND|-?nan(\(ind\))?/NAN/g; s/\r//g'; }
first=""
for c in "$@"; do
  n=${c%%=*}; lib=${c#*=}; W=$TMPW/cmod_${A}_$n; rm -rf "$W"; mkdir -p "$W"
  cp "$REFDIR/$A/lua$EXE" "$W/"; cp "$lib" "$W/$LUALIB"; cp "$TMPW/ctest_$A.$MODEXT" "$W/ctest.$MODEXT"; cp "$HERE/t_ctest.lua" "$W/"
  (cd "$W" && LUA_CPATH="./?.$MODEXT" $RUN ./lua$EXE t_ctest.lua 2>&1 | norm > out.txt)
  if [ -z "$first" ]; then first=$W; echo "$A $n: $(wc -l < "$W/out.txt") lines (baseline)";
  elif diff "$first/out.txt" "$W/out.txt" > /dev/null; then echo "$A $n: IDENTICAL";
  else echo "$A $n: DIFFERENT"; diff "$first/out.txt" "$W/out.txt" | head -20; fi
done
