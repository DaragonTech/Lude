{
  Lua 5.1.4 - Pascal port of lapi.c
  Lua API
}
unit LuaAPI;

{$I lua.inc}

interface

uses
  LuaTypes;

const
  lua_ident: PAnsiChar =
    '$Lua: ' + LUA_RELEASE + ' ' + LUA_COPYRIGHT + ' $'#10 +
    '$Authors: ' + LUA_AUTHORS + ' $'#10 +
    '$URL: www.lua.org $'#10;

procedure luaA_pushobject(L: Plua_State; o: PTValue);

{ state manipulation }
function lua_newthread(L: Plua_State): Plua_State; cdecl;
function lua_atpanic(L: Plua_State; panicf: lua_CFunction): lua_CFunction; cdecl;

{ basic stack manipulation }
function lua_gettop(L: Plua_State): Integer; cdecl;
procedure lua_settop(L: Plua_State; idx: Integer); cdecl;
procedure lua_pushvalue(L: Plua_State; idx: Integer); cdecl;
procedure lua_remove(L: Plua_State; idx: Integer); cdecl;
procedure lua_insert(L: Plua_State; idx: Integer); cdecl;
procedure lua_replace(L: Plua_State; idx: Integer); cdecl;
function lua_checkstack(L: Plua_State; size: Integer): Integer; cdecl;
procedure lua_xmove(from, to_: Plua_State; n: Integer); cdecl;

{ access functions (stack -> C) }
function lua_isnumber(L: Plua_State; idx: Integer): Integer; cdecl;
function lua_isstring(L: Plua_State; idx: Integer): Integer; cdecl;
function lua_iscfunction(L: Plua_State; idx: Integer): Integer; cdecl;
function lua_isuserdata(L: Plua_State; idx: Integer): Integer; cdecl;
function lua_type(L: Plua_State; idx: Integer): Integer; cdecl;
function lua_typename(L: Plua_State; t: Integer): PAnsiChar; cdecl;
function lua_equal(L: Plua_State; index1, index2: Integer): Integer; cdecl;
function lua_rawequal(L: Plua_State; index1, index2: Integer): Integer; cdecl;
function lua_lessthan(L: Plua_State; index1, index2: Integer): Integer; cdecl;
function lua_tonumber(L: Plua_State; idx: Integer): lua_Number; cdecl;
function lua_tointeger(L: Plua_State; idx: Integer): lua_Integer; cdecl;
function lua_toboolean(L: Plua_State; idx: Integer): Integer; cdecl;
function lua_tolstring(L: Plua_State; idx: Integer; len: Psize_t): PAnsiChar; cdecl;
function lua_objlen(L: Plua_State; idx: Integer): size_t; cdecl;
function lua_tocfunction(L: Plua_State; idx: Integer): lua_CFunction; cdecl;
function lua_touserdata(L: Plua_State; idx: Integer): Pointer; cdecl;
function lua_tothread(L: Plua_State; idx: Integer): Plua_State; cdecl;
function lua_topointer(L: Plua_State; idx: Integer): Pointer; cdecl;

{ push functions (C -> stack) }
procedure lua_pushnil(L: Plua_State); cdecl;
procedure lua_pushnumber(L: Plua_State; n: lua_Number); cdecl;
procedure lua_pushinteger(L: Plua_State; n: lua_Integer); cdecl;
procedure lua_pushlstring(L: Plua_State; s: PAnsiChar; len: size_t); cdecl;
procedure lua_pushstring(L: Plua_State; s: PAnsiChar); cdecl;
function lua_pushvfstring(L: Plua_State; fmt: PAnsiChar; argp: Pointer): PAnsiChar; cdecl;
{ C varargs: const char *lua_pushfstring(lua_State *L, const char *fmt, ...) }
function lua_pushfstring(L: Plua_State; fmt: PAnsiChar): PAnsiChar; cdecl;
procedure lua_pushcclosure(L: Plua_State; fn: lua_CFunction; n: Integer); cdecl;
procedure lua_pushboolean(L: Plua_State; b: Integer); cdecl;
procedure lua_pushlightuserdata(L: Plua_State; p: Pointer); cdecl;
function lua_pushthread(L: Plua_State): Integer; cdecl;

{ get functions (Lua -> stack) }
procedure lua_gettable(L: Plua_State; idx: Integer); cdecl;
procedure lua_getfield(L: Plua_State; idx: Integer; k: PAnsiChar); cdecl;
procedure lua_rawget(L: Plua_State; idx: Integer); cdecl;
procedure lua_rawgeti(L: Plua_State; idx: Integer; n: Integer); cdecl;
procedure lua_createtable(L: Plua_State; narray, nrec: Integer); cdecl;
function lua_newuserdata(L: Plua_State; size: size_t): Pointer; cdecl;
function lua_getmetatable(L: Plua_State; objindex: Integer): Integer; cdecl;
procedure lua_getfenv(L: Plua_State; idx: Integer); cdecl;

{ set functions (stack -> Lua) }
procedure lua_settable(L: Plua_State; idx: Integer); cdecl;
procedure lua_setfield(L: Plua_State; idx: Integer; k: PAnsiChar); cdecl;
procedure lua_rawset(L: Plua_State; idx: Integer); cdecl;
procedure lua_rawseti(L: Plua_State; idx: Integer; n: Integer); cdecl;
function lua_setmetatable(L: Plua_State; objindex: Integer): Integer; cdecl;
function lua_setfenv(L: Plua_State; idx: Integer): Integer; cdecl;

{ `load' and `call' functions (load and run Lua code) }
procedure lua_call(L: Plua_State; nargs, nresults: Integer); cdecl;
function lua_pcall(L: Plua_State; nargs, nresults, errfunc: Integer): Integer; cdecl;
function lua_cpcall(L: Plua_State; func: lua_CFunction; ud: Pointer): Integer; cdecl;
function lua_load(L: Plua_State; reader: lua_Reader; data: Pointer; chunkname: PAnsiChar): Integer; cdecl;
function lua_dump(L: Plua_State; writer: lua_Writer; data: Pointer): Integer; cdecl;

{ coroutine functions: lua_yield / lua_resume are in LuaDo }
function lua_status(L: Plua_State): Integer; cdecl;

{ garbage-collection function }
function lua_gc(L: Plua_State; what, data: Integer): Integer; cdecl;

{ miscellaneous functions }
function lua_error(L: Plua_State): Integer; cdecl;
function lua_next(L: Plua_State; idx: Integer): Integer; cdecl;
procedure lua_concat(L: Plua_State; n: Integer); cdecl;
function lua_getallocf(L: Plua_State; ud: PPointer): lua_Alloc; cdecl;
procedure lua_setallocf(L: Plua_State; f: lua_Alloc; ud: Pointer); cdecl;
procedure lua_setlevel(from, to_: Plua_State); cdecl;

function lua_getupvalue(L: Plua_State; funcindex, n: Integer): PAnsiChar; cdecl;
function lua_setupvalue(L: Plua_State; funcindex, n: Integer): PAnsiChar; cdecl;

{ lua.h macros, for Pascal users }
procedure lua_pop(L: Plua_State; n: Integer); inline;
procedure lua_newtable(L: Plua_State); inline;
procedure lua_pushcfunction(L: Plua_State; f: lua_CFunction); inline;
procedure lua_register(L: Plua_State; n: PAnsiChar; f: lua_CFunction); inline;
function lua_isfunction(L: Plua_State; n: Integer): Boolean; inline;
function lua_istable(L: Plua_State; n: Integer): Boolean; inline;
function lua_islightuserdata(L: Plua_State; n: Integer): Boolean; inline;
function lua_isnil(L: Plua_State; n: Integer): Boolean; inline;
function lua_isboolean(L: Plua_State; n: Integer): Boolean; inline;
function lua_isthread(L: Plua_State; n: Integer): Boolean; inline;
function lua_isnone(L: Plua_State; n: Integer): Boolean; inline;
function lua_isnoneornil(L: Plua_State; n: Integer): Boolean; inline;
procedure lua_pushliteral(L: Plua_State; const s: AnsiString); inline;
procedure lua_setglobal(L: Plua_State; s: PAnsiChar); inline;
procedure lua_getglobal(L: Plua_State; s: PAnsiChar); inline;
function lua_tostring(L: Plua_State; i: Integer): PAnsiChar; inline;
function lua_upvalueindex(i: Integer): Integer; inline;

implementation

uses
  LuaCRT, LuaObject, LuaMem, LuaString, LuaFunc, LuaTable, LuaTM, LuaGC,
  LuaState, LuaDo, LuaDebug, LuaVM, LuaZIO, LuaDump;

function index2adr(L: Plua_State; idx: Integer): PTValue;
var o: PTValue; func: PClosure;
begin
  if idx > 0 then
  begin
    o := L^.base + (idx - 1);
    if PAnsiChar(o) >= PAnsiChar(L^.top) then Result := luaO_nilobject
    else Result := o;
  end
  else if idx > LUA_REGISTRYINDEX then
    Result := L^.top + idx
  else
    case idx of  { pseudo-indices }
      LUA_REGISTRYINDEX: Result := registry(L);
      LUA_ENVIRONINDEX:
        begin
          func := curr_func(L);
          sethvalue(L, @L^.env, func^.c.env);
          Result := @L^.env;
        end;
      LUA_GLOBALSINDEX: Result := gt(L);
    else
      begin
        func := curr_func(L);
        idx := LUA_GLOBALSINDEX - idx;
        if idx <= func^.c.nupvalues then
          Result := @PTValue(@func^.c.upvalue)[idx - 1]
        else
          Result := luaO_nilobject;
      end;
    end;
end;

function getcurrenv(L: Plua_State): PTable;
begin
  if L^.ci = L^.base_ci then  { no enclosing function? }
    Result := hvalue(gt(L))  { use global table as environment }
  else
    Result := curr_func(L)^.c.env;
end;

procedure api_incr_top(L: Plua_State); inline;
begin
  Inc(L^.top);
end;

procedure luaA_pushobject(L: Plua_State; o: PTValue);
begin
  setobj(L, L^.top, o);
  api_incr_top(L);
end;

function lua_checkstack(L: Plua_State; size: Integer): Integer; cdecl;
var res: Integer;
begin
  res := 1;
  if (size > LUAI_MAXCSTACK) or (StkDiff(L^.top, L^.base) + size > LUAI_MAXCSTACK) then
    res := 0  { stack overflow }
  else if size > 0 then
  begin
    luaD_checkstack(L, size);
    if PAnsiChar(L^.ci^.top) < PAnsiChar(L^.top + size) then
      L^.ci^.top := L^.top + size;
  end;
  Result := res;
end;

procedure lua_xmove(from, to_: Plua_State; n: Integer); cdecl;
var i: Integer;
begin
  if from = to_ then Exit;
  Dec(from^.top, n);
  for i := 0 to n - 1 do
  begin
    setobj(to_, to_^.top, from^.top + i);
    Inc(to_^.top);
  end;
end;

procedure lua_setlevel(from, to_: Plua_State); cdecl;
begin
  to_^.nCcalls := from^.nCcalls;
end;

function lua_atpanic(L: Plua_State; panicf: lua_CFunction): lua_CFunction; cdecl;
begin
  Result := L^.l_G^.panic;
  L^.l_G^.panic := panicf;
end;

function lua_newthread(L: Plua_State): Plua_State; cdecl;
var L1: Plua_State;
begin
  luaC_checkGC(L);
  L1 := luaE_newthread(L);
  setthvalue(L, L^.top, L1);
  api_incr_top(L);
  Result := L1;
end;

{ basic stack manipulation }

function lua_gettop(L: Plua_State): Integer; cdecl;
begin
  Result := StkDiff(L^.top, L^.base);
end;

procedure lua_settop(L: Plua_State; idx: Integer); cdecl;
begin
  if idx >= 0 then
  begin
    while PAnsiChar(L^.top) < PAnsiChar(L^.base + idx) do
    begin
      setnilvalue(L^.top);
      Inc(L^.top);
    end;
    L^.top := L^.base + idx;
  end
  else
    L^.top := L^.top + (idx + 1);  { `subtract' index (index is negative) }
end;

procedure lua_remove(L: Plua_State; idx: Integer); cdecl;
var p: StkId;
begin
  p := index2adr(L, idx);
  Inc(p);
  while PAnsiChar(p) < PAnsiChar(L^.top) do
  begin
    setobj(L, p - 1, p);
    Inc(p);
  end;
  Dec(L^.top);
end;

procedure lua_insert(L: Plua_State; idx: Integer); cdecl;
var p, q: StkId;
begin
  p := index2adr(L, idx);
  q := L^.top;
  while PAnsiChar(q) > PAnsiChar(p) do
  begin
    setobj(L, q, q - 1);
    Dec(q);
  end;
  setobj(L, p, L^.top);
end;

procedure lua_replace(L: Plua_State; idx: Integer); cdecl;
var o: StkId; func: PClosure;
begin
  { explicit test for incompatible code }
  if (idx = LUA_ENVIRONINDEX) and (L^.ci = L^.base_ci) then
    luaG_runerror(L, 'no calling environment', []);
  o := index2adr(L, idx);
  if idx = LUA_ENVIRONINDEX then
  begin
    func := curr_func(L);
    func^.c.env := hvalue(L^.top - 1);
    luaC_barrier(L, func, L^.top - 1);
  end
  else
  begin
    setobj(L, o, L^.top - 1);
    if idx < LUA_GLOBALSINDEX then  { function upvalue? }
      luaC_barrier(L, curr_func(L), L^.top - 1);
  end;
  Dec(L^.top);
end;

procedure lua_pushvalue(L: Plua_State; idx: Integer); cdecl;
begin
  setobj(L, L^.top, index2adr(L, idx));
  api_incr_top(L);
end;

{ access functions (stack -> C) }

function lua_type(L: Plua_State; idx: Integer): Integer; cdecl;
var o: StkId;
begin
  o := index2adr(L, idx);
  if o = luaO_nilobject then Result := LUA_TNONE else Result := o^.tt;
end;

function lua_typename(L: Plua_State; t: Integer): PAnsiChar; cdecl;
begin
  if t = LUA_TNONE then Result := 'no value' else Result := luaT_typenames[t];
end;

function lua_iscfunction(L: Plua_State; idx: Integer): Integer; cdecl;
begin
  Result := Ord(iscfunction(index2adr(L, idx)));
end;

function lua_isnumber(L: Plua_State; idx: Integer): Integer; cdecl;
var n: TValue; o: PTValue;
begin
  o := index2adr(L, idx);
  Result := Ord(tonumber(o, @n));
end;

function lua_isstring(L: Plua_State; idx: Integer): Integer; cdecl;
var t: Integer;
begin
  t := lua_type(L, idx);
  Result := Ord((t = LUA_TSTRING) or (t = LUA_TNUMBER));
end;

function lua_isuserdata(L: Plua_State; idx: Integer): Integer; cdecl;
var o: PTValue;
begin
  o := index2adr(L, idx);
  Result := Ord(ttisuserdata(o) or ttislightuserdata(o));
end;

function lua_rawequal(L: Plua_State; index1, index2: Integer): Integer; cdecl;
var o1, o2: StkId;
begin
  o1 := index2adr(L, index1);
  o2 := index2adr(L, index2);
  if (o1 = luaO_nilobject) or (o2 = luaO_nilobject) then Result := 0
  else Result := luaO_rawequalObj(o1, o2);
end;

function lua_equal(L: Plua_State; index1, index2: Integer): Integer; cdecl;
var o1, o2: StkId;
begin
  o1 := index2adr(L, index1);
  o2 := index2adr(L, index2);
  if (o1 = luaO_nilobject) or (o2 = luaO_nilobject) then Result := 0
  else Result := Ord(equalobj(L, o1, o2));
end;

function lua_lessthan(L: Plua_State; index1, index2: Integer): Integer; cdecl;
var o1, o2: StkId;
begin
  o1 := index2adr(L, index1);
  o2 := index2adr(L, index2);
  if (o1 = luaO_nilobject) or (o2 = luaO_nilobject) then Result := 0
  else Result := luaV_lessthan(L, o1, o2);
end;

function lua_tonumber(L: Plua_State; idx: Integer): lua_Number; cdecl;
var n: TValue; o: PTValue;
begin
  o := index2adr(L, idx);
  if tonumber(o, @n) then Result := o^.value.n
  else Result := 0;
end;

function lua_tointeger(L: Plua_State; idx: Integer): lua_Integer; cdecl;
var n: TValue; o: PTValue;
begin
  o := index2adr(L, idx);
  if tonumber(o, @n) then
    Result := lua_number2integer(o^.value.n)
  else
    Result := 0;
end;

function lua_toboolean(L: Plua_State; idx: Integer): Integer; cdecl;
begin
  Result := Ord(not l_isfalse(index2adr(L, idx)));
end;

function lua_tolstring(L: Plua_State; idx: Integer; len: Psize_t): PAnsiChar; cdecl;
var o: StkId;
begin
  o := index2adr(L, idx);
  if not ttisstring(o) then
  begin
    if luaV_tostring(L, o) = 0 then
    begin  { conversion failed? }
      if len <> nil then len^ := 0;
      Exit(nil);
    end;
    luaC_checkGC(L);
    o := index2adr(L, idx);  { previous call may reallocate the stack }
  end;
  if len <> nil then len^ := tsvalue(o)^.len;
  Result := svalue(o);
end;

function lua_objlen(L: Plua_State; idx: Integer): size_t; cdecl;
var o: StkId;
begin
  o := index2adr(L, idx);
  case o^.tt of
    LUA_TSTRING: Result := tsvalue(o)^.len;
    LUA_TUSERDATA: Result := uvalue(o)^.len;
    LUA_TTABLE: Result := size_t(luaH_getn(hvalue(o)));
    LUA_TNUMBER:
      if luaV_tostring(L, o) <> 0 then Result := tsvalue(o)^.len
      else Result := 0;
  else
    Result := 0;
  end;
end;

function lua_tocfunction(L: Plua_State; idx: Integer): lua_CFunction; cdecl;
var o: StkId;
begin
  o := index2adr(L, idx);
  if not iscfunction(o) then Result := nil
  else Result := clvalue(o)^.c.f;
end;

function lua_touserdata(L: Plua_State; idx: Integer): Pointer; cdecl;
var o: StkId;
begin
  o := index2adr(L, idx);
  case o^.tt of
    LUA_TUSERDATA: Result := PAnsiChar(rawuvalue(o)) + UDATA_SIZE;
    LUA_TLIGHTUSERDATA: Result := pvalue(o);
  else
    Result := nil;
  end;
end;

function lua_tothread(L: Plua_State; idx: Integer): Plua_State; cdecl;
var o: StkId;
begin
  o := index2adr(L, idx);
  if not ttisthread(o) then Result := nil else Result := thvalue(o);
end;

function lua_topointer(L: Plua_State; idx: Integer): Pointer; cdecl;
var o: StkId;
begin
  o := index2adr(L, idx);
  case o^.tt of
    LUA_TTABLE: Result := hvalue(o);
    LUA_TFUNCTION: Result := clvalue(o);
    LUA_TTHREAD: Result := thvalue(o);
    LUA_TUSERDATA, LUA_TLIGHTUSERDATA: Result := lua_touserdata(L, idx);
  else
    Result := nil;
  end;
end;

{ push functions (C -> stack) }

procedure lua_pushnil(L: Plua_State); cdecl;
begin
  setnilvalue(L^.top);
  api_incr_top(L);
end;

procedure lua_pushnumber(L: Plua_State; n: lua_Number); cdecl;
begin
  setnvalue(L^.top, n);
  api_incr_top(L);
end;

procedure lua_pushinteger(L: Plua_State; n: lua_Integer); cdecl;
begin
  setnvalue(L^.top, n);
  api_incr_top(L);
end;

procedure lua_pushlstring(L: Plua_State; s: PAnsiChar; len: size_t); cdecl;
begin
  luaC_checkGC(L);
  setsvalue(L, L^.top, luaS_newlstr(L, s, len));
  api_incr_top(L);
end;

procedure lua_pushstring(L: Plua_State; s: PAnsiChar); cdecl;
begin
  if s = nil then
    lua_pushnil(L)
  else
    lua_pushlstring(L, s, c_strlen(s));
end;

function lua_pushvfstring(L: Plua_State; fmt: PAnsiChar; argp: Pointer): PAnsiChar; cdecl;
begin
  luaC_checkGC(L);
  Result := luaO_pushvfstring(L, fmt, argp);
end;

{$IFDEF LUA_POSIX}
{$IF defined(CPUAARCH64) and defined(DARWIN)}
{ Apple ARM64: variadic arguments are passed on the stack in 8-byte slots,
  so the va_list is simply the stack pointer at entry. }
function lua_pushfstring(L: Plua_State; fmt: PAnsiChar): PAnsiChar; cdecl;
  assembler; nostackframe;
asm
  mov x2, sp
  b lua_pushvfstring
end;
{$ELSE}
{$IFDEF CPUAARCH64}
{ AArch64 (AAPCS64) varargs: save x0-x7 and d0-d7 (in 16-byte slots, as for
  q0-q7) in register save areas,
  build a va_list (__stack, __gr_top, __vr_top, __gr_offs, __vr_offs)
  (offsets -48 and -128 skip the two named arguments / start at q0) and
  call the va_list version (va_list is passed by reference). }
function lua_pushfstring(L: Plua_State; fmt: PAnsiChar): PAnsiChar; cdecl;
  assembler; nostackframe;
asm
  stp x29, x30, [sp, #-16]!
  mov x29, sp
  sub sp, sp, #224
  stp x0, x1, [sp]
  stp x2, x3, [sp, #16]
  stp x4, x5, [sp, #32]
  stp x6, x7, [sp, #48]
  str d0, [sp, #64]
  str d1, [sp, #80]
  str d2, [sp, #96]
  str d3, [sp, #112]
  str d4, [sp, #128]
  str d5, [sp, #144]
  str d6, [sp, #160]
  str d7, [sp, #176]
  add x9, x29, #16
  str x9, [sp, #192]
  add x9, sp, #64
  str x9, [sp, #200]
  add x9, sp, #192
  str x9, [sp, #208]
  movn w9, #47
  str w9, [sp, #216]
  movn w9, #127
  str w9, [sp, #220]
  add x2, sp, #192
  bl lua_pushvfstring
  mov sp, x29
  ldp x29, x30, [sp], #16
  ret
end;
{$ELSE}
{ System V x86-64 varargs: store the argument registers in a register save
  area, build a va_list (gp_offset 16 and fp_offset 48 skip the named
  arguments), and call the va_list version. }
function lua_pushfstring(L: Plua_State; fmt: PAnsiChar): PAnsiChar; cdecl;
  assembler; nostackframe;
asm
  sub rsp, 216
  mov [rsp], rdi
  mov [rsp+8], rsi
  mov [rsp+16], rdx
  mov [rsp+24], rcx
  mov [rsp+32], r8
  mov [rsp+40], r9
  movaps [rsp+48], xmm0
  movaps [rsp+64], xmm1
  movaps [rsp+80], xmm2
  movaps [rsp+96], xmm3
  movaps [rsp+112], xmm4
  movaps [rsp+128], xmm5
  movaps [rsp+144], xmm6
  movaps [rsp+160], xmm7
  mov dword ptr [rsp+176], 16
  mov dword ptr [rsp+180], 48
  lea rax, [rsp+224]
  mov [rsp+184], rax
  mov [rsp+192], rsp
  lea rdx, [rsp+176]
  call lua_pushvfstring
  add rsp, 216
  ret
end;
{$ENDIF}
{$IFEND}
{$ELSE}
{$IFDEF LUA_64}
{ Microsoft x64 varargs: spill r8/r9 into their home slots so that the
  arguments after `fmt' form a contiguous va_list, then tail-jump. }
function lua_pushfstring(L: Plua_State; fmt: PAnsiChar): PAnsiChar; cdecl;
  {$IFDEF FPC} assembler; nostackframe; {$ENDIF}
asm
  {$IFNDEF FPC} .NOFRAME {$ENDIF}
  mov [rsp+24], r8
  mov [rsp+32], r9
  lea r8, [rsp+24]
  jmp lua_pushvfstring
end;
{$ELSE}
{ x86 cdecl: arguments are on the stack right after `fmt' }
function lua_pushfstring(L: Plua_State; fmt: PAnsiChar): PAnsiChar; cdecl;
begin
  Result := lua_pushvfstring(L, fmt, PAnsiChar(@fmt) + SizeOf(Pointer));
end;
{$ENDIF}
{$ENDIF}

procedure lua_pushcclosure(L: Plua_State; fn: lua_CFunction; n: Integer); cdecl;
var cl: PClosure;
begin
  luaC_checkGC(L);
  cl := luaF_newCclosure(L, n, getcurrenv(L));
  cl^.c.f := fn;
  Dec(L^.top, n);
  while n > 0 do
  begin
    Dec(n);
    setobj(L, @PTValue(@cl^.c.upvalue)[n], L^.top + n);
  end;
  setclvalue(L, L^.top, cl);
  api_incr_top(L);
end;

procedure lua_pushboolean(L: Plua_State; b: Integer); cdecl;
begin
  setbvalue(L^.top, Ord(b <> 0));  { ensure that true is 1 }
  api_incr_top(L);
end;

procedure lua_pushlightuserdata(L: Plua_State; p: Pointer); cdecl;
begin
  setpvalue(L^.top, p);
  api_incr_top(L);
end;

function lua_pushthread(L: Plua_State): Integer; cdecl;
begin
  setthvalue(L, L^.top, L);
  api_incr_top(L);
  Result := Ord(L^.l_G^.mainthread = L);
end;

{ get functions (Lua -> stack) }

procedure lua_gettable(L: Plua_State; idx: Integer); cdecl;
var t: StkId;
begin
  t := index2adr(L, idx);
  luaV_gettable(L, t, L^.top - 1, L^.top - 1);
end;

procedure lua_getfield(L: Plua_State; idx: Integer; k: PAnsiChar); cdecl;
var t: StkId; key: TValue;
begin
  t := index2adr(L, idx);
  setsvalue(L, @key, luaS_new(L, k));
  luaV_gettable(L, t, @key, L^.top);
  api_incr_top(L);
end;

procedure lua_rawget(L: Plua_State; idx: Integer); cdecl;
var t: StkId;
begin
  t := index2adr(L, idx);
  setobj(L, L^.top - 1, luaH_get(hvalue(t), L^.top - 1));
end;

procedure lua_rawgeti(L: Plua_State; idx: Integer; n: Integer); cdecl;
var o: StkId;
begin
  o := index2adr(L, idx);
  setobj(L, L^.top, luaH_getnum(hvalue(o), n));
  api_incr_top(L);
end;

procedure lua_createtable(L: Plua_State; narray, nrec: Integer); cdecl;
begin
  luaC_checkGC(L);
  sethvalue(L, L^.top, luaH_new(L, narray, nrec));
  api_incr_top(L);
end;

function lua_getmetatable(L: Plua_State; objindex: Integer): Integer; cdecl;
var obj: PTValue; mt: PTable;
begin
  obj := index2adr(L, objindex);
  case obj^.tt of
    LUA_TTABLE: mt := hvalue(obj)^.metatable;
    LUA_TUSERDATA: mt := uvalue(obj)^.metatable;
  else
    mt := L^.l_G^.mt[obj^.tt];
  end;
  if mt = nil then
    Result := 0
  else
  begin
    sethvalue(L, L^.top, mt);
    api_incr_top(L);
    Result := 1;
  end;
end;

procedure lua_getfenv(L: Plua_State; idx: Integer); cdecl;
var o: StkId;
begin
  o := index2adr(L, idx);
  case o^.tt of
    LUA_TFUNCTION: sethvalue(L, L^.top, clvalue(o)^.c.env);
    LUA_TUSERDATA: sethvalue(L, L^.top, uvalue(o)^.env);
    LUA_TTHREAD: setobj(L, L^.top, gt(thvalue(o)));
  else
    setnilvalue(L^.top);
  end;
  api_incr_top(L);
end;

{ set functions (stack -> Lua) }

procedure lua_settable(L: Plua_State; idx: Integer); cdecl;
var t: StkId;
begin
  t := index2adr(L, idx);
  luaV_settable(L, t, L^.top - 2, L^.top - 1);
  Dec(L^.top, 2);  { pop index and value }
end;

procedure lua_setfield(L: Plua_State; idx: Integer; k: PAnsiChar); cdecl;
var t: StkId; key: TValue;
begin
  t := index2adr(L, idx);
  setsvalue(L, @key, luaS_new(L, k));
  luaV_settable(L, t, @key, L^.top - 1);
  Dec(L^.top);  { pop value }
end;

procedure lua_rawset(L: Plua_State; idx: Integer); cdecl;
var t: StkId;
begin
  t := index2adr(L, idx);
  setobj(L, luaH_set(L, hvalue(t), L^.top - 2), L^.top - 1);
  luaC_barriert(L, hvalue(t), L^.top - 1);
  Dec(L^.top, 2);
end;

procedure lua_rawseti(L: Plua_State; idx: Integer; n: Integer); cdecl;
var o: StkId;
begin
  o := index2adr(L, idx);
  setobj(L, luaH_setnum(L, hvalue(o), n), L^.top - 1);
  luaC_barriert(L, hvalue(o), L^.top - 1);
  Dec(L^.top);
end;

function lua_setmetatable(L: Plua_State; objindex: Integer): Integer; cdecl;
var obj: PTValue; mt: PTable;
begin
  obj := index2adr(L, objindex);
  if ttisnil(L^.top - 1) then
    mt := nil
  else
    mt := hvalue(L^.top - 1);
  case obj^.tt of
    LUA_TTABLE:
      begin
        hvalue(obj)^.metatable := mt;
        if mt <> nil then
          luaC_objbarriert(L, hvalue(obj), mt);
      end;
    LUA_TUSERDATA:
      begin
        uvalue(obj)^.metatable := mt;
        if mt <> nil then
          luaC_objbarrier(L, rawuvalue(obj), mt);
      end;
  else
    L^.l_G^.mt[obj^.tt] := mt;
  end;
  Dec(L^.top);
  Result := 1;
end;

function lua_setfenv(L: Plua_State; idx: Integer): Integer; cdecl;
var o: StkId; res: Integer;
begin
  res := 1;
  o := index2adr(L, idx);
  case o^.tt of
    LUA_TFUNCTION: clvalue(o)^.c.env := hvalue(L^.top - 1);
    LUA_TUSERDATA: uvalue(o)^.env := hvalue(L^.top - 1);
    LUA_TTHREAD: sethvalue(L, gt(thvalue(o)), hvalue(L^.top - 1));
  else
    res := 0;
  end;
  if res <> 0 then luaC_objbarrier(L, gcvalue(o), hvalue(L^.top - 1));
  Dec(L^.top);
  Result := res;
end;

{ `load' and `call' functions (run Lua code) }

procedure adjustresults(L: Plua_State; nres: Integer); inline;
begin
  if (nres = LUA_MULTRET) and (PAnsiChar(L^.top) >= PAnsiChar(L^.ci^.top)) then
    L^.ci^.top := L^.top;
end;

procedure lua_call(L: Plua_State; nargs, nresults: Integer); cdecl;
var func: StkId;
begin
  func := L^.top - (nargs + 1);
  luaD_call(L, func, nresults);
  adjustresults(L, nresults);
end;

{ Execute a protected call. }
type
  PCallS = ^TCallS;
  TCallS = record  { data to `f_call' }
    func: StkId;
    nresults: Integer;
  end;

procedure f_call(L: Plua_State; ud: Pointer);
var c: PCallS;
begin
  c := PCallS(ud);
  luaD_call(L, c^.func, c^.nresults);
end;

function lua_pcall(L: Plua_State; nargs, nresults, errfunc: Integer): Integer; cdecl;
var c: TCallS; status: Integer; func: ptrdiff_t; o: StkId;
begin
  if errfunc = 0 then
    func := 0
  else
  begin
    o := index2adr(L, errfunc);
    func := savestack(L, o);
  end;
  c.func := L^.top - (nargs + 1);  { function to be called }
  c.nresults := nresults;
  status := luaD_pcall(L, f_call, @c, savestack(L, c.func), func);
  adjustresults(L, nresults);
  Result := status;
end;

{ Execute a protected C call. }
type
  PCCallS = ^TCCallS;
  TCCallS = record  { data to `f_Ccall' }
    func: lua_CFunction;
    ud: Pointer;
  end;

procedure f_Ccall(L: Plua_State; ud: Pointer);
var c: PCCallS; cl: PClosure;
begin
  c := PCCallS(ud);
  cl := luaF_newCclosure(L, 0, getcurrenv(L));
  cl^.c.f := c^.func;
  setclvalue(L, L^.top, cl);  { push function }
  api_incr_top(L);
  setpvalue(L^.top, c^.ud);  { push only argument }
  api_incr_top(L);
  luaD_call(L, L^.top - 2, 0);
end;

function lua_cpcall(L: Plua_State; func: lua_CFunction; ud: Pointer): Integer; cdecl;
var c: TCCallS;
begin
  c.func := func;
  c.ud := ud;
  Result := luaD_pcall(L, f_Ccall, @c, savestack(L, L^.top), 0);
end;

function lua_load(L: Plua_State; reader: lua_Reader; data: Pointer; chunkname: PAnsiChar): Integer; cdecl;
var z: TZIO;
begin
  if chunkname = nil then chunkname := '?';
  luaZ_init(L, @z, reader, data);
  Result := luaD_protectedparser(L, @z, chunkname);
end;

function lua_dump(L: Plua_State; writer: lua_Writer; data: Pointer): Integer; cdecl;
var o: PTValue;
begin
  o := L^.top - 1;
  if isLfunction(o) then
    Result := luaU_dump(L, clvalue(o)^.l.p, writer, data, 0)
  else
    Result := 1;
end;

function lua_status(L: Plua_State): Integer; cdecl;
begin
  Result := L^.status;
end;

{ Garbage-collection function }

function lua_gc(L: Plua_State; what, data: Integer): Integer; cdecl;
var res: Integer; g: Pglobal_State; a: lu_mem;
begin
  res := 0;
  g := L^.l_G;
  case what of
    LUA_GCSTOP:
      g^.GCthreshold := MAX_LUMEM;
    LUA_GCRESTART:
      g^.GCthreshold := g^.totalbytes;
    LUA_GCCOLLECT:
      luaC_fullgc(L);
    LUA_GCCOUNT:
      { GC values are expressed in Kbytes: #bytes/2^10 }
      res := Integer(g^.totalbytes shr 10);
    LUA_GCCOUNTB:
      res := Integer(g^.totalbytes and $3ff);
    LUA_GCSTEP:
      begin
        a := lu_mem(NativeUInt(NativeInt(data))) shl 10;
        if a <= g^.totalbytes then
          g^.GCthreshold := g^.totalbytes - a
        else
          g^.GCthreshold := 0;
        while g^.GCthreshold <= g^.totalbytes do
        begin
          luaC_step(L);
          if g^.gcstate = GCSpause then
          begin  { end of cycle? }
            res := 1;  { signal it }
            Break;
          end;
        end;
      end;
    LUA_GCSETPAUSE:
      begin
        res := g^.gcpause;
        g^.gcpause := data;
      end;
    LUA_GCSETSTEPMUL:
      begin
        res := g^.gcstepmul;
        g^.gcstepmul := data;
      end;
  else
    res := -1;  { invalid option }
  end;
  Result := res;
end;

{ miscellaneous functions }

function lua_error(L: Plua_State): Integer; cdecl;
begin
  luaG_errormsg(L);
  Result := 0;  { to avoid warnings }
end;

function lua_next(L: Plua_State; idx: Integer): Integer; cdecl;
var t: StkId; more: Integer;
begin
  t := index2adr(L, idx);
  more := luaH_next(L, hvalue(t), L^.top - 1);
  if more <> 0 then
    api_incr_top(L)
  else  { no more elements }
    Dec(L^.top);  { remove key }
  Result := more;
end;

procedure lua_concat(L: Plua_State; n: Integer); cdecl;
begin
  if n >= 2 then
  begin
    luaC_checkGC(L);
    luaV_concat(L, n, StkDiff(L^.top, L^.base) - 1);
    Dec(L^.top, n - 1);
  end
  else if n = 0 then
  begin  { push empty string }
    setsvalue(L, L^.top, luaS_newlstr(L, '', 0));
    api_incr_top(L);
  end;
  { else n == 1; nothing to do }
end;

function lua_getallocf(L: Plua_State; ud: PPointer): lua_Alloc; cdecl;
begin
  if ud <> nil then ud^ := L^.l_G^.ud;
  Result := L^.l_G^.frealloc;
end;

procedure lua_setallocf(L: Plua_State; f: lua_Alloc; ud: Pointer); cdecl;
begin
  L^.l_G^.ud := ud;
  L^.l_G^.frealloc := f;
end;

function lua_newuserdata(L: Plua_State; size: size_t): Pointer; cdecl;
var u: PUdata;
begin
  luaC_checkGC(L);
  u := luaS_newudata(L, size, getcurrenv(L));
  setuvalue(L, L^.top, u);
  api_incr_top(L);
  Result := PAnsiChar(u) + UDATA_SIZE;
end;

function aux_upvalue(fi: StkId; n: Integer; var val: PTValue): PAnsiChar;
var f: PClosure; p: PProto;
begin
  if not ttisfunction(fi) then Exit(nil);
  f := clvalue(fi);
  if f^.c.isC <> 0 then
  begin
    if not ((1 <= n) and (n <= f^.c.nupvalues)) then Exit(nil);
    val := @PTValue(@f^.c.upvalue)[n - 1];
    Result := '';
  end
  else
  begin
    p := f^.l.p;
    if not ((1 <= n) and (n <= p^.sizeupvalues)) then Exit(nil);
    val := PPUpVal(@f^.l.upvals)[n - 1]^.v;
    Result := getstr(p^.upvalues[n - 1]);
  end;
end;

function lua_getupvalue(L: Plua_State; funcindex, n: Integer): PAnsiChar; cdecl;
var name: PAnsiChar; val: PTValue;
begin
  val := nil;
  name := aux_upvalue(index2adr(L, funcindex), n, val);
  if name <> nil then
  begin
    setobj(L, L^.top, val);
    api_incr_top(L);
  end;
  Result := name;
end;

function lua_setupvalue(L: Plua_State; funcindex, n: Integer): PAnsiChar; cdecl;
var name: PAnsiChar; val: PTValue; fi: StkId;
begin
  val := nil;
  fi := index2adr(L, funcindex);
  name := aux_upvalue(fi, n, val);
  if name <> nil then
  begin
    Dec(L^.top);
    setobj(L, val, L^.top);
    luaC_barrier(L, clvalue(fi), L^.top);
  end;
  Result := name;
end;

{ ---- macros ---- }

procedure lua_pop(L: Plua_State; n: Integer); begin lua_settop(L, -n - 1); end;
procedure lua_newtable(L: Plua_State); begin lua_createtable(L, 0, 0); end;
procedure lua_pushcfunction(L: Plua_State; f: lua_CFunction); begin lua_pushcclosure(L, f, 0); end;
procedure lua_register(L: Plua_State; n: PAnsiChar; f: lua_CFunction);
begin
  lua_pushcfunction(L, f);
  lua_setglobal(L, n);
end;
function lua_isfunction(L: Plua_State; n: Integer): Boolean; begin Result := lua_type(L, n) = LUA_TFUNCTION; end;
function lua_istable(L: Plua_State; n: Integer): Boolean; begin Result := lua_type(L, n) = LUA_TTABLE; end;
function lua_islightuserdata(L: Plua_State; n: Integer): Boolean; begin Result := lua_type(L, n) = LUA_TLIGHTUSERDATA; end;
function lua_isnil(L: Plua_State; n: Integer): Boolean; begin Result := lua_type(L, n) = LUA_TNIL; end;
function lua_isboolean(L: Plua_State; n: Integer): Boolean; begin Result := lua_type(L, n) = LUA_TBOOLEAN; end;
function lua_isthread(L: Plua_State; n: Integer): Boolean; begin Result := lua_type(L, n) = LUA_TTHREAD; end;
function lua_isnone(L: Plua_State; n: Integer): Boolean; begin Result := lua_type(L, n) = LUA_TNONE; end;
function lua_isnoneornil(L: Plua_State; n: Integer): Boolean; begin Result := lua_type(L, n) <= 0; end;
procedure lua_pushliteral(L: Plua_State; const s: AnsiString); begin lua_pushlstring(L, PAnsiChar(s), Length(s)); end;
procedure lua_setglobal(L: Plua_State; s: PAnsiChar); begin lua_setfield(L, LUA_GLOBALSINDEX, s); end;
procedure lua_getglobal(L: Plua_State; s: PAnsiChar); begin lua_getfield(L, LUA_GLOBALSINDEX, s); end;
function lua_tostring(L: Plua_State; i: Integer): PAnsiChar; begin Result := lua_tolstring(L, i, nil); end;
function lua_upvalueindex(i: Integer): Integer; begin Result := LUA_GLOBALSINDEX - i; end;

end.
