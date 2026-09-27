{
  Lua 5.1.4 - Pascal port
  Emulation of the parts of the Microsoft C runtime that Lua depends on,
  written in pure Pascal so the results match a lua5.1.dll built with MSVC:

    * strtod / strtoul                 (number parsing)
    * printf-style formatting of numbers ("%.14g", string.format)
    * <ctype.h> in the "C" locale
    * fmod, pow (fdlibm), floor, ceil, frexp, ldexp, modf, sinh, cosh, tanh
    * rand / srand (MSVC linear congruential generator)
    * lua_number2int / lua_number2integer conversions

  By default the classic msvcrt behaviour is emulated (see lua.inc,
  define LUA_UCRT for the VS2015+ Universal CRT behaviour).
}
unit LuaCRT;

{$I lua.inc}

interface

uses
  LuaTypes;

{ ---- ctype ("C" locale) ---- }
function c_isalpha(c: Integer): Boolean; inline;
function c_isdigit(c: Integer): Boolean; inline;
function c_isalnum(c: Integer): Boolean; inline;
function c_isspace(c: Integer): Boolean; inline;
function c_iscntrl(c: Integer): Boolean; inline;
function c_islower(c: Integer): Boolean; inline;
function c_isupper(c: Integer): Boolean; inline;
function c_ispunct(c: Integer): Boolean; inline;
function c_isxdigit(c: Integer): Boolean; inline;
function c_tolower(c: Integer): Integer; inline;
function c_toupper(c: Integer): Integer; inline;

{ ---- <string.h> ---- }
function c_strlen(s: PAnsiChar): size_t;
function c_strchr(s: PAnsiChar; c: Integer): PAnsiChar;
function c_strcmp(a, b: PAnsiChar): Integer;
function c_strcoll(a, b: PAnsiChar): Integer;
function c_memcmp(a, b: Pointer; n: size_t): Integer;
function c_memchr(s: Pointer; c: Integer; n: size_t): Pointer;
function c_strcspn(s, reject: PAnsiChar): size_t;
function c_strspn(s, accept: PAnsiChar): size_t;
function c_strpbrk(s, accept: PAnsiChar): PAnsiChar;
function c_strstr(s, sub: PAnsiChar): PAnsiChar;
procedure c_strcpy(dst, src: PAnsiChar);
procedure c_strcat(dst, src: PAnsiChar);
procedure c_strncpy(dst, src: PAnsiChar; n: size_t);
procedure c_strncat(dst, src: PAnsiChar; n: size_t);

{ ---- number parsing ---- }
function c_strtod(s: PAnsiChar; endptr: PPAnsiChar): Double;
function c_strtoul(s: PAnsiChar; endptr: PPAnsiChar; base: Integer): c_ulong;

{ ---- number formatting ----
  'form' is a single printf conversion spec such as '%-5.2f' (NUL terminated).
  The result is what MSVC sprintf(buff, form, value) writes into buff. }
function c_fmt_double(form: PAnsiChar; x: Double): AnsiString;
function c_fmt_long(form: PAnsiChar; v: c_long): AnsiString;
function c_fmt_str(form: PAnsiChar; s: PAnsiChar): AnsiString;
{ sprintf(buf, "%.14g", n); buf must hold LUAI_MAXNUMBER2STR chars }
procedure lua_number2str(buf: PAnsiChar; n: lua_Number);
{ sprintf(buf, "%p", p) }
function c_fmt_pointer(p: Pointer): AnsiString;
function c_itoa(v: Int64): AnsiString;   { decimal, like %d / %lld }

{ ---- IEEE-correct comparisons (Delphi Win32 mis-compiles NaN compares) ---- }
function luai_numeq(a, b: Double): Boolean; inline;
function luai_numlt(a, b: Double): Boolean; inline;
function luai_numle(a, b: Double): Boolean; inline;
function luai_numisnan(a: Double): Boolean; inline;
function luai_numunm(a: Double): Double; inline;   { -a as a sign flip, like C (keeps NaN payload, flips its sign) }

{ ---- conversions ---- }
function lua_number2int(d: lua_Number): Integer; inline;
function lua_number2integer(d: lua_Number): lua_Integer; inline;
function c_double2long(d: Double): c_long;         { (long)d  - truncation }
function c_double2ulong(d: Double): c_ulong;      { (unsigned long)d }
function c_double2int_trunc(d: Double): Integer;   { (int)d }

{ ---- <math.h> ---- }
function c_isnan(x: Double): Boolean; inline;
function c_floor(x: Double): Double;
function c_ceil(x: Double): Double;
function c_fmod(x, y: Double): Double;
function c_pow(x, y: Double): Double;
function c_frexp(x: Double; var e: Integer): Double;
function c_ldexp(x: Double; e: Integer): Double;
function c_modf(x: Double; var ip: Double): Double;
function c_fabs(x: Double): Double; inline;
function c_sinh(x: Double): Double;
function c_cosh(x: Double): Double;
function c_tanh(x: Double): Double;
function c_log10(x: Double): Double;
function c_log(x: Double): Double;
function c_exp(x: Double): Double;
function c_sqrt(x: Double): Double;
function c_atan2(y, x: Double): Double;
function c_asin(x: Double): Double;
function c_acos(x: Double): Double;
function c_tan(x: Double): Double;
function c_sin(x: Double): Double;
function c_cos(x: Double): Double;
function c_atan(x: Double): Double;
function HUGE_VAL: Double;

{ ---- <stdlib.h> ---- }
const
{$IFDEF LUA_POSIX}
  RAND_MAX = 2147483647;   { glibc; c_rand/c_srand are libc's rand/srand }
{$ELSE}
  RAND_MAX = 32767;
{$ENDIF}
function c_rand: Integer;
procedure c_srand(seed: Cardinal);

implementation

{$IFDEF LUA_POSIX}
uses
  LuaPosix;
{$ENDIF}

{$IFDEF FPC}
type
  UInt64 = QWord;
{$ENDIF}
type
  PUInt64 = ^UInt64;

{ ====================================================================
  ctype
  ==================================================================== }

function c_isalpha(c: Integer): Boolean;
begin
  Result := ((c >= Ord('a')) and (c <= Ord('z'))) or ((c >= Ord('A')) and (c <= Ord('Z')));
end;

function c_isdigit(c: Integer): Boolean;
begin
  Result := (c >= Ord('0')) and (c <= Ord('9'));
end;

function c_isalnum(c: Integer): Boolean;
begin
  Result := c_isalpha(c) or c_isdigit(c);
end;

function c_isspace(c: Integer): Boolean;
begin
  Result := (c = 32) or ((c >= 9) and (c <= 13));
end;

function c_iscntrl(c: Integer): Boolean;
begin
  Result := ((c >= 0) and (c < 32)) or (c = 127);
end;

function c_islower(c: Integer): Boolean;
begin
  Result := (c >= Ord('a')) and (c <= Ord('z'));
end;

function c_isupper(c: Integer): Boolean;
begin
  Result := (c >= Ord('A')) and (c <= Ord('Z'));
end;

function c_ispunct(c: Integer): Boolean;
begin
  Result := (c > 32) and (c < 127) and not c_isalnum(c);
end;

function c_isxdigit(c: Integer): Boolean;
begin
  Result := c_isdigit(c) or ((c >= Ord('a')) and (c <= Ord('f'))) or ((c >= Ord('A')) and (c <= Ord('F')));
end;

function c_tolower(c: Integer): Integer;
begin
  if c_isupper(c) then Result := c + 32 else Result := c;
end;

function c_toupper(c: Integer): Integer;
begin
  if c_islower(c) then Result := c - 32 else Result := c;
end;

{ ====================================================================
  string.h
  ==================================================================== }

function c_strlen(s: PAnsiChar): size_t;
var p: PAnsiChar;
begin
  p := s;
  while p^ <> #0 do Inc(p);
  Result := size_t(p - s);
end;

function c_strchr(s: PAnsiChar; c: Integer): PAnsiChar;
var ch: AnsiChar;
begin
  ch := AnsiChar(c and $FF);
  while True do
  begin
    if s^ = ch then Exit(s);
    if s^ = #0 then Exit(nil);
    Inc(s);
  end;
end;

function c_strcmp(a, b: PAnsiChar): Integer;
begin
  while (a^ = b^) and (a^ <> #0) do
  begin
    Inc(a); Inc(b);
  end;
  Result := Integer(Byte(a^)) - Integer(Byte(b^));
end;

function c_strcoll(a, b: PAnsiChar): Integer;
begin
  { "C" locale: strcoll == strcmp }
  Result := c_strcmp(a, b);
end;

function c_memcmp(a, b: Pointer; n: size_t): Integer;
var pa, pb: PByte;
begin
  pa := a; pb := b;
  while n > 0 do
  begin
    if pa^ <> pb^ then Exit(Integer(pa^) - Integer(pb^));
    Inc(pa); Inc(pb); Dec(n);
  end;
  Result := 0;
end;

function c_memchr(s: Pointer; c: Integer; n: size_t): Pointer;
var p: PByte;
begin
  p := s;
  while n > 0 do
  begin
    if p^ = Byte(c) then Exit(p);
    Inc(p); Dec(n);
  end;
  Result := nil;
end;

function c_strcspn(s, reject: PAnsiChar): size_t;
var p: PAnsiChar;
begin
  p := s;
  while (p^ <> #0) and (c_strchr(reject, Ord(p^)) = nil) do Inc(p);
  Result := size_t(p - s);
end;

function c_strspn(s, accept: PAnsiChar): size_t;
var p: PAnsiChar;
begin
  p := s;
  while (p^ <> #0) and (c_strchr(accept, Ord(p^)) <> nil) do Inc(p);
  Result := size_t(p - s);
end;

function c_strpbrk(s, accept: PAnsiChar): PAnsiChar;
begin
  while s^ <> #0 do
  begin
    if c_strchr(accept, Ord(s^)) <> nil then Exit(s);
    Inc(s);
  end;
  Result := nil;
end;

function c_strstr(s, sub: PAnsiChar): PAnsiChar;
var a, b: PAnsiChar;
begin
  if sub^ = #0 then Exit(s);
  while s^ <> #0 do
  begin
    a := s; b := sub;
    while (b^ <> #0) and (a^ = b^) do begin Inc(a); Inc(b); end;
    if b^ = #0 then Exit(s);
    Inc(s);
  end;
  Result := nil;
end;

procedure c_strcpy(dst, src: PAnsiChar);
begin
  repeat
    dst^ := src^;
    Inc(dst);
    Inc(src);
  until (src - 1)^ = #0;
end;

procedure c_strcat(dst, src: PAnsiChar);
begin
  c_strcpy(dst + c_strlen(dst), src);
end;

procedure c_strncpy(dst, src: PAnsiChar; n: size_t);
begin
  while (n > 0) and (src^ <> #0) do
  begin
    dst^ := src^; Inc(dst); Inc(src); Dec(n);
  end;
  while n > 0 do
  begin
    dst^ := #0; Inc(dst); Dec(n);
  end;
end;

procedure c_strncat(dst, src: PAnsiChar; n: size_t);
begin
  dst := dst + c_strlen(dst);
  while (n > 0) and (src^ <> #0) do
  begin
    dst^ := src^; Inc(dst); Inc(src); Dec(n);
  end;
  dst^ := #0;
end;

{ ====================================================================
  Double bit helpers
  ==================================================================== }

function DblBits(const d: Double): UInt64; inline;
begin
  Result := PUInt64(@d)^;
end;

function BitsDbl(b: UInt64): Double; inline;
begin
  PUInt64(@Result)^ := b;
end;

function HiW(const d: Double): Integer; inline;
begin
  Result := Integer(PUInt64(@d)^ shr 32);
end;

function LoW(const d: Double): Cardinal; inline;
begin
  Result := Cardinal(PUInt64(@d)^);
end;

procedure SetLoW(var d: Double; v: Cardinal); inline;
begin
  PUInt64(@d)^ := (PUInt64(@d)^ and UInt64((UInt64($FFFFFFFF) shl 32 or UInt64($00000000)))) or v;
end;

procedure SetHiW(var d: Double; v: Integer); inline;
begin
  PUInt64(@d)^ := (PUInt64(@d)^ and UInt64($00000000FFFFFFFF)) or (UInt64(Cardinal(v)) shl 32);
end;

function MakeDbl(hi: Integer; lo: Cardinal): Double; inline;
begin
  PUInt64(@Result)^ := (UInt64(Cardinal(hi)) shl 32) or lo;
end;

function HUGE_VAL: Double;
begin
  Result := BitsDbl(UInt64($7FF0000000000000));
end;

function c_isnan(x: Double): Boolean;
begin
  { only System symbols here: inline routines of the interface may not
    use implementation-local ones (Delphi E2441) }
  Result := (PInt64(@x)^ and $7FFFFFFFFFFFFFFF) > $7FF0000000000000;
end;

function IsInfOrNaN(x: Double): Boolean; inline;
begin
  Result := (DblBits(x) and UInt64($7FF0000000000000)) = UInt64($7FF0000000000000);
end;

function c_fabs(x: Double): Double;
begin
  PInt64(@Result)^ := PInt64(@x)^ and $7FFFFFFFFFFFFFFF;
end;

{ ====================================================================
  Big natural numbers (little endian, base 2^32), fixed capacity
  ==================================================================== }
const
  BIGCAP = 200;
type
  TBig = record
    n: Integer;                               { number of used limbs }
    d: array[0..BIGCAP - 1] of Cardinal;
  end;

procedure BigSetU64(var a: TBig; v: UInt64);
begin
  a.n := 0;
  while v <> 0 do
  begin
    a.d[a.n] := Cardinal(v);
    v := v shr 32;
    Inc(a.n);
  end;
end;

procedure BigMulSmall(var a: TBig; m: Cardinal);
var i: Integer; carry, t: UInt64;
begin
  carry := 0;
  for i := 0 to a.n - 1 do
  begin
    t := UInt64(a.d[i]) * m + carry;
    a.d[i] := Cardinal(t);
    carry := t shr 32;
  end;
  if carry <> 0 then
  begin
    a.d[a.n] := Cardinal(carry);
    Inc(a.n);
  end;
end;

procedure BigAddSmall(var a: TBig; v: Cardinal);
var i: Integer; t: UInt64;
begin
  i := 0;
  t := v;
  while t <> 0 do
  begin
    if i >= a.n then
    begin
      a.d[i] := 0;
      a.n := i + 1;
    end;
    t := t + a.d[i];
    a.d[i] := Cardinal(t);
    t := t shr 32;
    Inc(i);
  end;
end;

procedure BigMulPow5(var a: TBig; e: Integer);
begin
  while e >= 13 do begin BigMulSmall(a, 1220703125); Dec(e, 13); end;   { 5^13 }
  while e > 0 do begin BigMulSmall(a, 5); Dec(e); end;
end;

procedure BigMulPow10(var a: TBig; e: Integer);
begin
  while e >= 9 do begin BigMulSmall(a, 1000000000); Dec(e, 9); end;
  while e > 0 do begin BigMulSmall(a, 10); Dec(e); end;
end;

procedure BigShl(var a: TBig; bits: Integer);
var limbs, sh, i: Integer;
begin
  if (a.n = 0) or (bits <= 0) then Exit;
  limbs := bits div 32;
  sh := bits mod 32;
  if sh <> 0 then
  begin
    a.d[a.n] := 0;
    for i := a.n downto 1 do
      a.d[i] := (a.d[i] shl sh) or (a.d[i - 1] shr (32 - sh));
    a.d[0] := a.d[0] shl sh;
    Inc(a.n);
    if a.d[a.n - 1] = 0 then Dec(a.n);
  end;
  if limbs > 0 then
  begin
    for i := a.n - 1 downto 0 do a.d[i + limbs] := a.d[i];
    for i := 0 to limbs - 1 do a.d[i] := 0;
    Inc(a.n, limbs);
  end;
end;

procedure BigShr1(var a: TBig);
var i: Integer;
begin
  for i := 0 to a.n - 1 do
  begin
    a.d[i] := a.d[i] shr 1;
    if i + 1 < a.n then a.d[i] := a.d[i] or (a.d[i + 1] shl 31);
  end;
  while (a.n > 0) and (a.d[a.n - 1] = 0) do Dec(a.n);
end;

function BigBitLen(const a: TBig): Integer;
var top: Cardinal;
begin
  if a.n = 0 then Exit(0);
  Result := (a.n - 1) * 32;
  top := a.d[a.n - 1];
  while top <> 0 do begin Inc(Result); top := top shr 1; end;
end;

function BigCmp(const a, b: TBig): Integer;
var i: Integer;
begin
  if a.n <> b.n then
  begin
    if a.n > b.n then Exit(1) else Exit(-1);
  end;
  for i := a.n - 1 downto 0 do
    if a.d[i] <> b.d[i] then
    begin
      if a.d[i] > b.d[i] then Exit(1) else Exit(-1);
    end;
  Result := 0;
end;

procedure BigSub(var a: TBig; const b: TBig);  { a := a - b, requires a >= b }
var i: Integer; borrow, t: Int64;
begin
  borrow := 0;
  for i := 0 to a.n - 1 do
  begin
    t := Int64(a.d[i]) - borrow;
    if i < b.n then t := t - Int64(b.d[i]);
    if t < 0 then begin t := t + $100000000; borrow := 1; end else borrow := 0;
    a.d[i] := Cardinal(t);
  end;
  while (a.n > 0) and (a.d[a.n - 1] = 0) do Dec(a.n);
end;

function BigDivSmall(var a: TBig; dv: Cardinal): Cardinal;  { returns remainder }
var i: Integer; r: UInt64;
begin
  r := 0;
  for i := a.n - 1 downto 0 do
  begin
    r := (r shl 32) or a.d[i];
    a.d[i] := Cardinal(r div dv);
    r := r mod dv;
  end;
  while (a.n > 0) and (a.d[a.n - 1] = 0) do Dec(a.n);
  Result := Cardinal(r);
end;

{ top 64 bits of a (a <> 0); returns exponent such that a ~= q * 2^e }
procedure BigTop64(const a: TBig; out q: UInt64; out e: Integer; out sticky: Boolean);
var bl, sh, i, limb, bit: Integer;
begin
  bl := BigBitLen(a);
  if bl <= 64 then
  begin
    q := 0;
    for i := a.n - 1 downto 0 do q := (q shl 32) or a.d[i];
    e := 0;
    sticky := False;
    Exit;
  end;
  sh := bl - 64;
  q := 0;
  for i := bl - 1 downto sh do
  begin
    limb := i div 32; bit := i mod 32;
    q := (q shl 1) or ((a.d[limb] shr bit) and 1);
  end;
  e := sh;
  sticky := False;
  for i := 0 to sh - 1 do
  begin
    limb := i div 32;
    if (i mod 32 = 0) and (i + 32 <= sh) then
    begin
      if a.d[limb] <> 0 then begin sticky := True; Break; end;
    end
    else if ((a.d[limb] shr (i mod 32)) and 1) <> 0 then
    begin
      sticky := True; Break;
    end;
  end;
end;

{ decimal digits of a (destroys a) }
function BigToDec(var a: TBig): AnsiString;
var chunks: array[0..BIGCAP * 2] of Cardinal;
    nc, i, j: Integer; s: AnsiString; c: Cardinal;
begin
  if a.n = 0 then Exit('0');
  nc := 0;
  while a.n > 0 do
  begin
    chunks[nc] := BigDivSmall(a, 1000000000);
    Inc(nc);
  end;
  Result := '';
  for i := nc - 1 downto 0 do
  begin
    SetLength(s, 9);
    c := chunks[i];
    for j := 9 downto 1 do begin s[j] := AnsiChar(Ord('0') + c mod 10); c := c div 10; end;
    Result := Result + s;
  end;
  i := 1;
  while (i < Length(Result)) and (Result[i] = '0') do Inc(i);
  Delete(Result, 1, i - 1);
end;

{ q * 2^e2 (+ sticky bits below) rounded to nearest-even double }
function RoundToDouble(q: UInt64; e2: Integer; sticky: Boolean; neg: Boolean): Double;
var bl, msbexp, keep, drop: Integer; mant, rem, half: UInt64; bits: UInt64; lsbexp: Integer;
begin
  if q = 0 then
  begin
    if neg then Exit(BitsDbl(UInt64((UInt64($80000000) shl 32 or UInt64($00000000))))) else Exit(0.0);
  end;
  bl := 0;
  mant := q;
  while mant <> 0 do begin Inc(bl); mant := mant shr 1; end;
  msbexp := bl - 1 + e2;
  if msbexp > 1023 then
  begin
    bits := UInt64($7FF0000000000000);
    if neg then bits := bits or UInt64((UInt64($80000000) shl 32 or UInt64($00000000)));
    Exit(BitsDbl(bits));
  end;
  keep := 53;
  lsbexp := msbexp - 52;
  if lsbexp < -1074 then keep := 53 - (-1074 - lsbexp);
  if keep < 0 then
    mant := 0
  else if keep = 0 then
  begin
    { value in (0, 2^-1074): round to 0 or min subnormal }
    half := UInt64(1) shl (bl - 1);
    if (q > half) or ((q = half) and sticky) then mant := 1 else mant := 0;
    { mant is at weight 2^-1074 }
    bits := mant;
    if neg then bits := bits or UInt64((UInt64($80000000) shl 32 or UInt64($00000000)));
    Exit(BitsDbl(bits));
  end
  else
  begin
    drop := bl - keep;
    if drop > 0 then
    begin
      mant := q shr drop;
      if drop >= 64 then rem := q else rem := q and ((UInt64(1) shl drop) - 1);
      half := UInt64(1) shl (drop - 1);
      if (rem > half) or ((rem = half) and (sticky or ((mant and 1) <> 0))) then
        Inc(mant);
    end
    else
      mant := q shl (-drop);
  end;
  { now value = mant * 2^(msbexp - keep + 1) }
  if keep >= 53 then
  begin
    if mant >= (UInt64(1) shl 53) then
    begin
      mant := mant shr 1;
      Inc(msbexp);
      if msbexp > 1023 then
      begin
        bits := UInt64($7FF0000000000000);
        if neg then bits := bits or UInt64((UInt64($80000000) shl 32 or UInt64($00000000)));
        Exit(BitsDbl(bits));
      end;
    end;
    bits := (UInt64(msbexp + 1023) shl 52) or (mant and UInt64($000FFFFFFFFFFFFF));
  end
  else
  begin
    { subnormal: mant is at weight 2^-1074; may have become normal by rounding }
    bits := mant;   { a carry into bit 52 yields the smallest normal: encoding still correct }
  end;
  if neg then bits := bits or UInt64((UInt64($80000000) shl 32 or UInt64($00000000)));
  Result := BitsDbl(bits);
end;

{ ====================================================================
  strtod
  ==================================================================== }

const
  MAXSIGDIGITS = 800;

function DecimalToDouble(const digits: AnsiString; exp10: Integer; neg: Boolean): Double;
{ value = 0.digits... no: value = digits (as integer) * 10^exp10 }
var a, b: TBig; i, nd, s, bitD, bitB: Integer; q, bitv: UInt64; e2: Integer; sticky: Boolean;
    v: UInt64;
begin
  nd := Length(digits);
  if nd = 0 then
  begin
    if neg then Exit(BitsDbl(UInt64((UInt64($80000000) shl 32 or UInt64($00000000))))) else Exit(0.0);
  end;
  { quick range checks }
  if nd + exp10 > 311 then Exit(RoundToDouble(1, 2000, False, neg));
  if nd + exp10 < -326 then Exit(RoundToDouble(0, 0, False, neg));
  { exact small integers }
  if (nd <= 19) and (exp10 >= 0) and (nd + exp10 <= 19) then
  begin
    v := 0;
    for i := 1 to nd do v := v * 10 + UInt64(Ord(digits[i]) - Ord('0'));
    for i := 1 to exp10 do v := v * 10;
    Exit(RoundToDouble(v, 0, False, neg));
  end;
  a.n := 0;
  i := 1;
  while i <= nd do
  begin
    { feed up to 9 digits at a time }
    v := 0; s := 0;
    while (i <= nd) and (s < 9) do
    begin
      v := v * 10 + UInt64(Ord(digits[i]) - Ord('0'));
      Inc(i); Inc(s);
    end;
    case s of
      1: BigMulSmall(a, 10);
      2: BigMulSmall(a, 100);
      3: BigMulSmall(a, 1000);
      4: BigMulSmall(a, 10000);
      5: BigMulSmall(a, 100000);
      6: BigMulSmall(a, 1000000);
      7: BigMulSmall(a, 10000000);
      8: BigMulSmall(a, 100000000);
      9: BigMulSmall(a, 1000000000);
    end;
    BigAddSmall(a, Cardinal(v));
  end;
  if a.n = 0 then Exit(RoundToDouble(0, 0, False, neg));
  if exp10 >= 0 then
  begin
    BigMulPow10(a, exp10);
    BigTop64(a, q, e2, sticky);
    Exit(RoundToDouble(q, e2, sticky, neg));
  end;
  { a / 10^k }
  BigSetU64(b, 1);
  BigMulPow10(b, -exp10);
  bitD := BigBitLen(a);
  bitB := BigBitLen(b);
  s := 63 + bitB - bitD;
  if s > 0 then BigShl(a, s) else if s < 0 then BigShl(b, -s);
  BigShl(b, 63);
  q := 0;
  bitv := UInt64(1) shl 63;
  for i := 63 downto 0 do
  begin
    if BigCmp(a, b) >= 0 then
    begin
      BigSub(a, b);
      q := q or bitv;
    end;
    bitv := bitv shr 1;
    BigShr1(b);
  end;
  sticky := a.n <> 0;
  Result := RoundToDouble(q, -s, sticky, neg);
end;

{$IFDEF LUA_UCRT}
function HexToDouble(p: PAnsiChar; var endp: PAnsiChar; neg: Boolean): Double;
{ p points after '0x'; returns with endp at the end of the parsed number }
var mant: UInt64; e2, digs, ex, esign: Integer; sticky, any: Boolean; c, dv: Integer; q: PAnsiChar;
begin
  mant := 0; e2 := 0; sticky := False; any := False; digs := 0;
  while c_isxdigit(Ord(p^)) or (p^ = '.') do
  begin
    if p^ = '.' then
    begin
      Break;
    end;
    c := Ord(p^);
    if c_isdigit(c) then dv := c - Ord('0') else dv := c_tolower(c) - Ord('a') + 10;
    any := True;
    if mant shr 60 = 0 then mant := mant * 16 + UInt64(dv)
    else begin Inc(e2, 4); if dv <> 0 then sticky := True; end;
    Inc(p); Inc(digs);
  end;
  if p^ = '.' then
  begin
    Inc(p);
    while c_isxdigit(Ord(p^)) do
    begin
      c := Ord(p^);
      if c_isdigit(c) then dv := c - Ord('0') else dv := c_tolower(c) - Ord('a') + 10;
      any := True;
      if mant shr 60 = 0 then begin mant := mant * 16 + UInt64(dv); Dec(e2, 4); end
      else if dv <> 0 then sticky := True;
      Inc(p);
    end;
  end;
  if not any then begin endp := nil; Exit(0); end;
  if (p^ = 'p') or (p^ = 'P') then
  begin
    q := p + 1; esign := 1;
    if q^ = '+' then Inc(q) else if q^ = '-' then begin esign := -1; Inc(q); end;
    if c_isdigit(Ord(q^)) then
    begin
      ex := 0;
      while c_isdigit(Ord(q^)) do
      begin
        if ex < 100000 then ex := ex * 10 + Ord(q^) - Ord('0');
        Inc(q);
      end;
      e2 := e2 + esign * ex;
      p := q;
    end;
  end;
  endp := p;
  if mant = 0 then Exit(RoundToDouble(0, 0, False, neg));
  if e2 > 5000 then e2 := 5000 else if e2 < -5000 then e2 := -5000;
  Result := RoundToDouble(mant, e2, sticky, neg);
end;

function MatchCI(p: PAnsiChar; const w: AnsiString): Boolean;
var i: Integer;
begin
  for i := 1 to Length(w) do
  begin
    if c_tolower(Ord(p^)) <> Ord(w[i]) then Exit(False);
    Inc(p);
  end;
  Result := True;
end;
{$ENDIF}

function c_strtod(s: PAnsiChar; endptr: PPAnsiChar): Double;
var p, q: PAnsiChar; neg, any, nonzeroTail: Boolean; digits: AnsiString;
    exp10, ex, esign, nd: Integer;
begin
  p := s;
  while c_isspace(Ord(p^)) do Inc(p);
  neg := False;
  if p^ = '-' then begin neg := True; Inc(p); end
  else if p^ = '+' then Inc(p);
{$IFDEF LUA_UCRT}
  if (p^ = '0') and ((p[1] = 'x') or (p[1] = 'X')) then
  begin
    Result := HexToDouble(p + 2, q, neg);
    if q = nil then
    begin
      { just "0" }
      if endptr <> nil then endptr^ := p + 1;
      if neg then Result := -0.0 else Result := 0.0;
      Exit;
    end;
    if endptr <> nil then endptr^ := q;
    Exit;
  end;
  if MatchCI(p, 'inf') then
  begin
    if MatchCI(p, 'infinity') then q := p + 8 else q := p + 3;
    if endptr <> nil then endptr^ := q;
    Result := HUGE_VAL;
    if neg then Result := -Result;
    Exit;
  end;
  if MatchCI(p, 'nan') then
  begin
    q := p + 3;
    if q^ = '(' then
    begin
      p := q + 1;
      while c_isalnum(Ord(p^)) or (p^ = '_') do Inc(p);
      if p^ = ')' then q := p + 1;
    end;
    if endptr <> nil then endptr^ := q;
    Result := BitsDbl(UInt64($7FF8000000000000));
    if neg then Result := BitsDbl(UInt64((UInt64($FFF80000) shl 32 or UInt64($00000000))));
    Exit;
  end;
{$ENDIF}
  digits := '';
  exp10 := 0;
  any := False;
  nonzeroTail := False;
  nd := 0;
  while c_isdigit(Ord(p^)) do
  begin
    any := True;
    if (nd = 0) and (p^ = '0') then
      { skip leading zeros }
    else if nd < MAXSIGDIGITS then
    begin
      digits := digits + p^; Inc(nd);
    end
    else
    begin
      Inc(exp10);
      if p^ <> '0' then nonzeroTail := True;
    end;
    Inc(p);
  end;
  if p^ = '.' then
  begin
    q := p + 1;
    if any or c_isdigit(Ord(q^)) then
    begin
      p := q;
      while c_isdigit(Ord(p^)) do
      begin
        any := True;
        if (nd = 0) and (p^ = '0') then
          Dec(exp10)
        else if nd < MAXSIGDIGITS then
        begin
          digits := digits + p^; Inc(nd); Dec(exp10);
        end
        else if p^ <> '0' then
          nonzeroTail := True;
        Inc(p);
      end;
    end;
  end;
  if not any then
  begin
    if endptr <> nil then endptr^ := s;
    Exit(0.0);
  end;
{$IFDEF LUA_UCRT}
  if (p^ = 'e') or (p^ = 'E') then
{$ELSE}
  if (p^ = 'e') or (p^ = 'E') or (p^ = 'd') or (p^ = 'D') then
{$ENDIF}
  begin
    q := p + 1; esign := 1;
    if q^ = '+' then Inc(q) else if q^ = '-' then begin esign := -1; Inc(q); end;
    if c_isdigit(Ord(q^)) then
    begin
      ex := 0;
      while c_isdigit(Ord(q^)) do
      begin
        if ex < 100000 then ex := ex * 10 + Ord(q^) - Ord('0');
        Inc(q);
      end;
      exp10 := exp10 + esign * ex;
      p := q;
    end;
  end;
  if endptr <> nil then endptr^ := p;
  if nonzeroTail then
  begin
    digits := digits + '1';
    Dec(exp10);
  end;
  Result := DecimalToDouble(digits, exp10, neg);
end;

function c_strtoul(s: PAnsiChar; endptr: PPAnsiChar; base: Integer): c_ulong;
var p: PAnsiChar; neg, overflow, any: Boolean; c, dv: Integer; v: UInt64;
begin
  p := s;
  while c_isspace(Ord(p^)) do Inc(p);
  neg := False;
  if p^ = '-' then begin neg := True; Inc(p); end
  else if p^ = '+' then Inc(p);
  if base = 0 then
  begin
    if p^ <> '0' then base := 10
    else if (p[1] = 'x') or (p[1] = 'X') then base := 16
    else base := 8;
  end;
  if (base = 16) and (p^ = '0') and ((p[1] = 'x') or (p[1] = 'X')) then Inc(p, 2);
  v := 0; overflow := False; any := False;
  while True do
  begin
    c := Ord(p^);
    if c_isdigit(c) then dv := c - Ord('0')
    else if c_isalpha(c) then dv := c_toupper(c) - Ord('A') + 10
    else Break;
    if dv >= base then Break;
    any := True;
    if not overflow then
    begin
      if v > (UInt64(High(c_ulong)) - UInt64(dv)) div UInt64(base) then overflow := True
      else v := v * UInt64(base) + UInt64(dv);
    end;
    Inc(p);
  end;
  if not any then
  begin
    if endptr <> nil then endptr^ := s;
    Exit(0);
  end;
  if endptr <> nil then endptr^ := p;
  if overflow then
  begin
    Exit(High(c_ulong));
  end;
  Result := c_ulong(v);
  if neg then Result := c_ulong(0) - Result;
end;

{ ====================================================================
  printf formatting
  ==================================================================== }

type
  TFmtSpec = record
    minus, plus, space, hash, zero: Boolean;
    width: Integer;
    prec: Integer;          { -1: not specified }
    conv: AnsiChar;
  end;

procedure ParseSpec(form: PAnsiChar; var sp: TFmtSpec);
begin
  FillChar(sp, SizeOf(sp), 0);
  sp.prec := -1;
  if form^ = '%' then Inc(form);
  while True do
  begin
    case form^ of
      '-': sp.minus := True;
      '+': sp.plus := True;
      ' ': sp.space := True;
      '#': sp.hash := True;
      '0': sp.zero := True;
    else
      Break;
    end;
    Inc(form);
  end;
  while c_isdigit(Ord(form^)) do
  begin
    sp.width := sp.width * 10 + Ord(form^) - Ord('0');
    Inc(form);
  end;
  if form^ = '.' then
  begin
    Inc(form);
    sp.prec := 0;
    while c_isdigit(Ord(form^)) do
    begin
      sp.prec := sp.prec * 10 + Ord(form^) - Ord('0');
      Inc(form);
    end;
  end;
  while (form^ = 'l') or (form^ = 'h') or (form^ = 'L') do Inc(form);
  sp.conv := form^;
end;

function Pad(const sp: TFmtSpec; const sign, prefix, body: AnsiString; zeroAllowed: Boolean): AnsiString;
var total: Integer;
begin
  total := Length(sign) + Length(prefix) + Length(body);
  if total >= sp.width then
    Result := sign + prefix + body
  else if sp.minus then
    Result := sign + prefix + body + StringOfChar(AnsiChar(' '), sp.width - total)
  else if sp.zero and zeroAllowed then
    Result := sign + prefix + StringOfChar(AnsiChar('0'), sp.width - total) + body
  else
    Result := StringOfChar(AnsiChar(' '), sp.width - total) + sign + prefix + body;
end;

{ exact decimal digits of |x| (finite, nonzero): value = 0.D * 10^decpt }
procedure ExactDigits(x: Double; out D: AnsiString; out decpt: Integer);
var bits, m, v: UInt64; e, e2, i: Integer; a: TBig; s: AnsiString;
begin
  bits := DblBits(x) and UInt64($7FFFFFFFFFFFFFFF);
  e := Integer(bits shr 52);
  m := bits and UInt64($000FFFFFFFFFFFFF);
  if e = 0 then e2 := -1074
  else
  begin
    m := m or (UInt64(1) shl 52);
    e2 := e - 1075;
  end;
  { strip trailing zero bits }
  while (m and 1) = 0 do begin m := m shr 1; Inc(e2); end;
  if (e2 >= 0) and (e2 <= 10) and (m < (UInt64(1) shl 53)) then
  begin
    v := m shl e2;
    s := '';
    while v <> 0 do
    begin
      s := AnsiChar(Ord('0') + Integer(v mod 10)) + s;
      v := v div 10;
    end;
    D := s;
    decpt := Length(s);
  end
  else
  begin
    BigSetU64(a, m);
    if e2 >= 0 then
    begin
      BigShl(a, e2);
      D := BigToDec(a);
      decpt := Length(D);
    end
    else
    begin
      BigMulPow5(a, -e2);
      D := BigToDec(a);
      decpt := Length(D) + e2;
    end;
  end;
  { strip trailing zeros }
  i := Length(D);
  while (i > 1) and (D[i] = '0') do Dec(i);
  SetLength(D, i);
end;

function DigitAt(const D: AnsiString; i: Integer): AnsiChar; inline;
begin
  if (i >= 1) and (i <= Length(D)) then Result := D[i] else Result := '0';
end;

{ Round the digit string D (value 0.D*10^decpt) keeping 'keep' digits.
  keep may be <= 0.  Result digits may be shorter than keep (implicit zeros). }
procedure RoundDigits(var D: AnsiString; var decpt: Integer; keep: Integer; halfEven: Boolean);
var up: Boolean; i: Integer; c: AnsiChar;
begin
  if keep >= Length(D) then Exit;
  if keep < 0 then
  begin
    D := ''; Exit;
  end;
  c := DigitAt(D, keep + 1);
  if halfEven then
  begin
    if c > '5' then up := True
    else if c < '5' then up := False
    else
    begin
      up := False;
      for i := keep + 2 to Length(D) do
        if D[i] <> '0' then begin up := True; Break; end;
      if not up then
      begin
        { exact tie: round to even }
        if keep = 0 then up := False
        else up := ((Ord(D[keep]) - Ord('0')) and 1) = 1;
      end;
    end;
  end
  else
    up := c >= '5';
  SetLength(D, keep);
  if up then
  begin
    i := keep;
    while True do
    begin
      if i = 0 then
      begin
        D := '1' + D;
        Inc(decpt);
        SetLength(D, keep);         { keep the same number of digits }
        if keep = 0 then D := '1';  { rounding 0.5.. up to 1 unit }
        Break;
      end;
      if D[i] = '9' then
      begin
        D[i] := '0';
        Dec(i);
      end
      else
      begin
        D[i] := AnsiChar(Ord(D[i]) + 1);
        Break;
      end;
    end;
  end;
end;

function ExpStr(e: Integer; upper: Boolean): AnsiString;
var s: AnsiString; minDigits: Integer;
begin
{$IFDEF LUA_UCRT}
  minDigits := 2;
{$ELSE}
  minDigits := 3;
{$ENDIF}
  s := '';
  if e < 0 then e := -e;
  repeat
    s := AnsiChar(Ord('0') + e mod 10) + s;
    e := e div 10;
  until e = 0;
  while Length(s) < minDigits do s := '0' + s;
  if upper then Result := 'E' else Result := 'e';
  Result := Result + s;
end;

function FormatFixed(const D: AnsiString; decpt, prec: Integer; hash: Boolean): AnsiString;
{ D already rounded so that it has no digits beyond position decpt+prec }
var i: Integer; ip, fp: AnsiString;
begin
  if decpt <= 0 then ip := '0'
  else
  begin
    SetLength(ip, decpt);
    for i := 1 to decpt do ip[i] := DigitAt(D, i);
  end;
  SetLength(fp, prec);
  for i := 1 to prec do fp[i] := DigitAt(D, decpt + i);
  Result := ip;
  if (prec > 0) or hash then Result := Result + '.';
  Result := Result + fp;
end;

function FormatExp(const D: AnsiString; decpt, prec: Integer; hash, upper: Boolean): AnsiString;
var i, ex: Integer; fp, es: AnsiString;
begin
  Result := DigitAt(D, 1);
  SetLength(fp, prec);
  for i := 1 to prec do fp[i] := DigitAt(D, 1 + i);
  if (prec > 0) or hash then Result := Result + '.';
  Result := Result + fp;
  if (Length(D) = 0) or (D = '0') then ex := 0 else ex := decpt - 1;
  es := ExpStr(ex, upper);
  if ex < 0 then Result := Result + es[1] + '-' + Copy(es, 2, 10)
  else Result := Result + es[1] + '+' + Copy(es, 2, 10);
end;

function StripZeros(const s: AnsiString): AnsiString;
var i, epos: Integer; mant, ex: AnsiString;
begin
  epos := 0;
  for i := 1 to Length(s) do
    if (s[i] = 'e') or (s[i] = 'E') then begin epos := i; Break; end;
  if epos > 0 then
  begin
    mant := Copy(s, 1, epos - 1); ex := Copy(s, epos, MaxInt);
  end
  else
  begin
    mant := s; ex := '';
  end;
  if Pos(AnsiString('.'), mant) > 0 then
  begin
    i := Length(mant);
    while (i > 0) and (mant[i] = '0') do Dec(i);
    if (i > 0) and (mant[i] = '.') then Dec(i);
    SetLength(mant, i);
  end;
  Result := mant + ex;
end;

function FormatDoubleSpec(const sp: TFmtSpec; x: Double): AnsiString;
var bits: UInt64; neg, upper, special: Boolean; D: AnsiString; decpt, prec, P, X10: Integer;
    sign, body: AnsiString; conv: AnsiChar;
begin
  bits := DblBits(x);
  neg := (bits shr 63) <> 0;
  conv := sp.conv;
  upper := (conv = 'E') or (conv = 'G');
  prec := sp.prec;
  if prec < 0 then prec := 6;
  if neg then sign := '-'
  else if sp.plus then sign := '+'
  else if sp.space then sign := ' '
  else sign := '';
  special := IsInfOrNaN(x);
{$IFDEF LUA_UCRT}
  if special then
  begin
    if (bits and UInt64($000FFFFFFFFFFFFF)) = 0 then body := 'inf'
{$IFDEF LUA_POSIX}
    else body := 'nan';   { glibc: "nan" / "-nan" by sign, no payload text }
  {$IFDEF DARWIN}
    if body = 'nan' then sign := '';   { macOS printf never shows a NaN's sign }
  {$ENDIF}
{$ELSE}
    else if bits = UInt64((UInt64($FFF80000) shl 32 or UInt64($00000000))) then body := 'nan(ind)'
    else if (bits and UInt64($0008000000000000)) = 0 then body := 'nan(snan)'
    else body := 'nan';
{$ENDIF}
    if upper then body := AnsiString(UpCase(string(body)));
    Exit(Pad(sp, sign, '', body, False));
  end;
{$ENDIF}
  if special then
  begin
    if (bits and UInt64($000FFFFFFFFFFFFF)) = 0 then D := '1#INF'
    else if bits = UInt64((UInt64($FFF80000) shl 32 or UInt64($00000000))) then D := '1#IND'
    else if (bits and UInt64($0008000000000000)) = 0 then D := '1#SNAN'
    else D := '1#QNAN';
    decpt := 1;
  end
  else if (bits and UInt64($7FFFFFFFFFFFFFFF)) = 0 then
  begin
    D := '';
    decpt := 1;
  end
  else
  begin
    ExactDigits(x, D, decpt);
{$IFNDEF LUA_UCRT}
    { classic msvcrt only produces 17 significant digits }
    RoundDigits(D, decpt, 17, False);
{$ENDIF}
  end;
  case conv of
    'f', 'F':
      begin
        RoundDigits(D, decpt, decpt + prec, {$IFDEF LUA_UCRT}True{$ELSE}False{$ENDIF});
        body := FormatFixed(D, decpt, prec, sp.hash);
      end;
    'e', 'E':
      begin
        if D = '' then decpt := 1;
        RoundDigits(D, decpt, prec + 1, {$IFDEF LUA_UCRT}True{$ELSE}False{$ENDIF});
        body := FormatExp(D, decpt, prec, sp.hash, upper);
      end;
  else { g, G }
    begin
      P := prec;
      if P = 0 then P := 1;
      if D = '' then decpt := 1;
      RoundDigits(D, decpt, P, {$IFDEF LUA_UCRT}True{$ELSE}False{$ENDIF});
      if D = '' then decpt := 1;
      X10 := decpt - 1;
      if (P > X10) and (X10 >= -4) then
        body := FormatFixed(D, decpt, P - 1 - X10, sp.hash)
      else
        body := FormatExp(D, decpt, P - 1, sp.hash, upper);
      if not sp.hash then body := StripZeros(body);
    end;
  end;
  Result := Pad(sp, sign, '', body, True);
end;

function c_fmt_double(form: PAnsiChar; x: Double): AnsiString;
var sp: TFmtSpec;
begin
  ParseSpec(form, sp);
  Result := FormatDoubleSpec(sp, x);
end;

function c_fmt_long(form: PAnsiChar; v: c_long): AnsiString;
var sp: TFmtSpec; u: c_ulong; digits, sign, prefix: AnsiString; base: c_ulong;
    upper: Boolean; dg: Integer;
begin
  ParseSpec(form, sp);
  if sp.conv = 'c' then
  begin
    sp.zero := False;
    Exit(Pad(sp, '', '', AnsiChar(Byte(v)), False));
  end;
  sign := ''; prefix := '';
  upper := False;
  case sp.conv of
    'd', 'i':
      begin
        base := 10;
        if v < 0 then
        begin
          sign := '-';
          u := c_ulong(0) - c_ulong(v);
        end
        else
        begin
          u := c_ulong(v);
          if sp.plus then sign := '+' else if sp.space then sign := ' ';
        end;
      end;
    'o': begin base := 8; u := c_ulong(v); end;
    'x': begin base := 16; u := c_ulong(v); end;
    'X': begin base := 16; u := c_ulong(v); upper := True; end;
  else { 'u' }
    begin base := 10; u := c_ulong(v); end;
  end;
  digits := '';
  while u <> 0 do
  begin
    dg := Integer(u mod base);
    if dg < 10 then digits := AnsiChar(Ord('0') + dg) + digits
    else if upper then digits := AnsiChar(Ord('A') + dg - 10) + digits
    else digits := AnsiChar(Ord('a') + dg - 10) + digits;
    u := u div base;
  end;
  if sp.prec < 0 then
  begin
    if digits = '' then digits := '0';
  end
  else
    while Length(digits) < sp.prec do digits := '0' + digits;
  if sp.hash then
  begin
    if (sp.conv = 'o') and ((digits = '') or (digits[1] <> '0')) then digits := '0' + digits
    else if (sp.conv = 'x') and (v <> 0) then prefix := '0x'
    else if (sp.conv = 'X') and (v <> 0) then prefix := '0X';
  end;
  Result := Pad(sp, sign, prefix, digits, sp.prec < 0);
end;

function c_fmt_str(form: PAnsiChar; s: PAnsiChar): AnsiString;
var sp: TFmtSpec; n: size_t; body: AnsiString;
begin
  ParseSpec(form, sp);
  if s = nil then s := '(null)';
  n := c_strlen(s);
  if (sp.prec >= 0) and (size_t(sp.prec) < n) then n := sp.prec;
  SetString(body, s, n);
  sp.zero := False;
  Result := Pad(sp, '', '', body, False);
end;

procedure lua_number2str(buf: PAnsiChar; n: lua_Number);
var s: AnsiString; sp: TFmtSpec; v: Int64; neg: Boolean; tmp: array[0..24] of AnsiChar; i, j: Integer;
begin
  { fast path: integral values with at most 14 digits print as plain integers }
  if (not luai_numisnan(n)) and (n = Int(n)) and (Abs(n) < 1e14) and not ((n = 0) and ((DblBits(n) shr 63) <> 0)) then
  begin
    v := Trunc(n);
    neg := v < 0;
    if neg then v := -v;
    i := 0;
    repeat
      tmp[i] := AnsiChar(Ord('0') + Integer(v mod 10));
      v := v div 10;
      Inc(i);
    until v = 0;
    j := 0;
    if neg then begin buf[0] := '-'; j := 1; end;
    while i > 0 do
    begin
      Dec(i);
      buf[j] := tmp[i];
      Inc(j);
    end;
    buf[j] := #0;
    Exit;
  end;
  FillChar(sp, SizeOf(sp), 0);
  sp.prec := 14;
  sp.conv := 'g';
  s := FormatDoubleSpec(sp, n);
  if Length(s) > LUAI_MAXNUMBER2STR - 1 then SetLength(s, LUAI_MAXNUMBER2STR - 1);
  if Length(s) > 0 then Move(s[1], buf^, Length(s));
  buf[Length(s)] := #0;
end;

function c_itoa(v: Int64): AnsiString;
var u: UInt64; neg: Boolean; buf: array[0..23] of AnsiChar; i: Integer;
begin
  neg := v < 0;
  if neg then u := UInt64(-(v + 1)) + 1 else u := UInt64(v);
  i := High(buf);
  repeat
    buf[i] := AnsiChar(Ord('0') + Integer(u mod 10));
    u := u div 10;
    Dec(i);
  until u = 0;
  if neg then begin buf[i] := '-'; Dec(i); end;
  SetString(Result, PAnsiChar(@buf[i + 1]), High(buf) - i);
end;

{$IFDEF LUA_POSIX}
{ glibc %p: "0x" + lowercase hex without padding, "(nil)" for NULL }
function c_fmt_pointer(p: Pointer): AnsiString;
const HexDigits: array[0..15] of AnsiChar = '0123456789abcdef';
var v: NativeUInt;
begin
  if p = nil then Exit({$IFDEF DARWIN}'0x0'{$ELSE}'(nil)'{$ENDIF});
  v := NativeUInt(p);
  Result := '';
  while v <> 0 do
  begin
    Result := HexDigits[v and 15] + Result;
    v := v shr 4;
  end;
  Result := '0x' + Result;
end;
{$ELSE}
function c_fmt_pointer(p: Pointer): AnsiString;
const HexDigits: array[0..15] of AnsiChar = '0123456789ABCDEF';
var v: NativeUInt; i: Integer;
begin
  v := NativeUInt(p);
  SetLength(Result, SizeOf(Pointer) * 2);
  for i := Length(Result) downto 1 do
  begin
    Result[i] := HexDigits[v and 15];
    v := v shr 4;
  end;
end;
{$ENDIF}

{ ====================================================================
  Comparisons
  ==================================================================== }

function luai_numisnan(a: Double): Boolean;
begin
  Result := (PInt64(@a)^ and $7FFFFFFFFFFFFFFF) > $7FF0000000000000;
end;

function luai_numunm(a: Double): Double;
begin
  { Delphi Win64 compiles -a as a multiplication by -1, which leaves a NaN's
    sign unchanged; C compilers flip the sign bit (so -(0/0) prints 1.#QNAN) }
  PInt64(@Result)^ := PInt64(@a)^ xor (-9223372036854775807 - 1);
end;

function luai_numeq(a, b: Double): Boolean;
begin
  Result := (a = b) and not (luai_numisnan(a) or luai_numisnan(b));
end;

function luai_numlt(a, b: Double): Boolean;
begin
  Result := (a < b) and not (luai_numisnan(a) or luai_numisnan(b));
end;

function luai_numle(a, b: Double): Boolean;
begin
  Result := (a <= b) and not (luai_numisnan(a) or luai_numisnan(b));
end;

{ ====================================================================
  Conversions double -> integer
  ==================================================================== }

{$IFDEF CPUAARCH64}
{ AArch64 conversions (fcvtzs / fcvtzu): truncate, saturate out-of-range
  values, NaN -> 0 - what C casts compile to on ARM64 }
function sat_i32(d: Double): Integer;
begin
  if luai_numisnan(d) then Exit(0);
  if d >= 2147483647.0 then Exit(2147483647);
  if d <= -2147483648.0 then Exit(-2147483647 - 1);
  Result := Trunc(d);
end;

function sat_i64(d: Double): Int64;
begin
  if luai_numisnan(d) then Exit(0);
  if d >= 9223372036854775807.0 then Exit(9223372036854775807);
  if d <= -9223372036854775808.0 then Exit(-9223372036854775807 - 1);
  Result := Trunc(d);
end;

function sat_u64(d: Double): QWord;
begin
  if luai_numisnan(d) or (d <= 0) then Exit(0);
  if d >= 18446744073709551615.0 then Exit(High(QWord));
  if d >= 9223372036854775808.0 then
    Result := QWord(Trunc(d - 9223372036854775808.0)) + (QWord(1) shl 63)
  else
    Result := QWord(Trunc(d));
end;
{$ENDIF}

function lua_number2int(d: lua_Number): Integer;
begin
{$IFDEF CPUAARCH64}
  Exit(sat_i32(d));
{$ENDIF}
  if luai_numisnan(d) then Exit(Integer($80000000));
{$IFDEF LUA_X86}
  { MSVC x86 build: __asm fld d; __asm fistp i  (round to nearest even) }
  if (d > -2147483648.5) and (d < 2147483647.5) then
    Result := Round(d)
  else
    Result := Integer($80000000);
{$ELSE}
  { (int)d : truncation, out of range -> 0x80000000 }
  if (d > -2147483649.0) and (d < 2147483648.0) then
    Result := Trunc(d)
  else
    Result := Integer($80000000);
{$ENDIF}
end;

function lua_number2integer(d: lua_Number): lua_Integer;
begin
{$IFDEF CPUAARCH64}
  Exit(sat_i64(d));
{$ENDIF}
{$IFDEF LUA_64}
  if luai_numisnan(d) then Exit(-9223372036854775807 - 1);
  if (d > -9223372036854775808.0) and (d < 9223372036854775808.0) then
    Result := Trunc(d)
  else
    Result := -9223372036854775807 - 1;
{$ELSE}
  Result := lua_number2int(d);
{$ENDIF}
end;

{$IFDEF LUA_POSIX}
{ x86-64: cvttsd2si with a 64-bit destination; NaN/out of range -> LONG_MIN }
function c_double2long(d: Double): c_long;
begin
{$IFDEF CPUAARCH64}
  Exit(sat_i64(d));
{$ENDIF}
  if luai_numisnan(d) or not ((d >= -9223372036854775808.0) and (d < 9223372036854775808.0)) then
    Result := -9223372036854775807 - 1
  else
    Result := Trunc(d);
end;

{ (unsigned long)d as compiled by gcc for x86-64:
    d < 2^63 ? (long)d : ((long)(d - 2^63)) ^ 0x8000000000000000   (NaN takes the first path) }
function c_double2ulong(d: Double): c_ulong;
const TWO63 = 9223372036854775808.0;
begin
{$IFDEF CPUAARCH64}
  Exit(sat_u64(d));
{$ENDIF}
{$IFDEF DARWIN}
  { clang, x86-64: r := (long)d; result := r or ((long)(d - 2^63) and (r shr 63 sign-filled)) }
  Result := c_ulong(c_double2long(d));
  if Int64(Result) < 0 then
    Result := Result or c_ulong(c_double2long(d - TWO63));
  Exit;
{$ENDIF}
  if luai_numisnan(d) or not (d >= TWO63) then
    Result := c_ulong(c_double2long(d))
  else
    Result := c_ulong(c_double2long(d - TWO63)) xor (c_ulong(1) shl 63);
end;
{$ELSE}
function c_double2long(d: Double): Integer;
begin
  if luai_numisnan(d) then Exit(Integer($80000000));
  if (d > -2147483649.0) and (d < 2147483648.0) then
    Result := Trunc(d)
  else
    Result := Integer($80000000);
end;

{ (unsigned long)d as done by MSVC: through a 64-bit integer }
function c_double2ulong(d: Double): c_ulong;
begin
  if luai_numisnan(d) or not ((d > -9223372036854775808.0) and (d < 9223372036854775808.0)) then
    Result := 0
  else
    Result := Cardinal(Trunc(d) and $FFFFFFFF);
end;
{$ENDIF}

function c_double2int_trunc(d: Double): Integer;
begin
{$IFDEF CPUAARCH64}
  Exit(sat_i32(d));
{$ENDIF}
  if luai_numisnan(d) or not ((d > -2147483649.0) and (d < 2147483648.0)) then
    Result := Integer($80000000)
  else
    Result := Trunc(d);
end;

{ ====================================================================
  math
  ==================================================================== }

function c_floor(x: Double): Double;
begin
{$IFDEF LUA_POSIX}
  Exit(px_floor(x));  { libm, like the C build }
{$ENDIF}
  if IsInfOrNaN(x) or (c_fabs(x) >= 4503599627370496.0) then Exit(x);
  Result := Int(x);
  if Result > x then Result := Result - 1.0;
  if (Result = 0) and ((DblBits(x) shr 63) <> 0) then Result := BitsDbl(UInt64((UInt64($80000000) shl 32 or UInt64($00000000))));
end;

function c_ceil(x: Double): Double;
begin
{$IFDEF LUA_POSIX}
  Exit(px_ceil(x));  { libm, like the C build }
{$ENDIF}
  if IsInfOrNaN(x) or (c_fabs(x) >= 4503599627370496.0) then Exit(x);
  Result := Int(x);
  if Result < x then Result := Result + 1.0;
  if (Result = 0) and ((DblBits(x) shr 63) <> 0) then Result := BitsDbl(UInt64((UInt64($80000000) shl 32 or UInt64($00000000))));
end;

function c_fmod(x, y: Double): Double;
{ exact algorithm (musl) }
var uxi, uyi, i: UInt64; ex, ey: Integer; sx: UInt64;
begin
{$IFDEF LUA_POSIX}
  Exit(px_fmod(x, y));  { libm, like the C build }
{$ENDIF}
  uxi := DblBits(x); uyi := DblBits(y);
  ex := Integer((uxi shr 52) and $7FF);
  ey := Integer((uyi shr 52) and $7FF);
  sx := uxi shr 63;
  if ((uyi shl 1) = 0) or c_isnan(y) or (ex = $7FF) then
    Exit((x * y) / (x * y));
  if (uxi shl 1) <= (uyi shl 1) then
  begin
    if (uxi shl 1) = (uyi shl 1) then Exit(0 * x);
    Exit(x);
  end;
  if ex = 0 then
  begin
    i := uxi shl 12;
    while (i shr 63) = 0 do begin Dec(ex); i := i shl 1; end;
    uxi := uxi shl (-ex + 1);
  end
  else
  begin
    uxi := uxi and (UInt64($000FFFFFFFFFFFFF));
    uxi := uxi or (UInt64(1) shl 52);
  end;
  if ey = 0 then
  begin
    i := uyi shl 12;
    while (i shr 63) = 0 do begin Dec(ey); i := i shl 1; end;
    uyi := uyi shl (-ey + 1);
  end
  else
  begin
    uyi := uyi and (UInt64($000FFFFFFFFFFFFF));
    uyi := uyi or (UInt64(1) shl 52);
  end;
  while ex > ey do
  begin
    i := uxi - uyi;
    if (i shr 63) = 0 then
    begin
      if i = 0 then Exit(0 * x);
      uxi := i;
    end;
    uxi := uxi shl 1;
    Dec(ex);
  end;
  i := uxi - uyi;
  if (i shr 63) = 0 then
  begin
    if i = 0 then Exit(0 * x);
    uxi := i;
  end;
  while (uxi shr 52) = 0 do begin uxi := uxi shl 1; Dec(ex); end;
  if ex > 0 then
  begin
    uxi := uxi - (UInt64(1) shl 52);
    uxi := uxi or (UInt64(ex) shl 52);
  end
  else
    uxi := uxi shr (-ex + 1);
  uxi := uxi or (sx shl 63);
  Result := BitsDbl(uxi);
end;

function c_frexp(x: Double; var e: Integer): Double;
var bits: UInt64; ee: Integer;
begin
{$IFDEF LUA_POSIX}
  Exit(px_frexp(x, @e));  { libm, like the C build }
{$ENDIF}
  bits := DblBits(x);
  ee := Integer((bits shr 52) and $7FF);
  if ee = 0 then
  begin
    if (bits shl 1) = 0 then begin e := 0; Exit(x); end;
    { subnormal: scale up }
    Result := c_frexp(x * 18446744073709551616.0, e);   { 2^64 }
    Dec(e, 64);
    Exit;
  end;
  if ee = $7FF then begin e := 0; Exit(x); end;
  e := ee - 1022;
  bits := (bits and UInt64((UInt64($800FFFFF) shl 32 or UInt64($FFFFFFFF)))) or (UInt64(1022) shl 52);
  Result := BitsDbl(bits);
end;

function c_ldexp(x: Double; e: Integer): Double;
var y: Double;
begin
{$IFDEF LUA_POSIX}
  Exit(px_ldexp(x, e));  { libm, like the C build }
{$ENDIF}
  { scalbn (musl) }
  y := x;
  if e > 1023 then
  begin
    y := y * 8.98846567431157953865e307;   { 2^1023 }
    Dec(e, 1023);
    if e > 1023 then
    begin
      y := y * 8.98846567431157953865e307;
      Dec(e, 1023);
      if e > 1023 then e := 1023;
    end;
  end
  else if e < -1022 then
  begin
    { make sure final result is rounded only once: 2^-1022 * 2^53 }
    y := y * (2.2250738585072014e-308 * 9007199254740992.0);
    Inc(e, 1022 - 53);
    if e < -1022 then
    begin
      y := y * (2.2250738585072014e-308 * 9007199254740992.0);
      Inc(e, 1022 - 53);
      if e < -1022 then e := -1022;
    end;
  end;
  Result := y * BitsDbl(UInt64($3FF + e) shl 52);
end;

function c_modf(x: Double; var ip: Double): Double;
begin
{$IFDEF LUA_POSIX}
  Exit(px_modf(x, @ip));  { libm, like the C build }
{$ENDIF}
  if IsInfOrNaN(x) then
  begin
    ip := x;
    if c_isnan(x) then Exit(x);
    { +-inf: fractional part is +-0 }
    Exit(BitsDbl(DblBits(x) and UInt64((UInt64($80000000) shl 32 or UInt64($00000000)))));
  end;
  ip := Int(x);
  if (ip = 0) and ((DblBits(x) shr 63) <> 0) then ip := BitsDbl(UInt64((UInt64($80000000) shl 32 or UInt64($00000000))));
  Result := x - ip;
  { sign of zero fractional part follows x }
  if Result = 0 then Result := BitsDbl(DblBits(x) and UInt64((UInt64($80000000) shl 32 or UInt64($00000000))));
end;

function c_sqrt(x: Double): Double;
begin
{$IFDEF LUA_POSIX}
  Exit(px_sqrt(x));  { libm, like the C build }
{$ENDIF}
  Result := Sqrt(x);
end;

function c_exp(x: Double): Double;
begin
{$IFDEF LUA_POSIX}
  Exit(px_exp(x));  { libm, like the C build }
{$ENDIF}
  if c_isnan(x) then Exit(x);
  if x > 709.782712893384 then Exit(HUGE_VAL);
  if x < -745.1332191019412 then Exit(0.0);
  Result := Exp(x);
end;

function c_log(x: Double): Double;
begin
{$IFDEF LUA_POSIX}
  Exit(px_log(x));  { libm, like the C build }
{$ENDIF}
  if c_isnan(x) then Exit(x);
  if x < 0 then Exit(BitsDbl(UInt64((UInt64($FFF80000) shl 32 or UInt64($00000000)))));
  if x = 0 then Exit(-HUGE_VAL);
  if IsInfOrNaN(x) then Exit(x);
  Result := Ln(x);
end;

function c_log10(x: Double): Double;
var r: Double; n: Integer;
begin
{$IFDEF LUA_POSIX}
  Exit(px_log10(x));  { libm, like the C build }
{$ENDIF}
  if c_isnan(x) then Exit(x);
  if x < 0 then Exit(BitsDbl(UInt64($FFF80000) shl 32));
  if x = 0 then Exit(-HUGE_VAL);
  if IsInfOrNaN(x) then Exit(x);
  r := Ln(x) * 0.43429448190325182765;
  { exact results for exact powers of ten }
  if Abs(r - Round(r)) < 1e-9 then
  begin
    n := Round(r);
    if (n > -300) and (n < 300) and (x = c_pow(10, n)) then r := n;
  end;
  Result := r;
end;

function c_atan2(y, x: Double): Double;
begin
{$IFDEF LUA_POSIX}
  Exit(px_atan2(y, x));  { libm, like the C build }
{$ENDIF}
  if c_isnan(x) or c_isnan(y) then Exit(x + y);
  if x = 0 then
  begin
    if y > 0 then Exit(Pi / 2);
    if y < 0 then Exit(-Pi / 2);
    { y = +-0 }
    if (DblBits(x) shr 63) <> 0 then
    begin
      if (DblBits(y) shr 63) <> 0 then Exit(-Pi) else Exit(Pi);
    end;
    Exit(y);
  end;
  if IsInfOrNaN(x) or IsInfOrNaN(y) then
  begin
    if IsInfOrNaN(x) and IsInfOrNaN(y) then
    begin
      if x > 0 then Result := Pi / 4 else Result := 3 * Pi / 4;
      if y < 0 then Result := -Result;
      Exit;
    end;
    if IsInfOrNaN(y) then
    begin
      if y > 0 then Exit(Pi / 2) else Exit(-Pi / 2);
    end;
    { x infinite, y finite }
    if x > 0 then
      Exit(BitsDbl(DblBits(y) and UInt64((UInt64($80000000) shl 32 or UInt64($00000000)))))
    else if (DblBits(y) shr 63) <> 0 then Exit(-Pi) else Exit(Pi);
  end;
  Result := ArcTan(y / x);
  if x < 0 then
  begin
    if (DblBits(y) shr 63) <> 0 then Result := Result - Pi else Result := Result + Pi;
  end;
end;

function c_asin(x: Double): Double;
begin
{$IFDEF LUA_POSIX}
  Exit(px_asin(x));  { libm, like the C build }
{$ENDIF}
  if c_isnan(x) or (x > 1) or (x < -1) then Exit(BitsDbl(UInt64((UInt64($FFF80000) shl 32 or UInt64($00000000)))));
  if x = 1 then Exit(Pi / 2);
  if x = -1 then Exit(-Pi / 2);
  Result := ArcTan(x / Sqrt((1 - x) * (1 + x)));
end;

function c_acos(x: Double): Double;
begin
{$IFDEF LUA_POSIX}
  Exit(px_acos(x));  { libm, like the C build }
{$ENDIF}
  if c_isnan(x) or (x > 1) or (x < -1) then Exit(BitsDbl(UInt64((UInt64($FFF80000) shl 32 or UInt64($00000000)))));
  if x = 1 then Exit(0);
  if x = -1 then Exit(Pi);
  Result := 2 * ArcTan(Sqrt((1 - x) / (1 + x)));
end;

function c_tan(x: Double): Double;
begin
{$IFDEF LUA_POSIX}
  Exit(px_tan(x));  { libm, like the C build }
{$ENDIF}
  if IsInfOrNaN(x) then Exit(BitsDbl(UInt64((UInt64($FFF80000) shl 32 or UInt64($00000000)))));
  Result := Sin(x) / Cos(x);
end;

function SinhSeries(x: Double): Double;
{ sinh for |x| < 1 using its Taylor series (no cancellation) }
var x2, term, sum: Double; k: Integer;
begin
  x2 := x * x;
  term := x;
  sum := x;
  k := 1;
  while k < 40 do
  begin
    term := term * x2 / ((k + 1) * (k + 2));
    sum := sum + term;
    Inc(k, 2);
    if Abs(term) < 1e-18 * Abs(sum) then Break;
  end;
  Result := sum;
end;

function c_sinh(x: Double): Double;
var t: Double;
begin
{$IFDEF LUA_POSIX}
  Exit(px_sinh(x));  { libm, like the C build }
{$ENDIF}
  if c_isnan(x) or IsInfOrNaN(x) then Exit(x);
  if Abs(x) < 1 then Exit(SinhSeries(x));
  if Abs(x) > 710.4758600739439 then
  begin
    if x > 0 then Exit(HUGE_VAL) else Exit(-HUGE_VAL);
  end;
  if Abs(x) > 709 then
  begin
    t := Exp(Abs(x) / 2);
    Result := (0.5 * t) * t;
  end
  else
  begin
    t := Exp(Abs(x));
    Result := (t - 1 / t) / 2;
  end;
  if x < 0 then Result := -Result;
end;

function c_cosh(x: Double): Double;
var t: Double;
begin
{$IFDEF LUA_POSIX}
  Exit(px_cosh(x));  { libm, like the C build }
{$ENDIF}
  if c_isnan(x) then Exit(x);
  if IsInfOrNaN(x) then Exit(HUGE_VAL);
  x := Abs(x);
  if x > 710.4758600739439 then Exit(HUGE_VAL);
  if x > 709 then
  begin
    t := Exp(x / 2);
    Exit((0.5 * t) * t);
  end;
  t := Exp(x);
  Result := (t + 1 / t) / 2;
end;

function c_tanh(x: Double): Double;
var t, s: Double;
begin
{$IFDEF LUA_POSIX}
  Exit(px_tanh(x));  { libm, like the C build }
{$ENDIF}
  if c_isnan(x) then Exit(x);
  if x > 22 then Exit(1.0);
  if x < -22 then Exit(-1.0);
  if Abs(x) < 1 then
  begin
    s := SinhSeries(x);
    Exit(s / Sqrt(1 + s * s));
  end;
  t := Exp(2 * Abs(x));
  Result := 1 - 2 / (t + 1);
  if x < 0 then Result := -Result;
end;

{ ---- pow: port of fdlibm e_pow.c ----
  Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
  Developed at SunSoft, a Sun Microsystems, Inc. business.
  Permission to use, copy, modify, and distribute this
  software is freely granted, provided that this notice
  is preserved. }
function c_pow(x, y: Double): Double;
const
  bp: array[0..1] of Double = (1.0, 1.5);
  dp_h: array[0..1] of Double = (0.0, 5.84962487220764160156e-01);
  dp_l: array[0..1] of Double = (0.0, 1.35003920212974897128e-08);
  zero = 0.0; half = 0.5; qrtr = 0.25; thrd = 3.3333333333333331e-01;
  one = 1.0; two = 2.0; two53 = 9007199254740992.0;
  huge: Double = 1.0e300; tiny: Double = 1.0e-300;  { typed: must not be constant-folded (Delphi E2098) }
  L1 = 5.99999999999994648725e-01; L2 = 4.28571428578550184252e-01;
  L3 = 3.33333329818377432918e-01; L4 = 2.72728123808534006489e-01;
  L5 = 2.30660745775561754067e-01; L6 = 2.06975017800338417784e-01;
  P1 = 1.66666666666666019037e-01; P2 = -2.77777777770155933842e-03;
  P3 = 6.61375632143793436117e-05; P4 = -1.65339022054652515390e-06;
  P5 = 4.13813679705723846039e-08;
  lg2 = 6.93147180559945286227e-01; lg2_h = 6.93147182464599609375e-01;
  lg2_l = -1.90465429995776804525e-09; ovt = 8.0085662595372944372e-0017;
  cp = 9.61796693925975554329e-01; cp_h = 9.61796700954437255859e-01;
  cp_l = -7.02846165095275826516e-09;
  ivln2 = 1.44269504088896338700e+00; ivln2_h = 1.44269502162933349609e+00;
  ivln2_l = 1.92596299112661746887e-08;
var
  z, ax, z_h, z_l, p_h, p_l, y1, t1, t2, r, s, t, u, v, w: Double;
  ss, s2, s_h, s_l, t_h, t_l: Double;
  i, j, k, yisint, n: Integer;
  hx, hy, ix, iy: Integer;
  lx, ly: Cardinal;
begin
{$IFDEF LUA_POSIX}
  Exit(px_pow(x, y));  { libm, like the C build }
{$ENDIF}
  hx := HiW(x); lx := LoW(x);
  hy := HiW(y); ly := LoW(y);
  ix := hx and $7fffffff; iy := hy and $7fffffff;

  if (Cardinal(iy) or ly) = 0 then Exit(one);
  if (hx = $3ff00000) and (lx = 0) then Exit(one);
  if (ix > $7ff00000) or ((ix = $7ff00000) and (lx <> 0)) or
     (iy > $7ff00000) or ((iy = $7ff00000) and (ly <> 0)) then
    Exit(x + y);

  yisint := 0;
  if hx < 0 then
  begin
    if iy >= $43400000 then yisint := 2
    else if iy >= $3ff00000 then
    begin
      k := (iy shr 20) - $3ff;
      if k > 20 then
      begin
        j := Integer(ly shr (52 - k));
        if (Cardinal(j) shl (52 - k)) = ly then yisint := 2 - (j and 1);
      end
      else if ly = 0 then
      begin
        j := iy shr (20 - k);
        if (j shl (20 - k)) = iy then yisint := 2 - (j and 1);
      end;
    end;
  end;

  if ly = 0 then
  begin
    if iy = $7ff00000 then
    begin
      if ((ix - $3ff00000) or Integer(lx)) = 0 then Exit(one)
      else if ix >= $3ff00000 then
      begin
        if hy >= 0 then Exit(y) else Exit(zero);
      end
      else
      begin
        if hy < 0 then Exit(-y) else Exit(zero);
      end;
    end;
    if iy = $3ff00000 then
    begin
      if hy < 0 then Exit(one / x) else Exit(x);
    end;
    if hy = $40000000 then Exit(x * x);
    if hy = $3fe00000 then
      if hx >= 0 then Exit(Sqrt(x));
  end;

  ax := c_fabs(x);
  if lx = 0 then
  begin
    if (ix = $7ff00000) or (ix = 0) or (ix = $3ff00000) then
    begin
      z := ax;
      if hy < 0 then z := one / z;
      if hx < 0 then
      begin
        if ((ix - $3ff00000) or yisint) = 0 then
          z := BitsDbl(UInt64($FFF80000) shl 32)  { (z-z)/(z-z): default NaN; Delphi folds x-x }
        else if yisint = 1 then
          z := -z;
      end;
      Exit(z);
    end;
  end;

  n := Integer((Cardinal(hx) shr 31)) - 1;

  if (n or yisint) = 0 then Exit(BitsDbl(UInt64($FFF80000) shl 32));  { (x-x)/(x-x) }

  s := one;
  if (n or (yisint - 1)) = 0 then s := -one;

  if iy > $41e00000 then
  begin
    if iy > $43f00000 then
    begin
      if ix <= $3fefffff then
      begin
        if hy < 0 then Exit(huge * huge) else Exit(tiny * tiny);
      end;
      if ix >= $3ff00000 then
      begin
        if hy > 0 then Exit(huge * huge) else Exit(tiny * tiny);
      end;
    end;
    if ix < $3fefffff then
    begin
      if hy < 0 then Exit(s * huge * huge) else Exit(s * tiny * tiny);
    end;
    if ix > $3ff00000 then
    begin
      if hy > 0 then Exit(s * huge * huge) else Exit(s * tiny * tiny);
    end;
    t := ax - one;
    w := (t * t) * (half - t * (thrd - t * qrtr));
    u := ivln2_h * t;
    v := t * ivln2_l - w * ivln2;
    t1 := u + v;
    SetLoW(t1, 0);
    t2 := v - (t1 - u);
  end
  else
  begin
    n := 0;
    if ix < $00100000 then
    begin
      ax := ax * two53; Dec(n, 53); ix := HiW(ax);
    end;
    n := n + ((ix shr 20) - $3ff);
    j := ix and $000fffff;
    ix := j or $3ff00000;
    if j <= $3988E then k := 0
    else if j < $BB67A then k := 1
    else
    begin
      k := 0; Inc(n); ix := ix - $00100000;
    end;
    SetHiW(ax, ix);

    u := ax - bp[k];
    v := one / (ax + bp[k]);
    ss := u * v;
    s_h := ss;
    SetLoW(s_h, 0);
    t_h := zero;
    SetHiW(t_h, ((ix shr 1) or $20000000) + $00080000 + (k shl 18));
    t_l := ax - (t_h - bp[k]);
    s_l := v * ((u - s_h * t_h) - s_h * t_l);
    s2 := ss * ss;
    r := s2 * s2 * (L1 + s2 * (L2 + s2 * (L3 + s2 * (L4 + s2 * (L5 + s2 * L6)))));
    r := r + s_l * (s_h + ss);
    s2 := s_h * s_h;
    t_h := 3 + s2 + r;
    SetLoW(t_h, 0);
    t_l := r - ((t_h - 3) - s2);
    u := s_h * t_h;
    v := s_l * t_h + t_l * ss;
    p_h := u + v;
    SetLoW(p_h, 0);
    p_l := v - (p_h - u);
    z_h := cp_h * p_h;
    z_l := cp_l * p_h + p_l * cp + dp_l[k];
    t := n;
    t1 := (((z_h + z_l) + dp_h[k]) + t);
    SetLoW(t1, 0);
    t2 := z_l - (((t1 - t) - dp_h[k]) - z_h);
  end;

  y1 := y;
  SetLoW(y1, 0);
  p_l := (y - y1) * t1 + y * t2;
  p_h := y1 * t1;
  z := p_l + p_h;
  j := HiW(z); i := Integer(LoW(z));
  if j >= $40900000 then
  begin
    if ((j - $40900000) or i) <> 0 then Exit(s * huge * huge)
    else if p_l + ovt > z - p_h then Exit(s * huge * huge);
  end
  else if (j and $7fffffff) >= $4090cc00 then
  begin
    if ((j - Integer($c090cc00)) or i) <> 0 then Exit(s * tiny * tiny)
    else if p_l <= z - p_h then Exit(s * tiny * tiny);
  end;

  i := j and $7fffffff;
  k := (i shr 20) - $3ff;
  n := 0;
  if i > $3fe00000 then
  begin
    n := j + ($00100000 shr (k + 1));
    k := ((n and $7fffffff) shr 20) - $3ff;
    t := zero;
    SetHiW(t, n and not ($000fffff shr k));
    n := ((n and $000fffff) or $00100000) shr (20 - k);
    if j < 0 then n := -n;
    p_h := p_h - t;
  end;
  t := p_l + p_h;
  SetLoW(t, 0);
  u := t * lg2_h;
  v := (p_l - (t - p_h)) * lg2 + t * lg2_l;
  z := u + v;
  w := v - (z - u);
  t := z * z;
  t1 := z - t * (P1 + t * (P2 + t * (P3 + t * (P4 + t * P5))));
  r := (z * t1) / (t1 - two) - (w + z * w);
  z := one - (r - z);
  j := HiW(z);
  j := j + Integer(Cardinal(n) shl 20);
  if (j div $100000) <= 0 then z := c_ldexp(z, n)
  else SetHiW(z, j);
  Result := s * z;
end;

function c_sin(x: Double): Double;
begin
  Result := {$IFDEF LUA_POSIX}px_sin(x){$ELSE}Sin(x){$ENDIF};
end;

function c_cos(x: Double): Double;
begin
  Result := {$IFDEF LUA_POSIX}px_cos(x){$ELSE}Cos(x){$ENDIF};
end;

function c_atan(x: Double): Double;
begin
  Result := {$IFDEF LUA_POSIX}px_atan(x){$ELSE}ArcTan(x){$ENDIF};
end;

{$IFDEF LUA_POSIX}
function c_rand: Integer;
begin
  Result := px_rand;
end;

procedure c_srand(seed: Cardinal);
begin
  px_srand(seed);
end;
{$ELSE}
{ ====================================================================
  rand / srand  (MSVC: per-thread LCG, initial seed 1)
  ==================================================================== }
threadvar
  holdrand_x: Cardinal;    { stored as seed xor 1 so that 0 means seed 1 }

function c_rand: Integer;
var h: Cardinal;
begin
  h := holdrand_x xor 1;
  h := h * 214013 + 2531011;
  holdrand_x := h xor 1;
  Result := Integer((h shr 16) and $7FFF);
end;

procedure c_srand(seed: Cardinal);
begin
  holdrand_x := seed xor 1;
end;
{$ENDIF}

end.
