# Test and benchmark scripts

These are the scripts used to check the Pascal `lua5.1.dll`, `lua51.dll`, `lua.exe` and `luac.exe` against the original C Lua 5.1.4, and to produce the numbers in [PERFORMANCE.md](../PERFORMANCE.md).

They are bash scripts. Each takes a platform: `win32`, `win64`, `linux64`, `linuxarm64`, `macx64` or `macarm64`. The Windows builds were tested on Linux with Wine 9 and MinGW-w64, and the scripts also run on Windows under MSYS2 or Git-Bash with `WINE` empty. The x86-64 Linux build is tested natively with gcc. The ARM64 build runs natively on an ARM64 machine; on an x86-64 machine it runs under `qemu-aarch64-static`, with the C library from `/usr/aarch64-linux-gnu` (packages `qemu-user-static`, `gcc-aarch64-linux-gnu`). Register qemu in `binfmt_misc` so that `main.lua` in the test suite can start ARM64 programs through the shell. The macOS builds run natively on a Mac with the Xcode command-line tools; on an Apple Silicon Mac, `macx64` runs under Rosetta 2. The scripts work with the bash 3.2 that comes with macOS, and use stand-ins for `timeout` and `md5sum`, which macOS lacks.

## Setup

| Variable | Meaning | Default |
|---|---|---|
| `REFDIR` | C reference builds: `$REFDIR/win32` and `$REFDIR/win64`, each with `lua.exe`, `lua5.1.dll`, `luac.exe` and `liblua5.1.a`; `$REFDIR/linux64` and `$REFDIR/linuxarm64` with `lua`, `liblua5.1.so.0` and `luac`; `$REFDIR/macx64` and `$REFDIR/macarm64` with `lua`, `liblua5.1.dylib` and `luac` | `<project>/ref` |
| `PASDIR` | Pascal builds: `$PASDIR/win32` and `$PASDIR/win64` | `<project>/build/delphi` if it exists, else `<project>/build/fpc` |
| `WINE` | command that runs Windows programs | `wine` on Linux, empty on MSYS2/Cygwin |
| `LUAINC` | Lua 5.1.4 `src` directory with `lua.h` (for the C module test) | `<project>/../lua-5.1.4/src` |
| `PASUCRT` | directory with a `-DLUA_UCRT` build of `lua5.1.dll` (enables the output diff in `run_all.sh`) | not set |

Build the C reference once from the original sources, with MinGW-w64 `gcc -O2` for Windows, `gcc -O2` for Linux and `cc -O2` (clang) for macOS:

```
tests/build_ref.sh /path/to/lua-5.1.4                 # win32 win64
tests/build_ref.sh /path/to/lua-5.1.4 linux64         # on Linux
tests/build_ref.sh /path/to/lua-5.1.4 linuxarm64      # on ARM64 Linux, or cross with aarch64-linux-gnu-gcc
tests/build_ref.sh /path/to/lua-5.1.4 macarm64 macx64 # on a Mac
```

## Scripts

| Script | What it checks |
|---|---|
| `run_all.sh <arch> [build-dir]` | Runs everything below except the benchmark. `build-dir` holds `lua5.1.dll`, `lua51.dll`, `lua.exe` and `luac.exe`, for example `build/delphi/win32` or `build/fpc/win32`. |
| `lua5.1-tests/run.sh <dir> <arch>` | The official Lua 5.1 test suite (`allwin.lua` on Windows, `allposix.lua` on Linux and macOS). It passes when the log contains "final OK". The local changes to the suite are listed in `lua5.1-tests/CHANGES.txt`. |
| `cmod/runcmod.sh <arch> NAME=dll ...` | Builds `ctest.c`, a C extension module that exercises most of the C API including the varargs functions, links it to the C import library, and runs it on each DLL. Output is compared with the first DLL. |
| `cmod/runhybrid.sh <arch> [hybrid-dir]` | Windows hybrid setup: runs the C module test inside `demo_hybrid.exe` (Lua linked into the EXE) through the shim `lua5.1.dll`, with the module linked to `lua5.1.dll` and to `lua51.dll`. Output is compared with the C `lua.exe` and C `lua5.1.dll`. |
| `diff/rundiff.sh <arch> NAME=dll ...` | Runs `difftest.lua` (numbers, `string.format`, `tonumber`, string library, tables, errors, metatables) and `io_os.lua` (io/os libraries) on each DLL and diffs the normalised output. Use a `LUA_UCRT` build when comparing with the MinGW reference, because the default build prints numbers the classic-MSVC way on purpose. |
| `exe/runexe.sh <arch> [build-dir]` | Runs the 25 command lines in `cases.txt` (options, scripts, stdin, interactive mode, errors, exit codes) with the C `lua.exe` and the Pascal `lua.exe`. |
| `luac/runluac.sh <arch> [build-dir]` | Compares the C and Pascal `luac.exe` on 99 cases: `-l -l` listings, `luac.out` md5, `-s`, `-p`, `-o`, usage and errors. |
| `bench/runbench.sh ROUNDS SCALE NAME=dll:arch ...` | Benchmarks. The same C `lua.exe` runs `bench/bench.lua` with each DLL. It reports the best time over `ROUNDS` runs and the ratio to the first DLL. |
| `crttest.dpr` + `crtcheck.py` | Checks the C-runtime emulation (`printf` number formats, `strtod`) against exact decimal arithmetic on about 32,000 cases. |
| `smoke.dpr` | Minimal static-link smoke test. |

## Examples

```
export REFDIR=$HOME/ref
tests/run_all.sh win32 build/delphi/win32
tests/run_all.sh linux64 build/fpc/linux64
tests/run_all.sh linuxarm64 build/fpc/linuxarm64
tests/run_all.sh macarm64 build/fpc/macarm64
tests/cmod/runcmod.sh win64 C=$REFDIR/win64/lua5.1.dll DELPHI=build/delphi/win64/lua5.1.dll
tests/bench/runbench.sh 3 1 C=$REFDIR/win32/lua5.1.dll:win32 FPC=build/fpc/win32/lua5.1.dll:win32 DELPHI=build/delphi/win32/lua5.1.dll:win32
```
