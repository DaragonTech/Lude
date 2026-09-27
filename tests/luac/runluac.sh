#!/bin/bash
# Compare the Pascal luac against the C reference luac (Windows builds under Wine).
# usage: runluac.sh win32|win64|linux64|linuxarm64|macx64|macarm64 [pascal-build-dir]
. "$(dirname "$0")/../env.sh"
T=$1; P=$(cd "${2:-$PASDIR/$T}" && pwd); plat $T
W=$TMPW/luac_$T; rm -rf "$W"; mkdir -p "$W"
cp "$ROOT"/tests/lua5.1-tests/*.lua "$W/"
cp "$ROOT/tests/exe/err.lua" "$W/"
printf 'print("s\\0\\1\\255\\a\\b\\f\\v\\r\\t\\"")\nlocal t={1,2,3,[10]=nil,x=1.5e300,y=-0.0,z=1/3}\nfor i=1,2 do end\nreturn t\n' > "$W/k.lua"
cd "$W"
run() { # name exe args...
  local tag=$1; shift
  local exe=$1; shift
  $RUN "$exe" "$@" < /dev/null > out.txt 2> err.txt; echo "rc=$?" >> err.txt
  sed -E 's/0x[0-9a-f]+/ADDR/g; s/\b[0-9A-Fa-f]{8,16}\b/ADDR/g; s/e([+-])0([0-9][0-9])/e\1\2/g; s#[^ ]*luac(\.exe)?:#luac:#g; s#[^ ]*luac(\.exe)? \[#luac [#g; s/[^ ]*luac\.exe/luac/g; /^[0-9a-f]{4}:(err|fixme)/d' out.txt err.txt
  [ -f luac.out ] && md5sum luac.out && rm -f luac.out
  [ -f x.out ] && md5sum x.out && rm -f x.out
}
cases=(
 "-v"
 ""
 "-x"
 "-o"
 "-l k.lua"
 "-l -l k.lua"
 "-p err.lua"
 "k.lua"
 "-s k.lua"
 "-o x.out -s constructs.lua"
 "-l -p calls.lua"
 "-l -l -p closure.lua nextvar.lua"
 "strings.lua math.lua"
 "-s -o x.out gc.lua sort.lua events.lua"
 "-o - k.lua"
 "-v -- k.lua"
 "nonexist.lua"
 "-o nodir/x.out k.lua"
)
for f in *.lua; do cases+=("-l -l -p $f" "-o x.out $f" "-s -o x.out $f"); done
same=0; ndiff=0
for c in "${cases[@]}"; do
  echo "=== $c"
  run C "$REFDIR/$T/luac$EXE" $c > c.res 2>&1
  run P "$P/luac$EXE" $c > p.res 2>&1
  if cmp -s c.res p.res; then echo same; same=$((same+1)); else echo DIFF; ndiff=$((ndiff+1)); diff c.res p.res | head -10; fi
done
echo "luac $T: $same same, $ndiff differ"
