#!/bin/sh
# macOS build with Free Pascal 3.2+  ->  build/fpc/<target>
#   target macx64 (Intel) or macarm64 (Apple Silicon); default: this Mac's.
#   On an Apple Silicon Mac the Intel build is made with  TARGET=macx64 FPC="fpc -Px86_64"
#   (and the other way round with -Paarch64); both need the Xcode command-line tools.
#   liblua5.1.dylib                        the Lua library (install name @rpath/liblua5.1.dylib)
#   lua, luac                              interpreter (Lua linked in, API exported
#                                          for C modules) and compiler
#   demo_dll, demo_static, demo_hybrid     host demos (+ hello.so C module)
# Extra options are passed to fpc, e.g.  ./build-macos.sh -O3
set -e
cd "$(dirname "$0")"
FPC=${FPC:-fpc}
if [ -z "$TARGET" ]; then
  case "$(uname -m)" in arm64|aarch64) TARGET=macarm64;; *) TARGET=macx64;; esac
fi
out=build/fpc/$TARGET
mkdir -p "$out/units" "$out/units_static"
opts="-O2 -Xs -CX -XX -Fusrc -Fisrc -FE$out -FU$out/units $*"
# exported symbols list: the C API names a program with LuaHostExports makes
# visible to C modules (bundles linked with -undefined dynamic_lookup)
export_api="-k-exported_symbols_list -ksrc/luaapi.exp"
$FPC $opts -oliblua5.1.dylib -k-install_name -k@rpath/liblua5.1.dylib lua5.dpr
$FPC $opts $export_api lua.dpr
$FPC $opts luac.dpr
$FPC $opts -Fl$out -k-rpath -k@executable_path demo/demo_dll.dpr
$FPC $opts -dLUA_STATIC -FU$out/units_static demo/demo_static.dpr
$FPC $opts $export_api demo/demo_hybrid.dpr
cp demo/prebuilt/$TARGET/hello.so "$out/"
rm -rf "$out/units" "$out/units_static" "$out"/link*.res
echo "Build OK ($out)"
