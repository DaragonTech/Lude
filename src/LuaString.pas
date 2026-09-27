{
  Lua 5.1.4 - Pascal port of lstring.c
  String table (keeps all strings handled by Lua)
}
unit LuaString;

{$I lua.inc}

interface

uses
  LuaTypes;

procedure luaS_resize(L: Plua_State; newsize: Integer);
function luaS_newudata(L: Plua_State; s: size_t; e: PTable): PUdata;
function luaS_newlstr(L: Plua_State; str: PAnsiChar; slen: size_t): PTString;
function luaS_new(L: Plua_State; s: PAnsiChar): PTString; inline;
function luaS_newliteral(L: Plua_State; const s: AnsiString): PTString;
procedure luaS_fix(s: PTString); inline;
function sizestring(s: PTString): size_t; inline;
function sizeudata(u: PUdata): size_t; inline;

implementation

uses
  LuaCRT, LuaMem, LuaGC;

function sizestring(s: PTString): size_t;
begin
  Result := TSTRING_SIZE + (s^.len + 1);
end;

function sizeudata(u: PUdata): size_t;
begin
  Result := UDATA_SIZE + u^.len;
end;

procedure luaS_fix(s: PTString);
begin
  s^.marked := s^.marked or (1 shl FIXEDBIT);
end;

procedure luaS_resize(L: Plua_State; newsize: Integer);
var newhash: PPGCObject; tb: ^Tstringtable; i, h1: Integer; p, next: PGCObject; h: Cardinal;
begin
  if L^.l_G^.gcstate = GCSsweepstring then
    Exit;  { cannot resize during GC traverse }
  newhash := luaM_newvector(L, newsize, SizeOf(PGCObject));
  tb := @L^.l_G^.strt;
  for i := 0 to newsize - 1 do newhash[i] := nil;
  { rehash }
  for i := 0 to tb^.size - 1 do
  begin
    p := tb^.hash[i];
    while p <> nil do
    begin  { for each node in the list }
      next := p^.next;  { save next }
      h := gco2ts(p)^.hash;
      h1 := lmod(h, newsize);  { new position }
      p^.next := newhash[h1];  { chain it }
      newhash[h1] := p;
      p := next;
    end;
  end;
  luaM_freearray(L, tb^.hash, tb^.size, SizeOf(PTString));
  tb^.size := newsize;
  tb^.hash := newhash;
end;

function newlstr(L: Plua_State; str: PAnsiChar; slen: size_t; h: Cardinal): PTString;
var ts: PTString; tb: ^Tstringtable;
begin
  if slen + 1 > (MAX_SIZET - TSTRING_SIZE) then
    luaM_toobig(L);
  ts := luaM_malloc(L, (slen + 1) + TSTRING_SIZE);
  ts^.len := slen;
  ts^.hash := h;
  ts^.marked := luaC_white(L^.l_G);
  ts^.tt := LUA_TSTRING;
  ts^.reserved := 0;
  Move(str^, getstr(ts)^, slen);
  getstr(ts)[slen] := #0;  { ending 0 }
  tb := @L^.l_G^.strt;
  h := Cardinal(lmod(h, tb^.size));
  ts^.next := tb^.hash[h];  { chain new entry }
  tb^.hash[h] := obj2gco(ts);
  Inc(tb^.nuse);
  if (tb^.nuse > lu_int32(tb^.size)) and (tb^.size <= MAX_INT div 2) then
    luaS_resize(L, tb^.size * 2);  { too crowded }
  Result := ts;
end;

function luaS_newlstr(L: Plua_State; str: PAnsiChar; slen: size_t): PTString;
var o: PGCObject; h: Cardinal; step, l1: size_t; ts: PTString;
begin
  h := Cardinal(slen);  { seed }
  step := (slen shr 5) + 1;  { if string is too long, don't hash all its chars }
  l1 := slen;
  while l1 >= step do  { compute hash }
  begin
    h := h xor ((h shl 5) + (h shr 2) + Cardinal(Byte(str[l1 - 1])));
    Dec(l1, step);
  end;
  o := L^.l_G^.strt.hash[lmod(h, L^.l_G^.strt.size)];
  while o <> nil do
  begin
    ts := PTString(o);
    if (ts^.len = slen) and (c_memcmp(str, getstr(ts), slen) = 0) then
    begin
      { string may be dead }
      if isdead(L^.l_G, o) then changewhite(o);
      Exit(ts);
    end;
    o := o^.next;
  end;
  Result := newlstr(L, str, slen, h);  { not found }
end;

function luaS_new(L: Plua_State; s: PAnsiChar): PTString;
begin
  Result := luaS_newlstr(L, s, c_strlen(s));
end;

function luaS_newliteral(L: Plua_State; const s: AnsiString): PTString;
begin
  Result := luaS_newlstr(L, PAnsiChar(s), Length(s));
end;

function luaS_newudata(L: Plua_State; s: size_t; e: PTable): PUdata;
var u: PUdata;
begin
  if s > MAX_SIZET - UDATA_SIZE then
    luaM_toobig(L);
  u := luaM_malloc(L, s + UDATA_SIZE);
  u^.marked := luaC_white(L^.l_G);  { is not finalized }
  u^.tt := LUA_TUSERDATA;
  u^.len := s;
  u^.metatable := nil;
  u^.env := e;
  { chain it on udata list (after main thread) }
  u^.next := L^.l_G^.mainthread^.next;
  L^.l_G^.mainthread^.next := obj2gco(u);
  Result := u;
end;

end.
