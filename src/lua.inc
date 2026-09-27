{ Common compiler settings for the Lua 5.1.4 Pascal port.
  Works with Delphi 10.2 Tokyo (Win32/Win64) and Free Pascal 3.2+ (MODE DELPHI). }

{$IFDEF FPC}
  {$MODE DELPHI}
  {$IFDEF CPUI386}{$ASMMODE INTEL}{$ENDIF}
  {$IFDEF CPUX86_64}{$ASMMODE INTEL}{$ENDIF}
  {$GOTO ON}
  {$MACRO OFF}
  {$INLINE ON}
  {$PACKENUM 4}
  {$IFDEF CPU64}{$DEFINE LUA_64}{$ENDIF}
  {$IFDEF CPUI386}{$DEFINE LUA_X86}{$ENDIF}
{$ELSE}
  {$IFDEF CPUX64}{$DEFINE LUA_64}{$ENDIF}
  {$IFDEF CPUX86}{$DEFINE LUA_X86}{$ENDIF}
  {$WARN SYMBOL_PLATFORM OFF}
  {$WARN UNSAFE_TYPE OFF}
  {$WARN UNSAFE_CODE OFF}
  {$WARN UNSAFE_CAST OFF}
  {$WARN COMBINING_SIGNED_UNSIGNED OFF}
  {$WARN COMPARING_SIGNED_UNSIGNED OFF}
  {$WARN IMPLICIT_STRING_CAST OFF}
  {$WARN IMPLICIT_STRING_CAST_LOSS OFF}
  {$MINENUMSIZE 4}
{$ENDIF}

{$POINTERMATH ON}
{$RANGECHECKS OFF}
{$OVERFLOWCHECKS OFF}
{$BOOLEVAL OFF}
{$EXTENDEDSYNTAX ON}
{$TYPEDADDRESS OFF}
{$ALIGN 8}
{$HINTS OFF}

{ ---- C runtime emulation style -------------------------------------------
  LUA_UCRT undefined (default): behave like the classic MSVC runtime
  (msvcrt / VC6..VC12) that the LuaBinaries lua5.1.dll was built with:
    tostring(1e20)   -> 1e+020        (3-digit exponents)
    tostring(1/0)    -> 1.#INF        tostring(0/0) -> -1.#IND
    tonumber("1d2")  -> 100           (Fortran 'd' exponent accepted)
  Define LUA_UCRT to behave like a lua5.1.dll built with VS2015+ (UCRT):
    1e+20, inf, -nan(ind), tonumber("inf"), hex floats accepted by strtod. }
{.$DEFINE LUA_UCRT}

{ ---- target system -------------------------------------------------------
  Windows: Microsoft C runtime emulated in Pascal (above).
  Other systems (Linux): LUA_POSIX - the system C library is used directly
  (stdio FILE*, malloc, dlopen, libm), with glibc-style number formatting
  (which is what LUA_UCRT selects, plus "inf"/"nan" spelling). }
{$IFNDEF MSWINDOWS}
  {$DEFINE LUA_POSIX}
  {$DEFINE LUA_UCRT}
{$ENDIF}
