{
  Lua 5.1.4 - Pascal port of lzio.c
  a generic input stream interface
}
unit LuaZIO;

{$I lua.inc}

interface

uses
  LuaTypes;

function luaZ_fill(z: PZIO): Integer;
function luaZ_lookahead(z: PZIO): Integer;
procedure luaZ_init(L: Plua_State; z: PZIO; reader: lua_Reader; data: Pointer);
function luaZ_read(z: PZIO; b: Pointer; n: size_t): size_t;
function luaZ_openspace(L: Plua_State; buff: PMbuffer; n: size_t): PAnsiChar;
function zgetc(z: PZIO): Integer; inline;
procedure luaZ_resizebuffer(L: Plua_State; buff: PMbuffer; size: size_t);
procedure luaZ_freebuffer(L: Plua_State; buff: PMbuffer);

implementation

uses
  LuaMem;

function luaZ_fill(z: PZIO): Integer;
var size: size_t; L: Plua_State; buff: PAnsiChar;
begin
  L := z^.L;
  buff := z^.reader(L, z^.data, @size);
  if (buff = nil) or (size = 0) then Exit(EOZ);
  z^.n := size - 1;
  z^.p := buff;
  Result := Ord(z^.p^);
  Inc(z^.p);
end;

function luaZ_lookahead(z: PZIO): Integer;
begin
  if z^.n = 0 then
  begin
    if luaZ_fill(z) = EOZ then Exit(EOZ)
    else
    begin
      Inc(z^.n);  { luaZ_fill removed first byte; put back it }
      Dec(z^.p);
    end;
  end;
  Result := Ord(z^.p^);
end;

procedure luaZ_init(L: Plua_State; z: PZIO; reader: lua_Reader; data: Pointer);
begin
  z^.L := L;
  z^.reader := reader;
  z^.data := data;
  z^.n := 0;
  z^.p := nil;
end;

function luaZ_read(z: PZIO; b: Pointer; n: size_t): size_t;
var m: size_t;
begin
  while n <> 0 do
  begin
    if luaZ_lookahead(z) = EOZ then Exit(n);  { return number of missing bytes }
    if n <= z^.n then m := n else m := z^.n;  { min. between n and z->n }
    Move(z^.p^, b^, m);
    Dec(z^.n, m);
    Inc(z^.p, m);
    b := PAnsiChar(b) + m;
    Dec(n, m);
  end;
  Result := 0;
end;

function zgetc(z: PZIO): Integer;
begin
  if z^.n > 0 then
  begin
    Dec(z^.n);
    Result := Ord(z^.p^);
    Inc(z^.p);
  end
  else
  begin
    Result := luaZ_fill(z);
  end;
end;

procedure luaZ_resizebuffer(L: Plua_State; buff: PMbuffer; size: size_t);
begin
  buff^.buffer := luaM_reallocv(L, buff^.buffer, buff^.buffsize, size, 1);
  buff^.buffsize := size;
end;

procedure luaZ_freebuffer(L: Plua_State; buff: PMbuffer);
begin
  luaZ_resizebuffer(L, buff, 0);
end;

function luaZ_openspace(L: Plua_State; buff: PMbuffer; n: size_t): PAnsiChar;
begin
  if n > buff^.buffsize then
  begin
    if n < LUA_MINBUFFER then n := LUA_MINBUFFER;
    luaZ_resizebuffer(L, buff, n);
  end;
  Result := buff^.buffer;
end;

end.
