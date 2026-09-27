#!/bin/bash
# lua executable comparison: runs every command line in cases.txt with the C
# lua and with the Pascal lua and compares stdout+stderr+exit code.  Both use
# the Pascal Lua library (on Windows the order in which buffered stdout and
# stderr lines reach a pipe depends on the library's stdio: the Pascal DLL
# buffers a redirected stdout like the MSVC runtime, while the MinGW
# reference DLL under Wine flushes every line).  On Linux the Pascal lua has
# Lua linked in, like the C "make linux" build.
# usage: runexe.sh win32|win64|linux64|linuxarm64|macx64|macarm64 [pascal-build-dir]   (default $PASDIR/<arch>)
. "$(dirname "$0")/../env.sh"
A=$1; P=${2:-$PASDIR/$A}; plat $A
HERE=$(cd "$(dirname "$0")" && pwd)
C=$TMPW/exe_c_$A; Q=$TMPW/exe_p_$A; rm -rf "$C" "$Q"; mkdir -p "$C" "$Q"
cp "$REFDIR/$A/lua$EXE" "$P/$LUALIB" "$C/"; cp "$P/lua$EXE" "$P/$LUALIB" "$Q/"
for d in "$C" "$Q"; do cp "$HERE/script.lua" "$HERE/err.lua" "$HERE/mod1.lua" "$d/"; done
run() { # dir, case
  (cd "$1" && eval "timeout 30 $RUN ./lua$EXE $2" 2>&1 < /dev/null; echo "rc=$?") |
    sed 's/\r//g; s#[A-Z]:\\[^ :]*\\lua\.exe#LUA#g; s#[^ ]*[\\/]lua\.exe#LUA#g; s#\./lua:#LUA:#g; s#usage: \./lua #usage: LUA #g'
}
bad=0; n=0
while IFS= read -r c <&3; do
  n=$((n+1)); r1=$(run "$C" "$c"); r2=$(run "$Q" "$c")
  if [ "$r1" != "$r2" ]; then bad=$((bad+1)); echo "--- $A case: $c"; diff <(echo "$r1") <(echo "$r2"); fi
done 3< "$HERE/cases.txt"
echo "lua $A: $n cases, $bad differ"
