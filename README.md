![Lude-Icon](./Lude-icon.png)

# Lude

**Lude** is Lua 5.1.4 in pure Pascal.

It is a file-by-file port of the Lua 5.1.4 C sources (core, auxiliary library, all standard libraries, `lua.c`, `luac.c` and `print.c`) to Object Pascal. It builds for:

- **Windows (Win32 and Win64)** with **Delphi 10.2** or **Free Pascal 3.2+**;
- **Linux x86-64 and ARM64 (AArch64)** with **Free Pascal 3.2+** (see [Linux](#linux));
- **macOS on Intel and Apple Silicon** with **Free Pascal 3.2+** (see [macOS](#macos)).

On Windows the binaries are meant to replace the C LuaBinaries files directly:

| File | What it is |
|---|---|
| `lua5.1.dll` | The real implementation. It exports the same 123 `cdecl` symbols as the C `lua5.1.dll`, with the same names, the same calling convention and the same struct layouts (`lua_Debug`, `luaL_Reg`, `luaL_Buffer`). |
| `lua51.dll` | A proxy. Every export forwards to `lua5.1.dll`, so modules linked against either name share one Lua state. |
| `lua.exe` | The stand-alone interpreter (a port of `lua.c`). It uses `lua5.1.dll`. |
| `luac.exe` | The compiler and lister (a port of `luac.c` and `print.c`). It is statically linked, like the C one. |

Existing C extension modules (`require "foo"` → `foo.dll` linked against `lua5.1.dll` or `lua51.dll`) and existing C host programs work unchanged.

On Linux the equivalents are `liblua5.1.so.0` (a drop-in for the C library of the same name), `lua` and `luac`; on macOS they are `liblua5.1.dylib`, `lua` and `luac`.

## A note from the developer

Lude is my second project, after Rulua, where I guided an AI to write all of the code. My part was to set the requirements (pure Pascal, Delphi, a drop-in for the C `lua5.1.dll`), build it, run it on my own machines, send back the output and decide what came next. 

Porting Lua to Pascal file by file, binary-compatible with the C DLL, then taking it to Linux and macOS on Intel and ARM, used to mean months of work. Here the hard part was knowing exactly what I wanted, and checking honestly that I got it. The tests below are that check.

— Felipe, DaragonTech

## Building

Everything is built into `build\`, in one folder per compiler and platform:

```
build\delphi\win32   build\delphi\win64    from build.bat        (Delphi)
build\fpc\win32      build\fpc\win64       from build-fpc.sh     (Free Pascal)
build/fpc/linux64  build/fpc/linuxarm64   from build-linux.sh   (Free Pascal, on Linux)
build/fpc/macx64   build/fpc/macarm64     from build-macos.sh   (Free Pascal, on macOS)
```

Prebuilt Free Pascal binaries come in a separate zip, `lua51pas-5.1.4-fpc-bin.zip`, attached to each version tag on the repository's [Releases](../../releases) page; the repository itself holds only the sources. The zip contains `lua51pas\build\fpc\...`, so extracting it next to the sources puts the files in the folders above.

Each Windows folder contains the same files:

```
lua5.1.dll  lua51.dll  lua.exe  luac.exe  demo_dll.exe  demo_static.exe
hybrid\     demo_hybrid.exe  lua5.1.dll (shim)  lua51.dll  hello.dll
```

Each Linux folder contains:

```
liblua5.1.so.0  liblua5.1.so (link)  lua  luac  demo_dll  demo_static  demo_hybrid  hello.so
```

Each macOS folder contains:

```
liblua5.1.dylib  lua  luac  demo_dll  demo_static  demo_hybrid  hello.so
```

### Delphi 10.2 (dcc32 / dcc64)

Open the **RAD Studio Command Prompt** (or run `rsvars.bat`), then:

```
build.bat              rem Win32 + Win64  -> build\delphi\win32, build\delphi\win64
build.bat win32        rem one platform
build.bat win64 ucrt   rem UCRT-style number formatting (see below)
```

You can also open `lua5.dpr`, `lua51.dpr`, `lua.dpr` or `luac.dpr` in the IDE, which creates the `.dproj` for you, and add the Win64 platform there.

- The DLL project is named `lua5` and uses `{$LIBSUFFIX '.1'}`, so Delphi writes `lua5.1.dll`. If your setup ignores the suffix, `build.bat` renames `lua5.dll` for you.
- None of the Delphi RTL units are used (no `SysUtils` and no `Windows`), so the DLL doesn't depend on RTL packages.

### Free Pascal

```
./build-fpc.sh                     # -> build/fpc/win32, build/fpc/win64 (fpc -Twin32 -Pi386 / -Twin64 -Px86_64)
FPC32="ppcross386 -Twin32" FPC64="ppcrossx64 -Twin64" ./build-fpc.sh
./build-fpc.sh -dLUA_UCRT
```

With FPC the output name comes from `-olua5.1.dll`.

### Linux x86-64 and ARM64 (Free Pascal)

```
./build-linux.sh                   # this machine: -> build/fpc/linux64 (x86-64) or build/fpc/linuxarm64 (ARM64)
TARGET=linuxarm64 FPC="ppcrossa64 -XPaarch64-linux-gnu- -Fl/usr/aarch64-linux-gnu/lib" ./build-linux.sh   # cross
```

It needs Free Pascal 3.2+ (`fpc`, for example from the distribution's `fp-compiler` package) and the usual C library development files. The prebuilt Linux binaries in the `-fpc-bin` zip were built for Ubuntu 24.04 and need glibc 2.38 or newer. On older systems, build them yourself. See [Linux](#linux) for how the Linux build behaves.

**Free Pascal 3.2.2 on ARM64 with glibc 2.34 or newer:** the distributions' Free Pascal packages work. The upstream 3.2.2 sources need two small fixes to `rtl/linux/aarch64/cprt0.as` before programs linked with the C library work:
- `__libc_csu_init`/`__libc_csu_fini` no longer exist in glibc; pass `0` for them.
- `_haltproc` should call `exit` rather than the raw `exit_group` system call, so C stdio buffers are flushed at exit.

I applied both to the cross-compiler used for the prebuilt ARM64 binaries.

### macOS Intel and Apple Silicon (Free Pascal)

```
./build-macos.sh                                   # this Mac: -> build/fpc/macarm64 (Apple Silicon) or build/fpc/macx64 (Intel)
TARGET=macx64   FPC="fpc -Px86_64"  ./build-macos.sh   # Intel build on an Apple Silicon Mac (runs under Rosetta 2)
TARGET=macarm64 FPC="fpc -Paarch64" ./build-macos.sh   # Apple Silicon build on an Intel Mac
```

It needs Free Pascal 3.2.2 for macOS (the installer from freepascal.org has both the Intel and the ARM64 compiler) and the Xcode command-line tools (`xcode-select --install`), which provide the assembler and linker. See [macOS](#macos) for how the macOS build behaves.

The prebuilt macOS binaries in the `-fpc-bin` zip were cross-compiled on Linux: Free Pascal 3.2.2 cross-compilers, clang as the assembler and LLVM's `ld64.lld` as the linker, with a generated stub of `libSystem` instead of the macOS SDK. They need macOS 10.8 or newer on Intel and macOS 11 or newer on Apple Silicon. The ARM64 binaries carry the ad-hoc code signature Apple Silicon requires. Files downloaded with a browser get the quarantine flag; remove it with `xattr -dr com.apple.quarantine build/fpc/macarm64` (or `macx64`).

### Using the DLL from Delphi code

`src/LuaDLL.pas` is a complete import unit covering the whole API plus the `lua.h`/`lauxlib.h` macros. By default it imports from `lua5.1.dll`. Define `LUA_USE_LUA51` to import from `lua51.dll` instead.

### Linking Lua into your program (no DLL)

`src/LuaStatic.pas` has the same interface as `LuaDLL.pas`: the same constants, types, functions and macros. Instead of importing `lua5.1.dll`, it compiles Lua into your executable. Code written for one compiles unchanged with the other, so a single codebase can build both ways:

```pascal
uses {$IFDEF LUA_STATIC} LuaStatic {$ELSE} LuaDLL {$ENDIF};

var L: Plua_State;
begin
  lua_set_c_fpu_mode;          // mask FP exceptions (see below)
  L := luaL_newstate;
  luaL_openlibs(L);
  luaL_dostring(L, 'print("hello")');
  lua_close(L);
end.
```

Add `src` to the project's search path (`-Usrc -Isrc` for dcc, `-Fusrc -Fisrc` for FPC). A static build adds about 170–270 KB to the executable.

`demo/` contains the same host program built both ways. The program is the unit `demo/DemoApp.pas`, which registers Pascal functions, defines a userdata type with methods, raises errors from Pascal, and reads globals back. `demo_dll.dpr` and `demo_static.dpr` only call it. `build.bat` and `build-fpc.sh` build them as `demo_dll.exe` and `demo_static.exe`.

A unit can't see a `{$DEFINE}` made in a `.dpr`, so `LUA_STATIC` must be a project-wide define: in Delphi, *Project Options → Delphi Compiler → Conditional defines* or `dcc32 -DLUA_STATIC`; in FPC, `-dLUA_STATIC`. Give each project its own unit output folder, so that a `DemoApp.dcu` compiled with the other setting is never reused. Each `.dpr` checks this at compile time and stops with a clear message if the define doesn't match. Their output is identical on Win32 and Win64, and `demo_dll.exe` also runs unchanged on the C `lua5.1.dll`.

Things to know:

- **Formatted messages:** Pascal can declare C-style varargs only for DLL imports, so `lua_pushfstring(L, fmt, ...)` and `luaL_error(L, fmt, ...)` exist only in `LuaDLL`. Both units provide `lua_pushfstringf` and `luaL_errorf`, which take an array of const: `luaL_errorf(L, 'bad value %d', [n])`. With `LuaDLL`, these build a C `va_list`, so they work with any `lua5.1.dll`, the C builds included.
- **Floating-point exceptions:** Delphi programs start with some floating-point exceptions unmasked, so a script evaluating `0/0` or `1/0` would raise `EInvalidOp`/`EZeroDivide` instead of producing NaN/inf. Free Pascal programs do the same on ARM64, where Apple Silicon then stops the program on `0/0` ("illegal hardware instruction"). Call `lua_set_c_fpu_mode` once at startup; both units provide it. This applies to hosts using the DLL too.
- **C extension modules** (DLLs linked to `lua5.1.dll`) need the hybrid setup below. With only `LuaStatic`, loading one would bring in a second Lua runtime. Lua modules and functions registered from Pascal work normally.
- **Errors:** an error raised outside any protected call (for example `lua_call` with no `lua_pcall` around it) reaches your code as an `ELuaThrow` exception, instead of calling the panic function and exiting as with the C DLL.
- `LuaStatic.pas` is generated from `LuaDLL.pas` by `tools/gen_luastatic.py`. Regenerate it after changing `LuaDLL.pas`.

### Hybrid: Lua linked in, C modules still loadable

A program can link Lua statically and still load C extension modules (`require "socket"` → `socket.dll` linked against `lua5.1.dll` or `lua51.dll`). The modules then run on the Lua inside the program and share its `lua_State`.

1. Add `LuaHostExports` to the program's `uses` clause, next to `LuaStatic`. The EXE then exports the same 123 C API functions as `lua5.1.dll`.
2. Put the **shim** `lua5.1.dll`, built from `hybrid/lua5.dpr`, next to the EXE instead of the real one. You can add the `lua51.dll` proxy too, for modules linked against that name.

```
myapp.exe    (LuaStatic + LuaHostExports)
lua5.1.dll   hybrid shim: forwards to myapp.exe
lua51.dll    optional proxy: forwards to lua5.1.dll
socket.dll ... any C modules
```

The shim contains no Lua. Each export is a single jump through a table. When the shim loads, it fills that table from the first module in the process that exports `luaL_newstate`: the EXE first, then any loaded DLL. So Lua can also be linked into a Delphi DLL or plugin instead of the EXE. If no module exports the API, the shim prints an explanation and exits.

`demo/demo_hybrid.dpr` shows this. `build.bat` and `build-fpc.sh` put it in `build\<compiler>\<arch>\hybrid\`, together with the shim, the proxy and `hello.dll`, a small C module (`demo/hello.c`, prebuilt in `demo/prebuilt/`). The demo calls C functions, raises a C error and catches it with `pcall`, and calls Lua from C, which then calls back into Pascal. Run it with a script path to execute that script instead: `demo_hybrid script.lua`.

In testing, `tests/cmod/ctest.c` (the full C API test) gives output identical to the C `lua5.1.dll` through the shim, on Win32 and Win64, whether the module is linked to `lua5.1.dll` or to `lua51.dll` (see `tests/cmod/runhybrid.sh`).

Keep the shim in a folder of its own. It must not replace the real `lua5.1.dll` that other programs use. `hybrid/lua5.dpr` and `src/LuaHostExports.pas` are generated by `tools/gen_hybrid.py`.

## Linux

The Linux build is the same Pascal code with a different system layer. On Windows, Lude imitates the Microsoft C runtime in Pascal. On Linux it uses the system C library directly, the way the C build of Lua does (`luaconf.h` with `LUA_USE_POSIX` and `LUA_USE_DLOPEN`, like `make linux` without readline). So the results match a C Lua 5.1.4 built with gcc on the same machine:

- **Numbers** print the glibc way: `1e+20`, `inf`, `-nan`. `string.format("%d")` uses a 64-bit `long`, and `tonumber(s, base)` uses the 64-bit `strtoul`, as in C on Linux.
- **`io` library** handles are real C `FILE*`s, so C modules can use them directly.
- **Memory** comes from `malloc`/`realloc`/`free`.
- **Math functions** are libm's (`sin`, `pow`, `fmod` …); `math.random` is libc's `rand()`.
- **`os` library:** `time`, `localtime`, `mktime` and `strftime` come from the C library, so `TZ` and the zoneinfo database apply. `os.clock` is CPU time. `os.tmpname` uses `mkstemp`. `os.setlocale` calls the real `setlocale`.
- **C modules** are loaded with `dlopen`. The default `package.path` and `package.cpath` are the standard Linux ones (`/usr/local/share/lua/5.1/`, `/usr/local/lib/lua/5.1/`, `.so`).
- **The varargs functions** `lua_pushfstring` and `luaL_error` follow each platform's C calling convention (System V on x86-64, AAPCS64 on ARM64), so C modules can call them as usual.
- **Number conversions** behave as the C casts do on each processor. For example, `string.format("%d", 2^70)` wraps to the minimum on x86-64 but saturates on ARM64, and `%x` of `-1` gives `ffffffffffffffff` on x86-64 but `0` on ARM64, as with C Lua.

What gets built:

| File | What it is |
|---|---|
| `liblua5.1.so.0` | The library (SONAME `liblua5.1.so.0`, as in Debian/Ubuntu), exporting the same 123 functions. A program linked to the C `liblua5.1.so.0` can use it instead. |
| `lua` | The interpreter. Like `make linux`, Lua is linked in and the C API is exported from the executable, so `require` can load C modules. |
| `luac` | The compiler and lister, with Lua linked in. |
| `demo_dll`, `demo_static`, `demo_hybrid` | The demos. `demo_dll` uses `liblua5.1.so.0`, found next to it. |

**Using Lude from a Pascal program on Linux** works as on Windows:

- **`LuaDLL`** links to `liblua5.1.so`.
- **`LuaStatic`** links Lua in.
- **The hybrid setup** is simpler than on Windows. Add `LuaHostExports` and link with `-k--dynamic-list=src/luaapi.dynlist`. That puts exactly the 123 API names into the executable's dynamic symbol table, and C modules (`.so` files, which aren't linked to a Lua library) find them there. No shim is needed. `build-linux.sh` does this for `lua` and `demo_hybrid`.

The Linux build is for Free Pascal. Delphi's Linux compiler hasn't been tried, and some parts use Free Pascal-specific syntax: the assembler stubs and the C-named aliases in `LuaHostExports`.

## macOS

The macOS build uses the same system layer as the Linux build: the system C library, `dlopen` and real `FILE*` streams. It matches a C Lua 5.1.4 built with clang on the Mac with `LUA_USE_POSIX` and `LUA_USE_DLOPEN`. The differences from Linux are the ones the C build has too:

- **Numbers** print the macOS way: `inf`, and `nan` without a sign (glibc prints `-nan`). `%p` of a null pointer prints `0x0`.
- **Number conversions** follow clang's code for the C casts: on Intel, `%x` of numbers of 2^63 and above differs from gcc's result; on Apple Silicon they saturate as on ARM64 Linux.
- **Varargs:** on Apple Silicon, variadic arguments are passed on the stack (Apple's variant of the ARM64 convention), and `lua_pushfstring`/`luaL_error` read them from there.
- **`os.setlocale`** uses the macOS category numbers, so `os.setlocale(nil, "numeric")` and the rest ask the right category.

What gets built:

| File | What it is |
|---|---|
| `liblua5.1.dylib` | The library, exporting the same 123 functions. Its install name is `@rpath/liblua5.1.dylib`, so a program linked to it finds it through its rpath; `demo_dll` has `@executable_path` as its rpath and finds it next to itself. |
| `lua` | The interpreter, with Lua linked in and the C API exported, so `require` can load C modules. |
| `luac` | The compiler and lister, with Lua linked in. |
| `demo_dll`, `demo_static`, `demo_hybrid` | The demos, as on Linux, with `hello.so`. |

**C modules** are bundles (`.so`, as LuaRocks builds them on macOS) linked with `-undefined dynamic_lookup`, not to a Lua library. They take the API from whatever loaded them: `lua`, a program that uses `liblua5.1.dylib`, or a hybrid program. For the hybrid setup, add `LuaHostExports` and link with `-k-exported_symbols_list -ksrc/luaapi.exp`; `build-macos.sh` does this for `lua` and `demo_hybrid`.

## Compatibility options

These options apply to Windows. On Linux and macOS the C library's behaviour is always used.

| Define | Behaviour |
|---|---|
| *(default)* | Matches the classic MSVC runtime (msvcrt / VC6–VC12) that LuaBinaries were built with. For example, `tostring(1e20)` gives `1e+020`, `1/0` gives `1.#INF`, `0/0` gives `-1.#IND`, and `tonumber("1d2")` is `100`. |
| `LUA_UCRT` | Matches a DLL built with VS2015+ (the UCRT). For example, you get `1e+20`, `inf` and `-nan(ind)`, and `tonumber` accepts `"inf"` and hex floats. |

Set it in `src/lua.inc` or pass it on the command line.

Other emulations of the Microsoft CRT behaviour are written in pure Pascal. They are there so scripts produce the same output as with the C DLL:

- `printf`/`strtod` are exact (bignum based) and `%g/%e/%f` rounding is identical, checked against 32,000 cases.
- `strtoul` wraps at 32 bits.
- `ctype` uses the "C" locale.
- `math.fmod` is exact; `math.pow` is ported from fdlibm.
- `math.random` uses the MSVC `rand()` generator.
- Number-to-integer conversion rounds half-to-even on x86 and truncates on x64.
- Files opened in text mode translate CR/LF and treat Ctrl-Z as end of file.
- `errno` and `strerror` give MSVC-style messages.

## Verification

The scripts are in `tests/` (see [tests/README.md](tests/README.md)). The Windows builds were run under Wine 9 against reference builds of the original C sources (MinGW-w64 `gcc -O2`); the Linux builds natively against a `gcc -O2` build.

**Free Pascal 3.2.2 builds:**

- **Official Lua 5.1 test suite** (`all.lua`): prints "final OK" on Win32 and Win64 in each of these setups:
  - C `lua.exe` with the Pascal `lua5.1.dll`.
  - Pascal `lua.exe` with the Pascal DLL.
  - A C program linked to the proxy `lua51.dll`.
- **C extension module** (`tests/cmod/ctest.c`, which exercises most of the API including `lua_pushfstring`/`luaL_error` varargs, userdata, buffers and errors across C frames): output is identical to the C DLL, both directly and through the proxy, on both platforms.
- **Output diff tests** (`tests/diff`):
  - `difftest.lua` output is identical to the C DLL.
  - In `io_os.lua`, one line differs: a date past year 3000, where Wine's own time limits differ from the MSVC CRT that Lude copies.
- **lua.exe scenarios** (`tests/exe/cases.txt`): 25 command-line cases give identical stdout, stderr and exit codes.
- **luac.exe** (`tests/luac/runluac.sh`), 99 cases: the bytecode files (`luac.out`, with and without `-s`) are byte-identical, and `-l -l` listings, usage and error messages match. The only differences are these:
  - Printed pointers.
  - The CRT style of number formatting, because the reference was built with MinGW.
  - One constant-folded `10^33` on Win64, where MinGW-w64's `pow` is 1 ulp off and Lude gives the correctly rounded result.

**Linux x86-64 and ARM64, Free Pascal 3.2.2 builds:** these were run against Lua 5.1.4 built with gcc from the same sources: natively on x86-64, and on ARM64 under qemu user-mode emulation, with qemu registered in `binfmt_misc` so that `main.lua` can start `lua` through the shell. The results are the same on both:

- **Official test suite:** prints "final OK" with the C `lua` using the Pascal `liblua5.1.so.0`, and with the Pascal `lua`. The run includes `main.lua`, which tests the interpreter's command line.
- **C extension module:** output is identical to the C library, both through the C `lua` and through the Pascal `lua`, where the module finds the API exported from the executable.
- **Output diff tests:** `difftest.lua` and `io_os.lua` give identical output, with no normalisation other than addresses. A further probe of `string.format` and index conversions with NaN, infinities and out-of-range values also matches, and the two processors behave differently here.
- **lua scenarios:** all 25 cases are identical.
- **luac:** all 102 cases are identical, including bytecode files and `-l -l` listings.
- **Demos:** `demo_dll`, `demo_static` and `demo_hybrid` (with `hello.so`) run correctly.

**macOS Intel and Apple Silicon:** cross-compiled on Linux. On an Apple Silicon Mac (Mac Studio, run by DaragonTech), `demo_dll`, `demo_static` and `demo_hybrid` (with `hello.so`) run correctly, and so do all three demos of the Intel build under Rosetta 2. The test suite hasn't been run on a Mac yet. Checked on Linux: every file links, `liblua5.1.dylib` exports exactly the 123 API functions and has the install name `@rpath/liblua5.1.dylib`, `lua` and `demo_hybrid` export the same 123 names, and the ARM64 code signatures are valid. On a Mac, `tests/build_ref.sh … macarm64` (or `macx64`) builds the C reference and `tests/run_all.sh macarm64 build/fpc/macarm64` runs the same comparison as on Linux.

**Delphi 10.2 builds (compiled and tested on Windows 11, re-checked here):**

- The official test suite prints "final OK" with the Delphi `lua5.1.dll` on Win32 and Win64.
- The C extension module gives output identical to the C DLL on both platforms, which covers the Win64 varargs stubs.
- The `difftest.lua` and `io_os.lua` output is byte-identical to the Free Pascal build on both platforms.
- On real Windows (Windows 11 on ARM, x64 through Prism), `lua.exe`, `demo_dll.exe` and `demo_static.exe` run correctly, both with the DLL and with Lua linked in.

## Performance

The Pascal DLLs take about 1.4–1.7× as long as the C DLL overall (geometric mean over 20 benchmarks); on Linux x86-64 the figure is 1.5×. ARM64 hasn't been benchmarked, because timings under emulation aren't meaningful. They are faster than C on pattern matching, string-keyed tables and string concatenation, and slowest on Win32 arithmetic and on number formatting. Full tables, method and analysis are in [PERFORMANCE.md](PERFORMANCE.md).

## Known limitations

Windows:

- **`FILE*` is not a CRT `FILE`.** `io` library file handles are Lude's own stream objects. A C module that takes the userdata from `io.open` and calls `fread`/`fprintf` on the `FILE*` inside it won't work. Very few modules do this.
- **Locales:** `os.setlocale` accepts only `"C"` and `""`; both give the C locale.
- **Time zone:** comes from Windows. The `TZ` environment variable is ignored. As in the MSVC CRT, dates run from 1970 to 3000.
- **FPU state:** the DLL doesn't change the host's FPU control word. On x86 the x87 precision is the host's setting; Delphi's default is 64-bit extended, while an MSVC host uses 53-bit. This can change the last bit of some results. `lua.exe` and `luac.exe` set MSVC's defaults at startup.
- **Extra Delphi exports:** a Delphi-built DLL also exports `dbkFCallWrapperAddr` and `__dbk_fcall_wrapper`, which Delphi adds to every DLL for its debugger. C hosts ignore them.
- **Windows on ARM:** under the Prism (x64) and x86 emulators, `0/0` and `inf - inf` give ARM's positive NaN, so they print as `1.#QNAN` instead of `-1.#IND`. This applies to every emulated program on that machine, including the C `lua5.1.dll`; it changes only the printed text.
- **Redirected stdout is buffered** as in the Microsoft C runtime. When stdout goes to a pipe or file, `print` output is written in blocks, so its order relative to unbuffered stderr can differ from a build whose runtime flushes every line.

Linux and macOS:

- **Locale:** `os.setlocale` changes the C library's locale, as in C. However, character classification (`%a`, `%l` … in patterns, `string.upper`) and number formatting and parsing stay in the "C" locale. With C Lua they would follow a non-"C" locale, for example a decimal comma after `os.setlocale("de_DE.UTF-8")`.
- **Free Pascal only** (see [Linux](#linux)).
- **macOS builds are only partly tested** so far (see [Verification](#verification)).

Both:

- **Changes to the test suite:** see `tests/lua5.1-tests/CHANGES.txt`. In short: a syntax fix in `pm.lua`; `allwin.lua` (Windows) skips `main.lua`, which needs a POSIX shell, and runs `big.lua` on Win32 only; `allposix.lua` (Linux, macOS) runs everything except `big.lua`; and four `tonumber` asserts are disabled because the C build also fails them on Windows and 64-bit Linux, where `strtoul` wraps.

## Layout

```
lua5.dpr  lua51.dpr  lua.dpr  luac.dpr   projects
exports.txt                             the 123 exports of the C lua5.1.dll
src/lua.inc                             shared compiler settings
src/LuaTypes .. LuaUndump, LuaAPI        core    (lobject.c .. lapi.c)
src/LuaAuxLib, Lua*Lib, LuaInit          auxlib + standard libraries
src/LuaCRT, LuaStdio, LuaWin, LuaFPU     MSVC runtime emulation, kernel32 imports (Windows)
src/LuaPosix.pas                        C library imports (Linux, macOS)
src/luaapi.dynlist                      linker list: the C API names a Linux executable exports
src/luaapi.exp                          the same for macOS (-exported_symbols_list)
src/LuaDLL.pas                          import unit for Delphi/FPC host programs (uses lua5.1.dll)
src/LuaStatic.pas                       same interface, Lua linked into the program
demo/                                   host demos: LuaDLL, LuaStatic, hybrid (+ hello.c C module)
src/LuaHostExports.pas                  makes a static-Lua program export the C API
hybrid/lua5.dpr                         shim lua5.1.dll for the hybrid setup
tools/gen_luastatic.py                  regenerates LuaStatic.pas from LuaDLL.pas
tools/gen_hybrid.py                     regenerates LuaHostExports.pas and hybrid/lua5.dpr
build.bat  build-fpc.sh                 build scripts (Delphi / Free Pascal for Windows)
build-linux.sh  build-macos.sh          build scripts (Linux / macOS)
build/fpc/win32, build/fpc/win64       Free Pascal output
build/delphi/win32, build/delphi/win64 Delphi output (build.bat)
build/fpc/linux64, build/fpc/linuxarm64 Linux output (build-linux.sh)
build/fpc/macx64, build/fpc/macarm64   macOS output (build-macos.sh)
tests/                                  verification and benchmark scripts (tests/README.md)
tests/lua5.1-tests/                     official Lua 5.1 test suite (with small changes)
PERFORMANCE.md                          benchmark results
```

## Credits

- **DaragonTech** directed the project and set its requirements (pure Pascal, Delphi support, a drop-in replacement for the C DLLs, Win32 and Win64). DaragonTech also built and tested it on Windows and reported every compiler issue until both platforms compiled cleanly.
- **Claude** (Anthropic's AI model) wrote Lude itself: translating the Lua 5.1.4 core, libraries, `lua.c`, `luac.c` and `print.c` to Pascal, writing the Microsoft C runtime emulation, the proxy DLL and the build scripts, and writing and running the test and benchmark suites.
- **Lua** was created by Roberto Ierusalimschy, Luiz Henrique de Figueiredo and Waldemar Celes at PUC-Rio (https://www.lua.org). Lude follows their C sources file by file.
- The **official Lua 5.1 test suite** is by the Lua authors, taken from the copy in gopher-lua (https://github.com/yuin/gopher-lua).
- **`math.pow`** is ported from fdlibm's `e_pow.c` (Copyright © 1993 Sun Microsystems, freely redistributable).

Lua is Copyright © 1994–2008 Lua.org, PUC-Rio. Lude is Copyright © 2026 DaragonTech and was written by Claude (Anthropic). Both are released under the MIT license; see [LICENSE](LICENSE).
