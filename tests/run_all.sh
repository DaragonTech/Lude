#!/bin/bash
# Runs all comparison tests for one platform.
# usage: run_all.sh win32|win64|linux64|linuxarm64|macx64|macarm64 [pascal-build-dir]     (default $PASDIR/<arch>)
# The build dir must contain the Lua library, lua and luac (Windows: also
# lua51.dll; see the README for the file names).
# Needs the C reference in $REFDIR (see build_ref.sh) and, for the C module
# test, a C compiler (MinGW-w64 for Windows, gcc for Linux) plus the Lua
# headers ($LUAINC).
# Windows, optional: PASUCRT=<dir with a -DLUA_UCRT lua5.1.dll> enables the
# output diff (the MinGW C reference formats numbers like the UCRT).
. "$(dirname "$0")/env.sh"
A=$1; P=$(cd "${2:-$PASDIR/$A}" && pwd); plat $A
T=$ROOT/tests
S=$TMPW/suite_c_$A; rm -rf "$S"; mkdir -p "$S"; cp "$REFDIR/$A/lua$EXE" "$P/$LUALIB" "$S/"
echo "== official suite, C lua + Pascal $LUALIB";  "$T/lua5.1-tests/run.sh" "$S" $A
echo "== official suite, Pascal lua"; "$T/lua5.1-tests/run.sh" "$P" $A
echo "== C extension module";  "$T/cmod/runcmod.sh" $A C="$REFDIR/$A/$LUALIB" PAS="$P/$LUALIB"
if [ -z "$EXE" ]; then   # Linux, macOS
  echo "== output diff (C vs Pascal)"
  "$T/diff/rundiff.sh" $A C="$REFDIR/$A/$LUALIB" PAS="$P/$LUALIB"
elif [ -n "$PASUCRT" ]; then
  echo "== output diff (C vs Pascal LUA_UCRT build in $PASUCRT)"
  "$T/diff/rundiff.sh" $A C="$REFDIR/$A/$LUALIB" PAS_UCRT="$PASUCRT/$LUALIB"
else
  echo "== output diff skipped: set PASUCRT to a directory with a LUA_UCRT build of lua5.1.dll"
fi
echo "== lua scenarios"; "$T/exe/runexe.sh" $A "$P"
echo "== luac"; "$T/luac/runluac.sh" $A "$P" | tail -n 1
