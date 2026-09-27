# Common settings for the test scripts (source it; bash).
#   REFDIR  C reference builds of Lua 5.1.4 (build them with build_ref.sh):
#           $REFDIR/win32, $REFDIR/win64: lua.exe, lua5.1.dll, luac.exe, liblua5.1.a
#           $REFDIR/linux64, $REFDIR/linuxarm64: lua, liblua5.1.so.0, luac
#           $REFDIR/macx64, $REFDIR/macarm64: lua, liblua5.1.dylib, luac
#   PASDIR  Pascal builds: $PASDIR/<platform> (default: <project>/build/delphi
#           if it exists, else <project>/build/fpc)
#   WINE    command used to run Windows programs (default: "wine" on Linux,
#           nothing under MSYS2/Cygwin/Git-Bash on Windows)
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
REFDIR=${REFDIR:-$ROOT/ref}
if [ -z "$PASDIR" ]; then
  if [ -d "$ROOT/build/delphi" ]; then PASDIR=$ROOT/build/delphi; else PASDIR=$ROOT/build/fpc; fi
fi
if [ -z "${WINE+x}" ]; then
  case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) WINE="";; *) WINE="wine";; esac
fi
export WINEDEBUG=-all
TMPW=${TMPDIR:-/tmp}
TMPW=${TMPW%/}/lua51pas-tests
mkdir -p "$TMPW"

# macOS has no GNU timeout or md5sum; stand-ins with the same use
if ! command -v timeout > /dev/null 2>&1; then
  timeout() { local t=$1; shift; perl -e 'alarm shift; exec @ARGV or die "$ARGV[0]: $!\n"' "$t" "$@"; }
fi
if ! command -v md5sum > /dev/null 2>&1; then
  md5sum() { local f; for f in "$@"; do echo "$(md5 -q "$f")  $f"; done; }
fi

# plat ARCH  (win32 | win64 | linux64 | linuxarm64 | macx64 | macarm64): sets
#   RUN     how to run a program of that platform ($WINE for Windows, nothing otherwise)
#   EXE     executable suffix (.exe or empty)
#   LUALIB  file name of the Lua library (lua5.1.dll / liblua5.1.so.0 / liblua5.1.dylib)
#   MODEXT  C module extension (dll / so)
#   MODCC   command that builds a C module: $MODCC -o out.$MODEXT file.c
plat() {
  LUAINC=${LUAINC:-$ROOT/../lua-5.1.4/src}
  case "$1" in
    win32|win64)
      RUN=$WINE; EXE=.exe; LUALIB=lua5.1.dll; MODEXT=dll
      local cc; [ "$1" = win32 ] && cc=i686-w64-mingw32-gcc || cc=x86_64-w64-mingw32-gcc
      MODCC_TAIL="$REFDIR/$1/liblua5.1.a"
      MODCC="$cc -O2 -shared -I$LUAINC";;
    linux64)
      RUN=""; EXE=""; LUALIB=liblua5.1.so.0; MODEXT=so
      MODCC_TAIL=""
      MODCC="gcc -O2 -shared -fPIC -I$LUAINC";;
    linuxarm64)
      EXE=""; LUALIB=liblua5.1.so.0; MODEXT=so; MODCC_TAIL=""
      if [ "$(uname -m)" = aarch64 ]; then
        RUN=""; MODCC="gcc -O2 -shared -fPIC -I$LUAINC"
      else
        # on another machine: qemu user-mode emulation, with the ARM64 C library
        # of the cross toolchain.  With qemu registered in binfmt_misc, ARM64
        # programs also run directly - needed by main.lua, which starts "lua"
        # through the shell.
        export QEMU_LD_PREFIX=${A64_SYSROOT:-/usr/aarch64-linux-gnu}
        if [ -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then RUN=""
        else RUN="${QEMU_A64:-qemu-aarch64-static}"; fi
        MODCC="aarch64-linux-gnu-gcc -O2 -shared -fPIC -I$LUAINC"
      fi;;
    macx64|macarm64)
      # macOS: C modules are bundles that take the Lua API from the host
      # (-undefined dynamic_lookup).  On an Apple Silicon Mac, macx64 runs
      # under Rosetta 2.
      RUN=""; EXE=""; LUALIB=liblua5.1.dylib; MODEXT=so; MODCC_TAIL=""
      local arch; [ "$1" = macx64 ] && arch=x86_64 || arch=arm64
      MODCC="cc -arch $arch -O2 -bundle -undefined dynamic_lookup -I$LUAINC";;
    *) echo "unknown platform '$1' (win32, win64, linux64, linuxarm64, macx64, macarm64)" >&2; exit 2;;
  esac
}
# build a C module: modcc out.$MODEXT file.c
modcc() { $MODCC -o "$1" "$2" $MODCC_TAIL; }
