#!/bin/bash
# Official Lua 5.1 test suite (copy from gopher-lua's _lua5.1-tests, see CHANGES.txt).
# usage: run.sh <dir containing lua + Lua library> <win32|win64|linux64|linuxarm64|macx64|macarm64> [logfile]
# Passes when the log contains "final OK".
. "$(dirname "$0")/../env.sh"
D=$(cd "$1" && pwd); A=$2; plat $A; LOG=${3:-$TMPW/suite_${A}_$(basename "$D").log}
cd "$(dirname "$0")"
E=(); [ "$A" = win32 ] && E=(RUNBIG=1)   # big.lua needs more address space than Wine gives Win64 here
ALL=allposix.lua; [ "$EXE" = .exe ] && ALL=allwin.lua
timeout 1200 env "${E[@]}" LUA_PATH="./?.lua;;" LUA_INIT="package.path = '?;'..package.path" \
  $RUN "$D/lua$EXE" $ALL > "$LOG" 2>&1
if grep -q "final OK" "$LOG"; then echo "suite $A $(basename "$D"): final OK"; else echo "suite $A $(basename "$D"): FAILED (see $LOG)"; exit 1; fi
