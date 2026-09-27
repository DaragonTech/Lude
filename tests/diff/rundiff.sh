#!/bin/bash
# Output comparison: runs difftest.lua and io_os.lua with the C lua and each
# Lua library given, normalises CRT-style differences (exponent digits, inf/nan
# spelling, addresses) and diffs against the first library.
# usage: rundiff.sh win32|win64|linux64|linuxarm64|macx64|macarm64 NAME=path/to/library [NAME=...]
# Windows note: compare a LUA_UCRT build with the MinGW C reference; the
# default (classic MSVC) build differs from it on purpose in %.0f rounding,
# %f digits beyond 17, and tonumber of "1d2"/"inf"/hex floats.
. "$(dirname "$0")/../env.sh"
A=$1; shift; plat $A
HERE=$(cd "$(dirname "$0")" && pwd)
norm() { sed -E 's/([eE])([+-])0([0-9][0-9])/\1\2\3/g; s/-?1\.#INF[0-9]*|-?inf/INF/g;
  s/-?1\.#(IND|QNAN)|-?nan(\(ind\))?/NAN/g; s/\r//g; s/: [0-9A-Fa-f]{8,16}/: ADDR/g;
  s/0x[0-9a-f]+/ADDR/g; s/\(0x[0-9A-Fa-f]+\)/(ADDR)/g; s#[A-Z]:\\[^ :]*\\lua\.exe#LUA#g'; }
for s in difftest.lua io_os.lua; do
  first=""
  for c in "$@"; do
    n=${c%%=*}; lib=${c#*=}; W=$TMPW/diff_${A}_$n; mkdir -p "$W"
    cp "$REFDIR/$A/lua$EXE" "$W/"; cp "$lib" "$W/$LUALIB"; cp "$HERE/$s" "$W/"
    (cd "$W" && timeout 120 $RUN ./lua$EXE $s x y > raw_$s.txt 2>&1; echo "rc=$?" >> raw_$s.txt; norm < raw_$s.txt > out_$s.txt)
    if [ -z "$first" ]; then first=$W
    elif diff "$first/out_$s.txt" "$W/out_$s.txt" > "$W/diff_$s.txt"; then echo "$A $s $n: IDENTICAL ($(wc -l < "$W/out_$s.txt") lines)"
    else echo "$A $s $n: DIFFERENT (see $W/diff_$s.txt)"; head -20 "$W/diff_$s.txt"; fi
  done
done
