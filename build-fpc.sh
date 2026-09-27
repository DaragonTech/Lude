#!/bin/sh
# Output: build/fpc/win32 and build/fpc/win64.
# Build with Free Pascal 3.2+ (native on Windows via MSYS/Cygwin, or as a
# cross-compile from Linux).  Override the compilers if needed:
#   FPC32="ppcross386 -Twin32"  FPC64="ppcrossx64 -Twin64"  ./build-fpc.sh
#   ./build-fpc.sh -dLUA_UCRT        (extra options are passed through)
set -e
cd "$(dirname "$0")"
FPC32=${FPC32:-"fpc -Twin32 -Pi386"}
FPC64=${FPC64:-"fpc -Twin64 -Px86_64"}
build() { # compiler outdir extra...
  cc=$1; out=$2; shift 2
  mkdir -p "$out/units"
  opts="-O2 -Xs -Fusrc -Fisrc -FE$out -FU$out/units $*"
  $cc $opts -olua5.1.dll lua5.dpr
  $cc $opts lua51.dpr
  $cc $opts lua.dpr
  $cc $opts luac.dpr
  $cc $opts demo/demo_dll.dpr
  # demo_static: define LUA_STATIC for all units, separate unit folder
  mkdir -p "$out/units_static"
  $cc $opts -dLUA_STATIC -FU$out/units_static demo/demo_static.dpr
  # hybrid: Lua linked into demo_hybrid.exe + shim lua5.1.dll for C modules
  mkdir -p "$out/hybrid"
  $cc $opts -FE$out/hybrid -olua5.1.dll hybrid/lua5.dpr
  $cc $opts -FE$out/hybrid demo/demo_hybrid.dpr
  cp "$out/lua51.dll" "$out/hybrid/"
  cp "demo/prebuilt/$arch/hello.dll" "$out/hybrid/"
  rm -rf "$out/units" "$out/units_static"
}
arch=win32; build "$FPC32" build/fpc/win32 "$@"
arch=win64; build "$FPC64" build/fpc/win64 "$@"
echo "Build OK"
