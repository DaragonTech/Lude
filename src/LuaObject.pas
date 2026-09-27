{
  Lua 5.1.4 - Pascal port of lobject.c
  Some generic functions over Lua objects
}
unit LuaObject;

{$I lua.inc}

interface

uses
  LuaTypes;

var
  luaO_nilobject_: TValue;

function luaO_nilobject: PTValue; inline;
function luaO_log2(x: Cardinal): Integer;
function ceillog2(x: Cardinal): Integer; inline;
function luaO_int2fb(x: Cardinal): Integer;
function luaO_fb2int(x: Integer): Integer;
function luaO_rawequalObj(t1, t2: PTValue): Integer;
function luaO_str2d(s: PAnsiChar; var res: lua_Number): Integer;
{ internal (Pascal) version: arguments as an open array }
function luaO_pushfstring(L: Plua_State; fmt: PAnsiChar; const args: array of const): PAnsiChar;
{ C version: argp is a Microsoft x86/x64 va_list }
function luaO_pushvfstring(L: Plua_State; fmt: PAnsiChar; argp: Pointer): PAnsiChar;
procedure luaO_chunkid(outbuf: PAnsiChar; source: PAnsiChar; bufflen: size_t);

implementation

uses
  LuaCRT, LuaString, LuaDo, LuaVM;

function luaO_nilobject: PTValue;
begin
  Result := @luaO_nilobject_;
end;

{ converts an integer to a "floating point byte", represented as
  (eeeeexxx), where the real value is (1xxx) * 2^(eeeee - 1) if
  eeeee != 0 and (xxx) otherwise. }
function luaO_int2fb(x: Cardinal): Integer;
var e: Integer;
begin
  e := 0;
  while x >= 16 do
  begin
    x := (x + 1) shr 1;
    Inc(e);
  end;
  if x < 8 then Result := Integer(x)
  else Result := ((e + 1) shl 3) or (Integer(x) - 8);
end;

function luaO_fb2int(x: Integer): Integer;
var e: Integer;
begin
  e := (x shr 3) and 31;
  if e = 0 then Result := x
  else Result := ((x and 7) + 8) shl (e - 1);
end;

const
  log_2: array[0..255] of Byte = (
    0,1,2,2,3,3,3,3,4,4,4,4,4,4,4,4,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
    6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
    7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
    7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
    8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
    8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
    8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
    8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8);

function luaO_log2(x: Cardinal): Integer;
var l: Integer;
begin
  l := -1;
  while x >= 256 do
  begin
    Inc(l, 8);
    x := x shr 8;
  end;
  Result := l + log_2[x];
end;

function ceillog2(x: Cardinal): Integer;
begin
  Result := luaO_log2(x - 1) + 1;
end;

function luaO_rawequalObj(t1, t2: PTValue): Integer;
begin
  if t1^.tt <> t2^.tt then Exit(0);
  case t1^.tt of
    LUA_TNIL: Result := 1;
    LUA_TNUMBER: Result := Ord(luai_numeq(t1^.value.n, t2^.value.n));
    LUA_TBOOLEAN: Result := Ord(t1^.value.b = t2^.value.b);
    LUA_TLIGHTUSERDATA: Result := Ord(t1^.value.p = t2^.value.p);
  else
    Result := Ord(t1^.value.gc = t2^.value.gc);
  end;
end;

function luaO_str2d(s: PAnsiChar; var res: lua_Number): Integer;
var endptr: PAnsiChar;
begin
  res := c_strtod(s, @endptr);
  if endptr = s then Exit(0);  { conversion failed }
  if (endptr^ = 'x') or (endptr^ = 'X') then  { maybe an hexadecimal constant? }
    res := c_strtoul(s, @endptr, 16);
  if endptr^ = #0 then Exit(1);  { most common case }
  while c_isspace(Ord(endptr^)) do Inc(endptr);
  if endptr^ <> #0 then Exit(0);  { invalid trailing characters? }
  Result := 1;
end;

procedure pushstr(L: Plua_State; str: PAnsiChar);
begin
  setsvalue(L, L^.top, luaS_new(L, str));
  incr_top(L);
end;

type
  TArgSource = record
    isVA: Boolean;
    argp: PByte;                 { C va_list }
    va: PVarRec;                 { Pascal open array }
    vaCount, vaIdx: Integer;
    tmp: array[0..7] of AnsiString;  { keeps converted string arguments alive }
    ntmp: Integer;
  end;

const
  VA_SLOT = SizeOf(Pointer);     { int/pointer slot size in a MS va_list }

{$IF defined(LUA_POSIX) and not (defined(DARWIN) and defined(CPUAARCH64))}{$IFDEF CPUAARCH64}
{ AArch64 (AAPCS64) va_list: argp points to this structure }
type
  PA64VaList = ^TA64VaList;
  TA64VaList = record
    stack: PByte;       { next stacked argument }
    gr_top: PByte;      { end of the general register save area }
    vr_top: PByte;      { end of the FP/SIMD register save area }
    gr_offs: Integer;   { negative offset from gr_top, >= 0: registers used up }
    vr_offs: Integer;   { negative offset from vr_top (16 bytes per register) }
  end;

function VaGP(var a: TArgSource): Pointer;   { next int/pointer argument }
var v: PA64VaList; offs: Integer;
begin
  v := PA64VaList(a.argp);
  offs := v^.gr_offs;
  if offs < 0 then
  begin
    v^.gr_offs := offs + 8;
    if offs + 8 <= 0 then Exit(v^.gr_top + offs);
  end;
  Result := v^.stack;
  Inc(v^.stack, 8);
end;

function VaFP(var a: TArgSource): Pointer;   { next double argument }
var v: PA64VaList; offs: Integer;
begin
  v := PA64VaList(a.argp);
  offs := v^.vr_offs;
  if offs < 0 then
  begin
    v^.vr_offs := offs + 16;
    if offs + 16 <= 0 then Exit(v^.vr_top + offs);
  end;
  Result := v^.stack;
  Inc(v^.stack, 8);
end;
{$ELSE}
{ System V x86-64 va_list: argp points to this structure }
type
  PSysVVaList = ^TSysVVaList;
  TSysVVaList = record
    gp_offset: Cardinal;         { next integer register slot (< 48) }
    fp_offset: Cardinal;         { next SSE register slot (< 176) }
    overflow_arg_area: PByte;    { arguments passed on the stack }
    reg_save_area: PByte;
  end;

function VaGP(var a: TArgSource): Pointer;   { next int/pointer argument }
var v: PSysVVaList;
begin
  v := PSysVVaList(a.argp);
  if v^.gp_offset < 48 then
  begin
    Result := v^.reg_save_area + v^.gp_offset;
    Inc(v^.gp_offset, 8);
  end
  else
  begin
    Result := v^.overflow_arg_area;
    Inc(v^.overflow_arg_area, 8);
  end;
end;

function VaFP(var a: TArgSource): Pointer;   { next double argument }
var v: PSysVVaList;
begin
  v := PSysVVaList(a.argp);
  if v^.fp_offset < 176 then
  begin
    Result := v^.reg_save_area + v^.fp_offset;
    Inc(v^.fp_offset, 16);
  end
  else
  begin
    Result := v^.overflow_arg_area;
    Inc(v^.overflow_arg_area, 8);
  end;
end;
{$ENDIF}
{$ELSE}
{ Windows and Apple ARM64: the va_list points to the arguments, 8-byte
  slots (4 for int/pointer on Win32) }
function VaGP(var a: TArgSource): Pointer;
begin
  Result := a.argp;
  Inc(a.argp, VA_SLOT);
end;

function VaFP(var a: TArgSource): Pointer;
begin
  Result := a.argp;
  Inc(a.argp, 8);
end;
{$IFEND}

function NextVarRec(var a: TArgSource): PVarRec;
begin
  if a.vaIdx < a.vaCount then
  begin
    Result := a.va;
    Inc(Result, a.vaIdx);
    Inc(a.vaIdx);
  end
  else
    Result := nil;
end;

function ArgToAnsi(v: PVarRec): AnsiString;
begin
  case v^.VType of
    vtUnicodeString: Result := AnsiString(UnicodeString(v^.VUnicodeString));
    vtPWideChar: Result := AnsiString(WideString(v^.VPWideChar));
    vtWideChar: Result := AnsiString(WideString(v^.VWideChar));
    vtString: Result := AnsiString(v^.VString^);
    vtChar: Result := v^.VChar;
  else
    Result := '';
  end;
end;

function ArgPChar(var a: TArgSource): PAnsiChar;
var v: PVarRec;
begin
  if a.isVA then
  begin
    Result := PPAnsiChar(VaGP(a))^;
    Exit;
  end;
  v := NextVarRec(a);
  Result := nil;
  if v = nil then Exit;
  case v^.VType of
    vtPChar: Result := v^.VPChar;
    vtAnsiString: begin Result := PAnsiChar(v^.VAnsiString); if Result = nil then Result := ''; end;
    vtPointer: Result := v^.VPointer;
    { Delphi 2009+ passes string literals/constants as UnicodeString (or
      WideChar for one character); convert them to AnsiString }
    vtUnicodeString, vtPWideChar, vtWideChar, vtString, vtChar:
      begin
        a.tmp[a.ntmp and 7] := ArgToAnsi(v);
        Result := PAnsiChar(a.tmp[a.ntmp and 7]);
        if Result = nil then Result := '';
        Inc(a.ntmp);
      end;
  end;
end;

function ArgInt(var a: TArgSource): Integer;
var v: PVarRec;
begin
  if a.isVA then
  begin
    Result := PInteger(VaGP(a))^;
    Exit;
  end;
  v := NextVarRec(a);
  Result := 0;
  if v = nil then Exit;
  case v^.VType of
    vtInteger: Result := v^.VInteger;
    vtInt64: Result := Integer(v^.VInt64^);
    vtChar: Result := Ord(v^.VChar);
    vtWideChar: Result := Ord(v^.VWideChar);
    vtBoolean: Result := Ord(v^.VBoolean);
  end;
end;

function ArgNum(var a: TArgSource): lua_Number;
var v: PVarRec;
begin
  if a.isVA then
  begin
    Result := PDouble(VaFP(a))^;
    Exit;
  end;
  v := NextVarRec(a);
  Result := 0;
  if v = nil then Exit;
  case v^.VType of
    vtExtended: Result := v^.VExtended^;
    vtInteger: Result := v^.VInteger;
    vtInt64: Result := v^.VInt64^;
  end;
end;

function ArgPtr(var a: TArgSource): Pointer;
var v: PVarRec;
begin
  if a.isVA then
  begin
    Result := PPointer(VaGP(a))^;
    Exit;
  end;
  v := NextVarRec(a);
  Result := nil;
  if v = nil then Exit;
  case v^.VType of
    vtPointer: Result := v^.VPointer;
    vtPChar: Result := v^.VPChar;
    vtObject: Result := v^.VObject;
  end;
end;

{ this function handles only `%d', `%c', %f, %p, and `%s' formats }
function pushvfstring(L: Plua_State; fmt: PAnsiChar; var a: TArgSource): PAnsiChar;
var n: Integer; e: PAnsiChar; s: PAnsiChar; buff: array[0..3] of AnsiChar; ps: AnsiString;
begin
  n := 1;
  pushstr(L, '');
  while True do
  begin
    e := c_strchr(fmt, Ord('%'));
    if e = nil then Break;
    setsvalue(L, L^.top, luaS_newlstr(L, fmt, e - fmt));
    incr_top(L);
    case (e + 1)^ of
      's':
        begin
          s := ArgPChar(a);
          if s = nil then s := '(null)';
          pushstr(L, s);
        end;
      'c':
        begin
          buff[0] := AnsiChar(Byte(ArgInt(a)));
          buff[1] := #0;
          pushstr(L, buff);
        end;
      'd':
        begin
          setnvalue(L^.top, ArgInt(a));
          incr_top(L);
        end;
      'f':
        begin
          setnvalue(L^.top, ArgNum(a));
          incr_top(L);
        end;
      'p':
        begin
          ps := c_fmt_pointer(ArgPtr(a));
          pushstr(L, PAnsiChar(ps));
        end;
      '%':
        pushstr(L, '%');
    else
      begin
        buff[0] := '%';
        buff[1] := (e + 1)^;
        buff[2] := #0;
        pushstr(L, buff);
        if (e + 1)^ = #0 then
        begin
          { format ends with a lone '%' }
          Inc(n, 2);
          fmt := e + 1;
          Break;
        end;
      end;
    end;
    Inc(n, 2);
    fmt := e + 2;
  end;
  pushstr(L, fmt);
  luaV_concat(L, n + 1, StkDiff(L^.top, L^.base) - 1);
  Dec(L^.top, n);
  Result := svalue(L^.top - 1);
end;

function luaO_pushfstring(L: Plua_State; fmt: PAnsiChar; const args: array of const): PAnsiChar;
var a: TArgSource;
begin
  a.isVA := False;
  a.ntmp := 0;
  a.argp := nil;
  if Length(args) > 0 then a.va := @args[0] else a.va := nil;
  a.vaCount := Length(args);
  a.vaIdx := 0;
  Result := pushvfstring(L, fmt, a);
end;

function luaO_pushvfstring(L: Plua_State; fmt: PAnsiChar; argp: Pointer): PAnsiChar;
var a: TArgSource;
begin
  a.isVA := True;
  a.ntmp := 0;
  a.argp := argp;
  a.va := nil;
  a.vaCount := 0;
  a.vaIdx := 0;
  Result := pushvfstring(L, fmt, a);
end;

procedure luaO_chunkid(outbuf: PAnsiChar; source: PAnsiChar; bufflen: size_t);
var l, len: size_t;
begin
  if source^ = '=' then
  begin
    c_strncpy(outbuf, source + 1, bufflen);  { remove first char }
    outbuf[bufflen - 1] := #0;  { ensures null termination }
  end
  else
  begin  { out = "source", or "...source" }
    if source^ = '@' then
    begin
      Inc(source);  { skip the `@' }
      bufflen := bufflen - 8;   { sizeof(" '...' ") }
      l := c_strlen(source);
      outbuf^ := #0;
      if l > bufflen then
      begin
        source := source + (l - bufflen);  { get last part of file name }
        c_strcat(outbuf, '...');
      end;
      c_strcat(outbuf, source);
    end
    else
    begin  { out = [string "string"] }
      len := c_strcspn(source, #10#13);  { stop at first newline }
      bufflen := bufflen - 17;  { sizeof(" [string \"...\"] ") }
      if len > bufflen then len := bufflen;
      c_strcpy(outbuf, '[string "');
      if source[len] <> #0 then
      begin  { must truncate? }
        c_strncat(outbuf, source, len);
        c_strcat(outbuf, '...');
      end
      else
        c_strcat(outbuf, source);
      c_strcat(outbuf, '"]');
    end;
  end;
end;

initialization
  luaO_nilobject_.value.p := nil;
  luaO_nilobject_.tt := LUA_TNIL;
end.
