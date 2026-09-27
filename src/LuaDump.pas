{
  Lua 5.1.4 - Pascal port of ldump.c
  save precompiled Lua chunks
}
unit LuaDump;

{$I lua.inc}

interface

uses
  LuaTypes;

function luaU_dump(L: Plua_State; f: PProto; w: lua_Writer; data: Pointer; strip: Integer): Integer;

implementation

uses
  LuaUndump;

type
  PDumpState = ^TDumpState;
  TDumpState = record
    L: Plua_State;
    writer: lua_Writer;
    data: Pointer;
    strip: Integer;
    status: Integer;
  end;

procedure DumpBlock(b: Pointer; size: size_t; D: PDumpState);
begin
  if D^.status = 0 then
    D^.status := D^.writer(D^.L, b, size, D^.data);
end;

procedure DumpChar(y: Integer; D: PDumpState);
var x: AnsiChar;
begin
  x := AnsiChar(Byte(y));
  DumpBlock(@x, 1, D);
end;

procedure DumpInt(x: Integer; D: PDumpState);
begin
  DumpBlock(@x, SizeOf(x), D);
end;

procedure DumpNumber(x: lua_Number; D: PDumpState);
begin
  DumpBlock(@x, SizeOf(x), D);
end;

procedure DumpVector(b: Pointer; n: Integer; size: size_t; D: PDumpState);
begin
  DumpInt(n, D);
  DumpBlock(b, size_t(n) * size, D);
end;

procedure DumpString(s: PTString; D: PDumpState);
var size: size_t;
begin
  if s = nil then
  begin
    size := 0;
    DumpBlock(@size, SizeOf(size), D);
  end
  else
  begin
    size := s^.len + 1;  { include trailing '\0' }
    DumpBlock(@size, SizeOf(size), D);
    DumpBlock(getstr(s), size, D);
  end;
end;

procedure DumpFunction(f: PProto; p: PTString; D: PDumpState); forward;

procedure DumpConstants(f: PProto; D: PDumpState);
var i, n: Integer; o: PTValue;
begin
  n := f^.sizek;
  DumpInt(n, D);
  for i := 0 to n - 1 do
  begin
    o := @f^.k[i];
    DumpChar(o^.tt, D);
    case o^.tt of
      LUA_TNIL: ;
      LUA_TBOOLEAN: DumpChar(bvalue(o), D);
      LUA_TNUMBER: DumpNumber(nvalue(o), D);
      LUA_TSTRING: DumpString(rawtsvalue(o), D);
    end;
  end;
  n := f^.sizep;
  DumpInt(n, D);
  for i := 0 to n - 1 do DumpFunction(f^.p[i], f^.source, D);
end;

procedure DumpDebug(f: PProto; D: PDumpState);
var i, n: Integer;
begin
  if D^.strip <> 0 then n := 0 else n := f^.sizelineinfo;
  DumpVector(f^.lineinfo, n, SizeOf(Integer), D);
  if D^.strip <> 0 then n := 0 else n := f^.sizelocvars;
  DumpInt(n, D);
  for i := 0 to n - 1 do
  begin
    DumpString(f^.locvars[i].varname, D);
    DumpInt(f^.locvars[i].startpc, D);
    DumpInt(f^.locvars[i].endpc, D);
  end;
  if D^.strip <> 0 then n := 0 else n := f^.sizeupvalues;
  DumpInt(n, D);
  for i := 0 to n - 1 do DumpString(f^.upvalues[i], D);
end;

procedure DumpFunction(f: PProto; p: PTString; D: PDumpState);
begin
  if (f^.source = p) or (D^.strip <> 0) then DumpString(nil, D)
  else DumpString(f^.source, D);
  DumpInt(f^.linedefined, D);
  DumpInt(f^.lastlinedefined, D);
  DumpChar(f^.nups, D);
  DumpChar(f^.numparams, D);
  DumpChar(f^.is_vararg, D);
  DumpChar(f^.maxstacksize, D);
  DumpVector(f^.code, f^.sizecode, SizeOf(Instruction), D);
  DumpConstants(f, D);
  DumpDebug(f, D);
end;

procedure DumpHeader(D: PDumpState);
var h: array[0..LUAC_HEADERSIZE - 1] of AnsiChar;
begin
  luaU_header(@h[0]);
  DumpBlock(@h[0], LUAC_HEADERSIZE, D);
end;

{ dump Lua function as precompiled chunk }
function luaU_dump(L: Plua_State; f: PProto; w: lua_Writer; data: Pointer; strip: Integer): Integer;
var D: TDumpState;
begin
  D.L := L;
  D.writer := w;
  D.data := data;
  D.strip := strip;
  D.status := 0;
  DumpHeader(@D);
  DumpFunction(f, nil, @D);
  Result := D.status;
end;

end.
