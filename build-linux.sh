#!/bin/sh
# Linux build with Free Pascal 3.2+  ->  build/fpc/<target>
#   target linux64 (x86-64) or linuxarm64 (AArch64); default: this machine's.
#   Cross-compiling: TARGET=linuxarm64 FPC="ppcrossa64 -XPaarch64-linux-gnu- ..." ./build-linux.sh
#   liblua5.1.so.0 (+ liblua5.1.so link)   the Lua library (drop-in for the C one)
#   lua, luac                              interpreter (Lua linked in, API exported
#                                          for C modules) and compiler
#   demo_dll, demo_static, demo_hybrid     host demos (+ hello.so C module)
# Extra options are passed to fpc, e.g.  ./build-linux.sh -O3
set -e
cd "$(dirname "$0")"
FPC=${FPC:-fpc}
if [ -z "$TARGET" ]; then
  case "$(uname -m)" in aarch64|arm64) TARGET=linuxarm64;; *) TARGET=linux64;; esac
fi
out=build/fpc/$TARGET
mkdir -p "$out/units" "$out/units_static"
opts="-O2 -Xs -CX -XX -Fusrc -Fisrc -FE$out -FU$out/units $*"
# the dynamic list puts exactly the C API names into an executable's
# dynamic symbol table (like -Wl,-E), for programs using LuaHostExports
export_api="-k--dynamic-list=src/luaapi.dynlist"
$FPC $opts -oliblua5.1.so.0 lua5.dpr
ln -sf liblua5.1.so.0 "$out/liblua5.1.so"
$FPC $opts $export_api lua.dpr
$FPC $opts luac.dpr
$FPC $opts -Fl$out '-k-rpath=$ORIGIN' demo/demo_dll.dpr
$FPC $opts -dLUA_STATIC -FU$out/units_static demo/demo_static.dpr
$FPC $opts $export_api demo/demo_hybrid.dpr
cp demo/prebuilt/$TARGET/hello.so "$out/"
rm -rf "$out/units" "$out/units_static"
echo "Build OK ($out)"
