{
  Lua 5.1.4 - Pascal port of lauxlib.c
  Auxiliary functions for building Lua libraries
}
unit LuaAuxLib;

{$I lua.inc}

interface

uses
  LuaTypes;

function luaL_argerror(L: Plua_State; narg: Integer; extramsg: PAnsiChar): Integer; cdecl;
function luaL_typerror(L: Plua_State; narg: Integer; tname: PAnsiChar): Integer; cdecl;
procedure luaL_where(L: Plua_State; level: Integer); cdecl;
{ C varargs: int luaL_error(lua_State *L, const char *fmt, ...) }
function luaL_error(L: Plua_State; fmt: PAnsiChar): Integer; cdecl;
function luaL_checkoption(L: Plua_State; narg: Integer; def: PAnsiChar; lst: PPAnsiChar): Integer; cdecl;
function luaL_newmetatable(L: Plua_State; tname: PAnsiChar): Integer; cdecl;
function luaL_checkudata(L: Plua_State; ud: Integer; tname: PAnsiChar): Pointer; cdecl;
procedure luaL_checkstack(L: Plua_State; space: Integer; mes: PAnsiChar); cdecl;
procedure luaL_checktype(L: Plua_State; narg: Integer; t: Integer); cdecl;
procedure luaL_checkany(L: Plua_State; narg: Integer); cdecl;
function luaL_checklstring(L: Plua_State; narg: Integer; len: Psize_t): PAnsiChar; cdecl;
function luaL_optlstring(L: Plua_State; narg: Integer; def: PAnsiChar; len: Psize_t): PAnsiChar; cdecl;
function luaL_checknumber(L: Plua_State; narg: Integer): lua_Number; cdecl;
function luaL_optnumber(L: Plua_State; narg: Integer; def: lua_Number): lua_Number; cdecl;
function luaL_checkinteger(L: Plua_State; narg: Integer): lua_Integer; cdecl;
function luaL_optinteger(L: Plua_State; narg: Integer; def: lua_Integer): lua_Integer; cdecl;
function luaL_getmetafield(L: Plua_State; obj: Integer; event: PAnsiChar): Integer; cdecl;
function luaL_callmeta(L: Plua_State; obj: Integer; event: PAnsiChar): Integer; cdecl;
procedure luaL_register(L: Plua_State; libname: PAnsiChar; l_: PluaL_Reg); cdecl;
procedure luaL_openlib(L: Plua_State; libname: PAnsiChar; l_: PluaL_Reg; nup: Integer); cdecl;
function luaL_gsub(L: Plua_State; s, p, r: PAnsiChar): PAnsiChar; cdecl;
function luaL_findtable(L: Plua_State; idx: Integer; fname: PAnsiChar; szhint: Integer): PAnsiChar; cdecl;
procedure luaL_buffinit(L: Plua_State; B: PluaL_Buffer); cdecl;
function luaL_prepbuffer(B: PluaL_Buffer): PAnsiChar; cdecl;
procedure luaL_addlstring(B: PluaL_Buffer; s: PAnsiChar; len: size_t); cdecl;
procedure luaL_addstring(B: PluaL_Buffer; s: PAnsiChar); cdecl;
procedure luaL_addvalue(B: PluaL_Buffer); cdecl;
procedure luaL_pushresult(B: PluaL_Buffer); cdecl;
function luaL_ref(L: Plua_State; t: Integer): Integer; cdecl;
procedure luaL_unref(L: Plua_State; t: Integer; ref: Integer); cdecl;
function luaL_loadfile(L: Plua_State; filename: PAnsiChar): Integer; cdecl;
function luaL_loadbuffer(L: Plua_State; buff: PAnsiChar; size: size_t; name: PAnsiChar): Integer; cdecl;
function luaL_loadstring(L: Plua_State; s: PAnsiChar): Integer; cdecl;
function luaL_newstate: Plua_State; cdecl;

{ Pascal-side helpers (formatted with an open array instead of C varargs) }
function luaL_errorf(L: Plua_State; fmt: PAnsiChar; const args: array of const): Integer;
function lua_pushfstringf(L: Plua_State; fmt: PAnsiChar; const args: array of const): PAnsiChar;

{ lauxlib.h macros }
procedure luaL_argcheck(L: Plua_State; cond: Boolean; numarg: Integer; extramsg: PAnsiChar); inline;
function luaL_checkstring(L: Plua_State; n: Integer): PAnsiChar; inline;
function luaL_optstring(L: Plua_State; n: Integer; d: PAnsiChar): PAnsiChar; inline;
function luaL_checkint(L: Plua_State; n: Integer): Integer; inline;
function luaL_optint(L: Plua_State; n: Integer; d: Integer): Integer; inline;
function luaL_checklong(L: Plua_State; n: Integer): c_long; inline;
function luaL_optlong(L: Plua_State; n: Integer; d: c_long): c_long; inline;
function luaL_typename(L: Plua_State; i: Integer): PAnsiChar; inline;
function luaL_dofile(L: Plua_State; fn: PAnsiChar): Integer; inline;
function luaL_dostring(L: Plua_State; s: PAnsiChar): Integer; inline;
procedure luaL_getmetatable(L: Plua_State; n: PAnsiChar); inline;
procedure luaL_addchar(B: PluaL_Buffer; c: AnsiChar); inline;
procedure luaL_addsize(B: PluaL_Buffer; n: size_t); inline;
function luaL_getn(L: Plua_State; i: Integer): Integer; inline;

implementation

uses
  LuaCRT, LuaAPI, LuaState, LuaDebug, LuaDo, LuaObject, LuaGC, LuaStdio,
  {$IFDEF LUA_POSIX} LuaPosix {$ELSE} LuaWin {$ENDIF};

const
  FREELIST_REF = 0;  { free list of references }

function abs_index(L: Plua_State; i: Integer): Integer; inline;
begin
  if (i > 0) or (i <= LUA_REGISTRYINDEX) then Result := i
  else Result := lua_gettop(L) + i + 1;
end;

{ =======================================================
  Error-report functions
  ======================================================= }

function lua_pushfstringf(L: Plua_State; fmt: PAnsiChar; const args: array of const): PAnsiChar;
begin
  luaC_checkGC(L);
  Result := luaO_pushfstring(L, fmt, args);
end;

function luaL_errorf(L: Plua_State; fmt: PAnsiChar; const args: array of const): Integer;
begin
  luaL_where(L, 1);
  lua_pushfstringf(L, fmt, args);
  lua_concat(L, 2);
  Result := lua_error(L);
end;

function luaL_argerror(L: Plua_State; narg: Integer; extramsg: PAnsiChar): Integer; cdecl;
var ar: lua_Debug;
begin
  if lua_getstack(L, 0, @ar) = 0 then  { no stack frame? }
    Exit(luaL_errorf(L, 'bad argument #%d (%s)', [narg, extramsg]));
  lua_getinfo(L, 'n', @ar);
  if c_strcmp(ar.namewhat, 'method') = 0 then
  begin
    Dec(narg);  { do not count `self' }
    if narg = 0 then  { error is in the self argument itself? }
      Exit(luaL_errorf(L, 'calling ''%s'' on bad self (%s)', [ar.name, extramsg]));
  end;
  if ar.name = nil then
    ar.name := '?';
  Result := luaL_errorf(L, 'bad argument #%d to ''%s'' (%s)', [narg, ar.name, extramsg]);
end;

function luaL_typerror(L: Plua_State; narg: Integer; tname: PAnsiChar): Integer; cdecl;
var msg: PAnsiChar;
begin
  msg := lua_pushfstringf(L, '%s expected, got %s', [tname, luaL_typename(L, narg)]);
  Result := luaL_argerror(L, narg, msg);
end;

procedure tag_error(L: Plua_State; narg, tag: Integer);
begin
  luaL_typerror(L, narg, lua_typename(L, tag));
end;

procedure luaL_where(L: Plua_State; level: Integer); cdecl;
var ar: lua_Debug;
begin
  if lua_getstack(L, level, @ar) <> 0 then
  begin  { check function at level }
    lua_getinfo(L, 'Sl', @ar);  { get info about it }
    if ar.currentline > 0 then
    begin  { is there info? }
      lua_pushfstringf(L, '%s:%d: ', [PAnsiChar(@ar.short_src[0]), ar.currentline]);
      Exit;
    end;
  end;
  lua_pushlstring(L, '', 0);  { else, no information available... }
end;

function luaL_verror(L: Plua_State; fmt: PAnsiChar; argp: Pointer): Integer; cdecl;
begin
  luaL_where(L, 1);
  lua_pushvfstring(L, fmt, argp);
  lua_concat(L, 2);
  Result := lua_error(L);
end;

{$IFDEF LUA_POSIX}
{$IF defined(CPUAARCH64) and defined(DARWIN)}
{ Apple ARM64: variadic arguments are passed on the stack in 8-byte slots,
  so the va_list is simply the stack pointer at entry. }
function luaL_error(L: Plua_State; fmt: PAnsiChar): Integer; cdecl;
  assembler; nostackframe;
asm
  mov x2, sp
  b luaL_verror
end;
{$ELSE}
{$IFDEF CPUAARCH64}
{ AArch64 (AAPCS64) varargs: save x0-x7 and d0-d7 (in 16-byte slots, as for
  q0-q7) in register save areas,
  build a va_list (__stack, __gr_top, __vr_top, __gr_offs, __vr_offs)
  (offsets -48 and -128 skip the two named arguments / start at q0) and
  call the va_list version (va_list is passed by reference). }
function luaL_error(L: Plua_State; fmt: PAnsiChar): Integer; cdecl;
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
  bl luaL_verror
  mov sp, x29
  ldp x29, x30, [sp], #16
  ret
end;
{$ELSE}
{ System V x86-64 varargs: store the argument registers in a register save
  area, build a va_list (gp_offset 16 and fp_offset 48 skip the named
  arguments), and call the va_list version. }
function luaL_error(L: Plua_State; fmt: PAnsiChar): Integer; cdecl;
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
  call luaL_verror
  add rsp, 216
  ret
end;
{$ENDIF}
{$IFEND}
{$ELSE}
{$IFDEF LUA_64}
function luaL_error(L: Plua_State; fmt: PAnsiChar): Integer; cdecl;
  {$IFDEF FPC} assembler; nostackframe; {$ENDIF}
asm
  {$IFNDEF FPC} .NOFRAME {$ENDIF}
  mov [rsp+24], r8
  mov [rsp+32], r9
  lea r8, [rsp+24]
  jmp luaL_verror
end;
{$ELSE}
function luaL_error(L: Plua_State; fmt: PAnsiChar): Integer; cdecl;
begin
  Result := luaL_verror(L, fmt, PAnsiChar(@fmt) + SizeOf(Pointer));
end;
{$ENDIF}
{$ENDIF}

function luaL_checkoption(L: Plua_State; narg: Integer; def: PAnsiChar; lst: PPAnsiChar): Integer; cdecl;
var name: PAnsiChar; i: Integer;
begin
  if def <> nil then name := luaL_optstring(L, narg, def)
  else name := luaL_checkstring(L, narg);
  i := 0;
  while lst[i] <> nil do
  begin
    if c_strcmp(lst[i], name) = 0 then
      Exit(i);
    Inc(i);
  end;
  Result := luaL_argerror(L, narg, lua_pushfstringf(L, 'invalid option ''%s''', [name]));
end;

function luaL_newmetatable(L: Plua_State; tname: PAnsiChar): Integer; cdecl;
begin
  lua_getfield(L, LUA_REGISTRYINDEX, tname);  { get registry.name }
  if not lua_isnil(L, -1) then  { name already in use? }
    Exit(0);  { leave previous value on top, but return 0 }
  lua_pop(L, 1);
  lua_newtable(L);  { create metatable }
  lua_pushvalue(L, -1);
  lua_setfield(L, LUA_REGISTRYINDEX, tname);  { registry.name = metatable }
  Result := 1;
end;

function luaL_checkudata(L: Plua_State; ud: Integer; tname: PAnsiChar): Pointer; cdecl;
var p: Pointer;
begin
  p := lua_touserdata(L, ud);
  if p <> nil then
  begin  { value is a userdata? }
    if lua_getmetatable(L, ud) <> 0 then
    begin  { does it have a metatable? }
      lua_getfield(L, LUA_REGISTRYINDEX, tname);  { get correct metatable }
      if lua_rawequal(L, -1, -2) <> 0 then
      begin  { does it have the correct mt? }
        lua_pop(L, 2);  { remove both metatables }
        Exit(p);
      end;
    end;
  end;
  luaL_typerror(L, ud, tname);  { else error }
  Result := nil;  { to avoid warnings }
end;

procedure luaL_checkstack(L: Plua_State; space: Integer; mes: PAnsiChar); cdecl;
begin
  if lua_checkstack(L, space) = 0 then
    luaL_errorf(L, 'stack overflow (%s)', [mes]);
end;

procedure luaL_checktype(L: Plua_State; narg: Integer; t: Integer); cdecl;
begin
  if lua_type(L, narg) <> t then
    tag_error(L, narg, t);
end;

procedure luaL_checkany(L: Plua_State; narg: Integer); cdecl;
begin
  if lua_type(L, narg) = LUA_TNONE then
    luaL_argerror(L, narg, 'value expected');
end;

function luaL_checklstring(L: Plua_State; narg: Integer; len: Psize_t): PAnsiChar; cdecl;
var s: PAnsiChar;
begin
  s := lua_tolstring(L, narg, len);
  if s = nil then tag_error(L, narg, LUA_TSTRING);
  Result := s;
end;

function luaL_optlstring(L: Plua_State; narg: Integer; def: PAnsiChar; len: Psize_t): PAnsiChar; cdecl;
begin
  if lua_isnoneornil(L, narg) then
  begin
    if len <> nil then
    begin
      if def <> nil then len^ := c_strlen(def) else len^ := 0;
    end;
    Result := def;
  end
  else
    Result := luaL_checklstring(L, narg, len);
end;

function luaL_checknumber(L: Plua_State; narg: Integer): lua_Number; cdecl;
var d: lua_Number;
begin
  d := lua_tonumber(L, narg);
  if luai_numeq(d, 0) and (lua_isnumber(L, narg) = 0) then  { avoid extra test when d is not 0 }
    tag_error(L, narg, LUA_TNUMBER);
  Result := d;
end;

function luaL_optnumber(L: Plua_State; narg: Integer; def: lua_Number): lua_Number; cdecl;
begin
  if lua_isnoneornil(L, narg) then Result := def
  else Result := luaL_checknumber(L, narg);
end;

function luaL_checkinteger(L: Plua_State; narg: Integer): lua_Integer; cdecl;
var d: lua_Integer;
begin
  d := lua_tointeger(L, narg);
  if (d = 0) and (lua_isnumber(L, narg) = 0) then  { avoid extra test when d is not 0 }
    tag_error(L, narg, LUA_TNUMBER);
  Result := d;
end;

function luaL_optinteger(L: Plua_State; narg: Integer; def: lua_Integer): lua_Integer; cdecl;
begin
  if lua_isnoneornil(L, narg) then Result := def
  else Result := luaL_checkinteger(L, narg);
end;

function luaL_getmetafield(L: Plua_State; obj: Integer; event: PAnsiChar): Integer; cdecl;
begin
  if lua_getmetatable(L, obj) = 0 then  { no metatable? }
    Exit(0);
  lua_pushstring(L, event);
  lua_rawget(L, -2);
  if lua_isnil(L, -1) then
  begin
    lua_pop(L, 2);  { remove metatable and metafield }
    Result := 0;
  end
  else
  begin
    lua_remove(L, -2);  { remove only metatable }
    Result := 1;
  end;
end;

function luaL_callmeta(L: Plua_State; obj: Integer; event: PAnsiChar): Integer; cdecl;
begin
  obj := abs_index(L, obj);
  if luaL_getmetafield(L, obj, event) = 0 then  { no metafield? }
    Exit(0);
  lua_pushvalue(L, obj);
  lua_call(L, 1, 1);
  Result := 1;
end;

procedure luaL_register(L: Plua_State; libname: PAnsiChar; l_: PluaL_Reg); cdecl;
begin
  luaL_openlib(L, libname, l_, 0);
end;

function libsize(l_: PluaL_Reg): Integer;
var size: Integer;
begin
  size := 0;
  while l_^.name <> nil do
  begin
    Inc(size);
    Inc(l_);
  end;
  Result := size;
end;

procedure luaL_openlib(L: Plua_State; libname: PAnsiChar; l_: PluaL_Reg; nup: Integer); cdecl;
var size, i: Integer;
begin
  if libname <> nil then
  begin
    size := libsize(l_);
    { check whether lib already exists }
    luaL_findtable(L, LUA_REGISTRYINDEX, '_LOADED', 1);
    lua_getfield(L, -1, libname);  { get _LOADED[libname] }
    if not lua_istable(L, -1) then
    begin  { not found? }
      lua_pop(L, 1);  { remove previous result }
      { try global variable (and create one if it does not exist) }
      if luaL_findtable(L, LUA_GLOBALSINDEX, libname, size) <> nil then
        luaL_errorf(L, 'name conflict for module ''%s''', [libname]);
      lua_pushvalue(L, -1);
      lua_setfield(L, -3, libname);  { _LOADED[libname] = new table }
    end;
    lua_remove(L, -2);  { remove _LOADED table }
    lua_insert(L, -(nup + 1));  { move library table to below upvalues }
  end;
  while l_^.name <> nil do
  begin
    for i := 0 to nup - 1 do  { copy upvalues to the top }
      lua_pushvalue(L, -nup);
    lua_pushcclosure(L, l_^.func, nup);
    lua_setfield(L, -(nup + 2), l_^.name);
    Inc(l_);
  end;
  lua_pop(L, nup);  { remove upvalues }
end;

function luaL_gsub(L: Plua_State; s, p, r: PAnsiChar): PAnsiChar; cdecl;
var wild: PAnsiChar; plen: size_t; b: luaL_Buffer;
begin
  plen := c_strlen(p);
  luaL_buffinit(L, @b);
  while True do
  begin
    wild := c_strstr(s, p);
    if wild = nil then Break;
    luaL_addlstring(@b, s, wild - s);  { push prefix }
    luaL_addstring(@b, r);  { push replacement in place of pattern }
    s := wild + plen;  { continue after `p' }
  end;
  luaL_addstring(@b, s);  { push last suffix }
  luaL_pushresult(@b);
  Result := lua_tostring(L, -1);
end;

function luaL_findtable(L: Plua_State; idx: Integer; fname: PAnsiChar; szhint: Integer): PAnsiChar; cdecl;
var e: PAnsiChar;
begin
  lua_pushvalue(L, idx);
  repeat
    e := c_strchr(fname, Ord('.'));
    if e = nil then e := fname + c_strlen(fname);
    lua_pushlstring(L, fname, e - fname);
    lua_rawget(L, -2);
    if lua_isnil(L, -1) then
    begin  { no such field? }
      lua_pop(L, 1);  { remove this nil }
      if e^ = '.' then lua_createtable(L, 0, 1)  { new table for field }
      else lua_createtable(L, 0, szhint);
      lua_pushlstring(L, fname, e - fname);
      lua_pushvalue(L, -2);
      lua_settable(L, -4);  { set new table into field }
    end
    else if not lua_istable(L, -1) then
    begin  { field has a non-table value? }
      lua_pop(L, 2);  { remove table and value }
      Exit(fname);  { return problematic part of the name }
    end;
    lua_remove(L, -2);  { remove previous table }
    fname := e + 1;
  until e^ <> '.';
  Result := nil;
end;

{ =======================================================
  Generic Buffer manipulation
  ======================================================= }

const
  LIMIT = LUA_MINSTACK div 2;

function bufflen(B: PluaL_Buffer): size_t; inline;
begin
  Result := size_t(B^.p - PAnsiChar(@B^.buffer[0]));
end;

function bufffree(B: PluaL_Buffer): size_t; inline;
begin
  Result := LUAL_BUFFERSIZE - bufflen(B);
end;

function emptybuffer(B: PluaL_Buffer): Boolean;
var len: size_t;
begin
  len := bufflen(B);
  if len = 0 then Exit(False)  { put nothing on stack }
  else
  begin
    lua_pushlstring(B^.L, @B^.buffer[0], len);
    B^.p := @B^.buffer[0];
    Inc(B^.lvl);
    Result := True;
  end;
end;

procedure adjuststack(B: PluaL_Buffer);
var L: Plua_State; toget: Integer; toplen, len: size_t;
begin
  if B^.lvl > 1 then
  begin
    L := B^.L;
    toget := 1;  { number of levels to concat }
    toplen := lua_objlen(L, -1);
    repeat
      len := lua_objlen(L, -(toget + 1));
      if (B^.lvl - toget + 1 >= LIMIT) or (toplen > len) then
      begin
        Inc(toplen, len);
        Inc(toget);
      end
      else
        Break;
    until toget >= B^.lvl;
    lua_concat(L, toget);
    B^.lvl := B^.lvl - toget + 1;
  end;
end;

function luaL_prepbuffer(B: PluaL_Buffer): PAnsiChar; cdecl;
begin
  if emptybuffer(B) then
    adjuststack(B);
  Result := @B^.buffer[0];
end;

procedure luaL_addchar(B: PluaL_Buffer; c: AnsiChar);
begin
  if not (B^.p < PAnsiChar(@B^.buffer[0]) + LUAL_BUFFERSIZE) then
    luaL_prepbuffer(B);
  B^.p^ := c;
  Inc(B^.p);
end;

procedure luaL_addsize(B: PluaL_Buffer; n: size_t);
begin
  Inc(B^.p, n);
end;

procedure luaL_addlstring(B: PluaL_Buffer; s: PAnsiChar; len: size_t); cdecl;
begin
  while len > 0 do
  begin
    luaL_addchar(B, s^);
    Inc(s);
    Dec(len);
  end;
end;

procedure luaL_addstring(B: PluaL_Buffer; s: PAnsiChar); cdecl;
begin
  luaL_addlstring(B, s, c_strlen(s));
end;

procedure luaL_pushresult(B: PluaL_Buffer); cdecl;
begin
  emptybuffer(B);
  lua_concat(B^.L, B^.lvl);
  B^.lvl := 1;
end;

procedure luaL_addvalue(B: PluaL_Buffer); cdecl;
var L: Plua_State; vl: size_t; s: PAnsiChar;
begin
  L := B^.L;
  s := lua_tolstring(L, -1, @vl);
  if vl <= bufffree(B) then
  begin  { fit into buffer? }
    Move(s^, B^.p^, vl);  { put it there }
    Inc(B^.p, vl);
    lua_pop(L, 1);  { remove from stack }
  end
  else
  begin
    if emptybuffer(B) then
      lua_insert(L, -2);  { put buffer before new value }
    Inc(B^.lvl);  { add new value into B stack }
    adjuststack(B);
  end;
end;

procedure luaL_buffinit(L: Plua_State; B: PluaL_Buffer); cdecl;
begin
  B^.L := L;
  B^.p := @B^.buffer[0];
  B^.lvl := 0;
end;

function luaL_ref(L: Plua_State; t: Integer): Integer; cdecl;
var ref: Integer;
begin
  t := abs_index(L, t);
  if lua_isnil(L, -1) then
  begin
    lua_pop(L, 1);  { remove from stack }
    Exit(LUA_REFNIL);  { `nil' has a unique fixed reference }
  end;
  lua_rawgeti(L, t, FREELIST_REF);  { get first free element }
  ref := Integer(lua_tointeger(L, -1));  { ref = t[FREELIST_REF] }
  lua_pop(L, 1);  { remove it from stack }
  if ref <> 0 then
  begin  { any free element? }
    lua_rawgeti(L, t, ref);  { remove it from list }
    lua_rawseti(L, t, FREELIST_REF);  { (t[FREELIST_REF] = t[ref]) }
  end
  else
  begin  { no free elements }
    ref := Integer(lua_objlen(L, t));
    Inc(ref);  { create new reference }
  end;
  lua_rawseti(L, t, ref);
  Result := ref;
end;

procedure luaL_unref(L: Plua_State; t: Integer; ref: Integer); cdecl;
begin
  if ref >= 0 then
  begin
    t := abs_index(L, t);
    lua_rawgeti(L, t, FREELIST_REF);
    lua_rawseti(L, t, ref);  { t[ref] = t[FREELIST_REF] }
    lua_pushinteger(L, ref);
    lua_rawseti(L, t, FREELIST_REF);  { t[FREELIST_REF] = ref }
  end;
end;

{ =======================================================
  Load functions
  ======================================================= }

type
  PLoadF = ^TLoadF;
  TLoadF = record
    extraline: Integer;
    f: PCFile;
    buff: array[0..LUAL_BUFFERSIZE - 1] of AnsiChar;
  end;

function getF(L: Plua_State; ud: Pointer; size: Psize_t): PAnsiChar; cdecl;
var lf: PLoadF;
begin
  lf := PLoadF(ud);
  if lf^.extraline <> 0 then
  begin
    lf^.extraline := 0;
    size^ := 1;
    Exit(#10);
  end;
  if c_feof(lf^.f) <> 0 then Exit(nil);
  size^ := c_fread(@lf^.buff[0], 1, SizeOf(lf^.buff), lf^.f);
  if size^ > 0 then Result := @lf^.buff[0] else Result := nil;
end;

function errfile(L: Plua_State; what: PAnsiChar; fnameindex: Integer): Integer;
var serr, filename: PAnsiChar;
begin
  serr := c_strerror(c_errno);
  filename := lua_tostring(L, fnameindex) + 1;
  lua_pushfstringf(L, 'cannot %s %s: %s', [what, filename, serr]);
  lua_remove(L, fnameindex);
  Result := LUA_ERRFILE;
end;

function luaL_loadfile(L: Plua_State; filename: PAnsiChar): Integer; cdecl;
var lf: TLoadF; status, readstatus, c, fnameindex: Integer;
begin
  fnameindex := lua_gettop(L) + 1;  { index of filename on the stack }
  lf.extraline := 0;
  if filename = nil then
  begin
    lua_pushlstring(L, '=stdin', 6);
    lf.f := c_stdin;
  end
  else
  begin
    lua_pushfstringf(L, '@%s', [filename]);
    lf.f := c_fopen(filename, 'r');
    if lf.f = nil then Exit(errfile(L, 'open', fnameindex));
  end;
  c := c_getc(lf.f);
  if c = Ord('#') then
  begin  { Unix exec. file? }
    lf.extraline := 1;
    repeat
      c := c_getc(lf.f);
    until (c = EOF_) or (c = 10);  { skip first line }
    if c = 10 then c := c_getc(lf.f);
  end;
  if (c = Ord(LUA_SIGNATURE_CHAR)) and (filename <> nil) then
  begin  { binary file? }
    lf.f := c_freopen(filename, 'rb', lf.f);  { reopen in binary mode }
    if lf.f = nil then Exit(errfile(L, 'reopen', fnameindex));
    { skip eventual `#!...' }
    repeat
      c := c_getc(lf.f);
    until (c = EOF_) or (c = Ord(LUA_SIGNATURE_CHAR));
    lf.extraline := 0;
  end;
  c_ungetc(c, lf.f);
  status := lua_load(L, getF, @lf, lua_tostring(L, -1));
  readstatus := c_ferror(lf.f);
  if filename <> nil then c_fclose(lf.f);  { close file (even in case of errors) }
  if readstatus <> 0 then
  begin
    lua_settop(L, fnameindex);  { ignore results from `lua_load' }
    Exit(errfile(L, 'read', fnameindex));
  end;
  lua_remove(L, fnameindex);
  Result := status;
end;

type
  PLoadS = ^TLoadS;
  TLoadS = record
    s: PAnsiChar;
    size: size_t;
  end;

function getS(L: Plua_State; ud: Pointer; size: Psize_t): PAnsiChar; cdecl;
var ls: PLoadS;
begin
  ls := PLoadS(ud);
  if ls^.size = 0 then Exit(nil);
  size^ := ls^.size;
  ls^.size := 0;
  Result := ls^.s;
end;

function luaL_loadbuffer(L: Plua_State; buff: PAnsiChar; size: size_t; name: PAnsiChar): Integer; cdecl;
var ls: TLoadS;
begin
  ls.s := buff;
  ls.size := size;
  Result := lua_load(L, getS, @ls, name);
end;

function luaL_loadstring(L: Plua_State; s: PAnsiChar): Integer; cdecl;
begin
  Result := luaL_loadbuffer(L, s, c_strlen(s), s);
end;

{$IFDEF LUA_POSIX}
function l_alloc(ud, ptr: Pointer; osize, nsize: size_t): Pointer; cdecl;
begin
  if nsize = 0 then
  begin
    px_free(ptr);
    Result := nil;
  end
  else
    Result := px_realloc(ptr, nsize);
end;
{$ELSE}
var
  heap: HANDLE = 0;

function l_alloc(ud, ptr: Pointer; osize, nsize: size_t): Pointer; cdecl;
begin
  if nsize = 0 then
  begin
    if ptr <> nil then HeapFree(heap, 0, ptr);
    Result := nil;
  end
  else if ptr = nil then
    Result := HeapAlloc(heap, 0, nsize)
  else
    Result := HeapReAlloc(heap, 0, ptr, nsize);
end;
{$ENDIF}

function panic(L: Plua_State): Integer; cdecl;
begin
  c_fputs('PANIC: unprotected error in call to Lua API (', c_stderr);
  c_fputs(lua_tostring(L, -1), c_stderr);
  c_fputs(')'#10, c_stderr);
  c_fflush(c_stderr);
  Result := 0;
end;

function luaL_newstate: Plua_State; cdecl;
var L: Plua_State;
begin
{$IFNDEF LUA_POSIX}
  if heap = 0 then heap := GetProcessHeap;
{$ENDIF}
  L := lua_newstate(l_alloc, nil);
  if L <> nil then lua_atpanic(L, panic);
  Result := L;
end;

{ ---- macros ---- }

procedure luaL_argcheck(L: Plua_State; cond: Boolean; numarg: Integer; extramsg: PAnsiChar);
begin
  if not cond then luaL_argerror(L, numarg, extramsg);
end;

function luaL_checkstring(L: Plua_State; n: Integer): PAnsiChar; begin Result := luaL_checklstring(L, n, nil); end;
function luaL_optstring(L: Plua_State; n: Integer; d: PAnsiChar): PAnsiChar; begin Result := luaL_optlstring(L, n, d, nil); end;
function luaL_checkint(L: Plua_State; n: Integer): Integer; begin Result := Integer(luaL_checkinteger(L, n)); end;
function luaL_optint(L: Plua_State; n: Integer; d: Integer): Integer; begin Result := Integer(luaL_optinteger(L, n, d)); end;
function luaL_checklong(L: Plua_State; n: Integer): c_long; begin Result := c_long(luaL_checkinteger(L, n)); end;
function luaL_optlong(L: Plua_State; n: Integer; d: c_long): c_long; begin Result := c_long(luaL_optinteger(L, n, d)); end;
function luaL_typename(L: Plua_State; i: Integer): PAnsiChar; begin Result := lua_typename(L, lua_type(L, i)); end;
function luaL_dofile(L: Plua_State; fn: PAnsiChar): Integer;
begin
  Result := luaL_loadfile(L, fn);
  if Result = 0 then Result := lua_pcall(L, 0, LUA_MULTRET, 0);
end;
function luaL_dostring(L: Plua_State; s: PAnsiChar): Integer;
begin
  Result := luaL_loadstring(L, s);
  if Result = 0 then Result := lua_pcall(L, 0, LUA_MULTRET, 0);
end;
procedure luaL_getmetatable(L: Plua_State; n: PAnsiChar); begin lua_getfield(L, LUA_REGISTRYINDEX, n); end;
function luaL_getn(L: Plua_State; i: Integer): Integer; begin Result := Integer(lua_objlen(L, i)); end;

end.
