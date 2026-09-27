{
  Lua 5.1.4 - Pascal port of lundump.c
  load precompiled Lua chunks
}
unit LuaUndump;

{$I lua.inc}

interface

uses
  LuaTypes;

const
  LUAC_VERSION = $51;
  LUAC_FORMAT = 0;
  LUAC_HEADERSIZE = 12;

function luaU_undump(L: Plua_State; Z: PZIO; buff: PMbuffer; name: PAnsiChar): PProto;
procedure luaU_header(h: PAnsiChar);

implementation

uses
  LuaCRT, LuaObject, LuaMem, LuaString, LuaFunc, LuaDo, LuaDebug, LuaZIO;

type
  PLoadState = ^TLoadState;
  TLoadState = record
    L: Plua_State;
    Z: PZIO;
    b: PMbuffer;
    name: PAnsiChar;
  end;

procedure error_(S: PLoadState; why: PAnsiChar);
begin
  luaO_pushfstring(S^.L, '%s: %s in precompiled chunk', [S^.name, why]);
  luaD_throw(S^.L, LUA_ERRSYNTAX);
end;

procedure LoadBlock(S: PLoadState; b: Pointer; size: size_t);
var r: size_t;
begin
  r := luaZ_read(S^.Z, b, size);
  if r <> 0 then error_(S, 'unexpected end');
end;

function LoadChar(S: PLoadState): Integer;
var x: ShortInt;
begin
  LoadBlock(S, @x, 1);
  Result := x;
end;

function LoadByte(S: PLoadState): lu_byte;
begin
  Result := lu_byte(LoadChar(S));
end;

function LoadInt(S: PLoadState): Integer;
var x: Integer;
begin
  LoadBlock(S, @x, SizeOf(x));
  if x < 0 then error_(S, 'bad integer');
  Result := x;
end;

function LoadNumber(S: PLoadState): lua_Number;
var x: lua_Number;
begin
  LoadBlock(S, @x, SizeOf(x));
  Result := x;
end;

function LoadString(S: PLoadState): PTString;
var size: size_t; s_: PAnsiChar;
begin
  LoadBlock(S, @size, SizeOf(size));
  if size = 0 then
    Result := nil
  else
  begin
    s_ := luaZ_openspace(S^.L, S^.b, size);
    LoadBlock(S, s_, size);
    Result := luaS_newlstr(S^.L, s_, size - 1);  { remove trailing '\0' }
  end;
end;

procedure LoadCode(S: PLoadState; f: PProto);
var n: Integer;
begin
  n := LoadInt(S);
  f^.code := luaM_newvector(S^.L, n, SizeOf(Instruction));
  f^.sizecode := n;
  LoadBlock(S, f^.code, size_t(n) * SizeOf(Instruction));
end;

function LoadFunction(S: PLoadState; p: PTString): PProto; forward;

procedure LoadConstants(S: PLoadState; f: PProto);
var i, n, t: Integer; o: PTValue;
begin
  n := LoadInt(S);
  f^.k := luaM_newvector(S^.L, n, SizeOf(TValue));
  f^.sizek := n;
  for i := 0 to n - 1 do setnilvalue(@f^.k[i]);
  for i := 0 to n - 1 do
  begin
    o := @f^.k[i];
    t := LoadChar(S);
    case t of
      LUA_TNIL: setnilvalue(o);
      LUA_TBOOLEAN: setbvalue(o, Ord(LoadChar(S) <> 0));
      LUA_TNUMBER: setnvalue(o, LoadNumber(S));
      LUA_TSTRING: setsvalue(S^.L, o, LoadString(S));
    else
      error_(S, 'bad constant');
    end;
  end;
  n := LoadInt(S);
  f^.p := luaM_newvector(S^.L, n, SizeOf(PProto));
  f^.sizep := n;
  for i := 0 to n - 1 do f^.p[i] := nil;
  for i := 0 to n - 1 do f^.p[i] := LoadFunction(S, f^.source);
end;

procedure LoadDebug(S: PLoadState; f: PProto);
var i, n: Integer;
begin
  n := LoadInt(S);
  f^.lineinfo := luaM_newvector(S^.L, n, SizeOf(Integer));
  f^.sizelineinfo := n;
  LoadBlock(S, f^.lineinfo, size_t(n) * SizeOf(Integer));
  n := LoadInt(S);
  f^.locvars := luaM_newvector(S^.L, n, SizeOf(TLocVar));
  f^.sizelocvars := n;
  for i := 0 to n - 1 do f^.locvars[i].varname := nil;
  for i := 0 to n - 1 do
  begin
    f^.locvars[i].varname := LoadString(S);
    f^.locvars[i].startpc := LoadInt(S);
    f^.locvars[i].endpc := LoadInt(S);
  end;
  n := LoadInt(S);
  f^.upvalues := luaM_newvector(S^.L, n, SizeOf(PTString));
  f^.sizeupvalues := n;
  for i := 0 to n - 1 do f^.upvalues[i] := nil;
  for i := 0 to n - 1 do f^.upvalues[i] := LoadString(S);
end;

function LoadFunction(S: PLoadState; p: PTString): PProto;
var f: PProto;
begin
  Inc(S^.L^.nCcalls);
  if S^.L^.nCcalls > LUAI_MAXCCALLS then error_(S, 'code too deep');
  f := luaF_newproto(S^.L);
  setptvalue(S^.L, S^.L^.top, f);
  incr_top(S^.L);
  f^.source := LoadString(S);
  if f^.source = nil then f^.source := p;
  f^.linedefined := LoadInt(S);
  f^.lastlinedefined := LoadInt(S);
  f^.nups := LoadByte(S);
  f^.numparams := LoadByte(S);
  f^.is_vararg := LoadByte(S);
  f^.maxstacksize := LoadByte(S);
  LoadCode(S, f);
  LoadConstants(S, f);
  LoadDebug(S, f);
  if luaG_checkcode(f) = 0 then error_(S, 'bad code');
  Dec(S^.L^.top);
  Dec(S^.L^.nCcalls);
  Result := f;
end;

procedure LoadHeader(S: PLoadState);
var h, s_: array[0..LUAC_HEADERSIZE - 1] of AnsiChar;
begin
  luaU_header(@h[0]);
  LoadBlock(S, @s_[0], LUAC_HEADERSIZE);
  if c_memcmp(@h[0], @s_[0], LUAC_HEADERSIZE) <> 0 then error_(S, 'bad header');
end;

{ load precompiled chunk }
function luaU_undump(L: Plua_State; Z: PZIO; buff: PMbuffer; name: PAnsiChar): PProto;
var S: TLoadState;
begin
  if (name^ = '@') or (name^ = '=') then
    S.name := name + 1
  else if name^ = LUA_SIGNATURE_CHAR then
    S.name := 'binary string'
  else
    S.name := name;
  S.L := L;
  S.Z := Z;
  S.b := buff;
  LoadHeader(@S);
  Result := LoadFunction(@S, luaS_newliteral(L, '=?'));
end;

{ make header }
procedure luaU_header(h: PAnsiChar);
begin
  Move(PAnsiChar(LUA_SIGNATURE)^, h^, Length(LUA_SIGNATURE));
  Inc(h, Length(LUA_SIGNATURE));
  h^ := AnsiChar(LUAC_VERSION); Inc(h);
  h^ := AnsiChar(LUAC_FORMAT); Inc(h);
  h^ := AnsiChar(1); Inc(h);                        { endianness: little }
  h^ := AnsiChar(SizeOf(Integer)); Inc(h);
  h^ := AnsiChar(SizeOf(size_t)); Inc(h);
  h^ := AnsiChar(SizeOf(Instruction)); Inc(h);
  h^ := AnsiChar(SizeOf(lua_Number)); Inc(h);
  h^ := AnsiChar(0);                                { not an integral lua_Number }
end;

end.
