# Performance

This compares the Pascal `lua5.1.dll`, built with Free Pascal and with Delphi, against the original C Lua 5.1.4, on 32-bit and 64-bit Windows, and the Pascal `liblua5.1.so.0` against the C one on Linux x86-64.

The script is `tests/bench/bench.lua` and the runner is `tests/bench/runbench.sh`; see [tests/README.md](tests/README.md).

## Setup

**How it was run:**
- The same C `lua.exe` runs `bench.lua` each time; only `lua5.1.dll` changes.
- Each DLL ran 3 times, interleaved with the others, and the table shows the best time per test.
- Times are CPU seconds from `os.clock()`. Lower is faster.

**Machine:** Intel Xeon at 2.80 GHz with 2 cores, running Linux with Wine 9. The benchmarks are pure computation, so they run as native x86/x64 code and Wine adds almost nothing. The relative numbers should carry over to Windows, but the absolute times won't.

**The DLLs compared:**

| Column | DLL |
|---|---|
| C | Original Lua 5.1.4 C sources, MinGW-w64 `gcc -O2` (`tests/build_ref.sh`) |
| Free Pascal | This port, Free Pascal 3.2.2, `-O2` (`build-fpc.sh`) |
| Delphi | This port, Delphi 10.2 Tokyo (dcc32/dcc64 32.0), `build.bat` (`-$O+`) |

The C DLL isn't the MSVC-built LuaBinaries DLL. Times for that one may differ.

## Results: seconds (best of 3)

| test | C 32 | Free Pascal 32 | Delphi 32 | C 64 | Free Pascal 64 | Delphi 64 |
|---|---|---|---|---|---|---|
| fib (recursive calls) | **0.696** | 1.237 | 1.116 | **0.613** | 0.861 | 1.108 |
| loop_arith | **0.562** | 2.568 | 2.508 | **0.486** | 0.824 | 0.896 |
| float_math | **0.602** | 1.151 | 1.134 | **0.529** | 0.700 | 0.672 |
| pow_fmod | **0.432** | 1.361 | 1.346 | **0.407** | 0.692 | 0.731 |
| table_array | **0.173** | 0.439 | 0.429 | **0.132** | 0.199 | 0.237 |
| table_hash | 0.394 | 0.392 | **0.384** | 0.399 | **0.373** | **0.373** |
| table_sort | **0.462** | 0.750 | 0.636 | **0.367** | 0.585 | 0.610 |
| str_concat | 0.607 | 0.588 | **0.562** | 0.544 | **0.446** | 0.499 |
| str_format | **0.744** | 2.304 | 3.859 | **0.633** | 2.119 | 1.445 |
| tostring_num | **0.645** | 1.446 | 3.607 | **0.559** | 1.332 | 1.007 |
| str_patterns | 0.152 | 0.091 | **0.077** | 0.119 | 0.086 | **0.083** |
| str_ops | **0.440** | 0.653 | 0.565 | **0.360** | 0.488 | 0.503 |
| closures | **0.635** | 0.787 | 0.715 | **0.539** | 0.608 | 0.648 |
| oop_methods | **1.034** | 1.459 | 1.362 | **0.835** | 1.159 | 1.245 |
| metamethods | **0.265** | 0.487 | 0.453 | **0.196** | 0.310 | 0.368 |
| coroutines | **0.100** | 0.158 | 0.134 | **0.081** | 0.100 | 0.129 |
| pcall_error | **0.153** | 0.495 | 0.359 | **0.431** | 1.386 | 1.048 |
| gc_alloc | **0.374** | 0.461 | 0.425 | **0.330** | 0.372 | 0.386 |
| compile | **0.509** | 0.605 | 0.557 | **0.398** | 0.479 | 0.499 |
| dump_load | **0.238** | 0.309 | 0.254 | **0.219** | 0.246 | 0.266 |
| **Total** | **9.22** | 17.74 | 20.48 | **8.18** | 13.37 | 12.75 |

Bold marks the fastest within each group (32-bit and 64-bit).

## Results: relative to C

Each value is the Pascal time divided by the C time. Below 1.00 means the Pascal DLL was faster.

| test | Free Pascal 32 | Delphi 32 | Free Pascal 64 | Delphi 64 |
|---|---|---|---|---|
| fib | 1.78 | 1.60 | 1.40 | 1.81 |
| loop_arith | 4.57 | 4.46 | 1.70 | 1.84 |
| float_math | 1.91 | 1.88 | 1.32 | 1.27 |
| pow_fmod | 3.15 | 3.12 | 1.70 | 1.80 |
| table_array | 2.54 | 2.48 | 1.51 | 1.80 |
| table_hash | 0.99 | 0.97 | 0.93 | 0.93 |
| table_sort | 1.62 | 1.38 | 1.59 | 1.66 |
| str_concat | 0.97 | 0.93 | 0.82 | 0.92 |
| str_format | 3.10 | 5.19 | 3.35 | 2.28 |
| tostring_num | 2.24 | 5.59 | 2.38 | 1.80 |
| str_patterns | 0.60 | 0.51 | 0.72 | 0.70 |
| str_ops | 1.48 | 1.28 | 1.36 | 1.40 |
| closures | 1.24 | 1.13 | 1.13 | 1.20 |
| oop_methods | 1.41 | 1.32 | 1.39 | 1.49 |
| metamethods | 1.84 | 1.71 | 1.58 | 1.88 |
| coroutines | 1.58 | 1.34 | 1.23 | 1.59 |
| pcall_error | 3.24 | 2.35 | 3.22 | 2.43 |
| gc_alloc | 1.23 | 1.14 | 1.13 | 1.17 |
| compile | 1.19 | 1.09 | 1.20 | 1.25 |
| dump_load | 1.30 | 1.07 | 1.12 | 1.21 |
| **Total time** | **1.92** | **2.22** | **1.63** | **1.56** |
| **Geometric mean** | **1.69** | **1.66** | **1.42** | **1.46** |

## What the numbers show

- **Overall:** the Pascal DLLs take about 1.4–1.7× as long as the C DLL (geometric mean). Free Pascal and Delphi are close; Delphi is a little faster on Win32 except for number formatting.
- **Faster than C:** pattern matching (`gmatch`, `gsub`, `find`, `match`), string-keyed hash tables and string concatenation. These spend most of their time in memory allocation and byte search. The port uses the Windows heap and its own `memchr`/`memcmp`, which are faster here than the C runtime used by the MinGW build.
- **Arithmetic in the interpreter loop** (`loop_arith`, `pow_fmod`, `table_array`) is the largest gap on Win32, about 2.5–4.6×. Both Pascal compilers generate x87 floating-point code for Win32 that is much slower than gcc's. The NaN-safe comparison helpers the port needs, because Delphi's Win32 NaN comparisons are wrong, add to it. On Win64 (SSE2) the gap drops to about 1.5–1.8×.
- **Number formatting** (`tostring`, `string.format` with `%g`/`%f`): 2–5.6× slower. The port formats and parses numbers with exact big-integer arithmetic, so the output is digit-for-digit identical to the Microsoft C runtime. Delphi's 32-bit compiler is particularly slow at the 64-bit integer operations this relies on.
- **`pcall` with errors:** about 2.4–3.2× slower. Lua errors are Pascal exceptions, which cost more than C's `setjmp`/`longjmp`.

## Linux x86-64

Same method, run natively on the same machine (no Wine). The C `lua` (built with gcc `-O2`, linked to `liblua5.1.so.0`) runs `bench.lua` with each library:

| Column | Library |
|---|---|
| C | Lua 5.1.4 C sources, gcc 13 `-O2` (`tests/build_ref.sh … linux64`) |
| Free Pascal | Lude, Free Pascal 3.2.2 `-O2` (`build-linux.sh`) |

Times are in seconds, best of 3, lower is faster. The ratio is Free Pascal time divided by C time.

| test | C | Free Pascal | ratio |
|---|---|---|---|
| fib | **0.609** | 0.931 | 1.53 |
| loop_arith | **0.504** | 0.855 | 1.70 |
| float_math | **0.337** | 0.487 | 1.45 |
| pow_fmod | **0.282** | 0.370 | 1.31 |
| table_array | **0.103** | 0.185 | 1.80 |
| table_hash | 0.512 | **0.438** | 0.86 |
| table_sort | **0.501** | 0.721 | 1.44 |
| str_concat | 0.731 | **0.555** | 0.76 |
| str_format | **0.497** | 1.624 | 3.27 |
| tostring_num | **0.357** | 1.023 | 2.87 |
| str_patterns | **0.063** | 0.087 | 1.38 |
| str_ops | **0.359** | 0.531 | 1.48 |
| closures | **0.367** | 0.456 | 1.24 |
| oop_methods | **0.726** | 1.098 | 1.51 |
| metamethods | **0.195** | 0.327 | 1.68 |
| coroutines | **0.082** | 0.109 | 1.33 |
| pcall_error | **0.112** | 0.194 | 1.73 |
| gc_alloc | **0.207** | 0.284 | 1.37 |
| compile | **0.304** | 0.429 | 1.41 |
| dump_load | **0.185** | 0.237 | 1.28 |
| **Total** | **7.03** | 10.94 | **1.56** |
| **Geometric mean** | | | **1.49** |

The picture is the same as on Win64: about 1.5× overall. Hash tables and string concatenation are faster than C, and number formatting (`str_format`, `tostring_num`) is the slowest part. `pcall_error` costs less than on Windows (1.7× instead of 2.4–3.2×), and pattern matching is slower than C here (1.4×) where it was faster on Windows, probably because glibc's string functions are faster than the Windows C runtime's.

ARM64 isn't benchmarked here: the ARM64 build was only run under qemu emulation, where timings don't reflect real hardware. `tests/bench/runbench.sh … linuxarm64` measures it on a real ARM64 machine. The macOS builds haven't been benchmarked either; on a Mac, `tests/bench/runbench.sh 3 1 C=$REFDIR/macarm64/liblua5.1.dylib:macarm64 PAS=build/fpc/macarm64/liblua5.1.dylib:macarm64` does it.

## Possible optimisations

None of these would change any output:
1. A fast path for `%.14g` and friends, falling back to the exact code only in the rare cases where it can't guarantee the right digits.
2. Streamlining arithmetic and comparisons in the interpreter loop: fewer helper calls and a cheaper NaN check.
3. Lighter error unwinding for `pcall`.
