{
  Lua 5.1.4 - Pascal port of lfunc.c
  Auxiliary functions to manipulate prototypes and closures
}
unit LuaFunc;

{$I lua.inc}

interface

uses
  LuaTypes;

function sizeCclosure(n: Integer): Integer; inline;
function sizeLclosure(n: Integer): Integer; inline;
function luaF_newproto(L: Plua_State): PProto;
function luaF_newCclosure(L: Plua_State; nelems: Integer; e: PTable): PClosure;
function luaF_newLclosure(L: Plua_State; nelems: Integer; e: PTable): PClosure;
function luaF_newupval(L: Plua_State): PUpVal;
function luaF_findupval(L: Plua_State; level: StkId): PUpVal;
procedure luaF_close(L: Plua_State; level: StkId);
procedure luaF_freeproto(L: Plua_State; f: PProto);
procedure luaF_freeclosure(L: Plua_State; c: PClosure);
procedure luaF_freeupval(L: Plua_State; uv: PUpVal);
function luaF_getlocalname(f: PProto; local_number: Integer; pc: Integer): PAnsiChar;

implementation

uses
  LuaMem, LuaGC;

function sizeCclosure(n: Integer): Integer;
begin
  Result := SizeOf(TCClosure) + SizeOf(TValue) * (n - 1);
end;

function sizeLclosure(n: Integer): Integer;
begin
  Result := SizeOf(TLClosure) + SizeOf(PTValue) * (n - 1);
end;

function luaF_newCclosure(L: Plua_State; nelems: Integer; e: PTable): PClosure;
var c: PClosure;
begin
  c := luaM_malloc(L, sizeCclosure(nelems));
  luaC_link(L, obj2gco(c), LUA_TFUNCTION);
  c^.c.isC := 1;
  c^.c.env := e;
  c^.c.nupvalues := lu_byte(nelems);
  Result := c;
end;

function luaF_newLclosure(L: Plua_State; nelems: Integer; e: PTable): PClosure;
var c: PClosure;
begin
  c := luaM_malloc(L, sizeLclosure(nelems));
  luaC_link(L, obj2gco(c), LUA_TFUNCTION);
  c^.l.isC := 0;
  c^.l.env := e;
  c^.l.nupvalues := lu_byte(nelems);
  while nelems > 0 do
  begin
    Dec(nelems);
    PPUpVal(@c^.l.upvals)[nelems] := nil;
  end;
  Result := c;
end;

function luaF_newupval(L: Plua_State): PUpVal;
var uv: PUpVal;
begin
  uv := luaM_malloc(L, SizeOf(TUpVal));
  luaC_link(L, obj2gco(uv), LUA_TUPVAL);
  uv^.v := @uv^.value;
  setnilvalue(uv^.v);
  Result := uv;
end;

function luaF_findupval(L: Plua_State; level: StkId): PUpVal;
var g: Pglobal_State; pp: PPGCObject; p, uv: PUpVal;
begin
  g := L^.l_G;
  pp := @L^.openupval;
  while pp^ <> nil do
  begin
    p := gco2uv(pp^);
    if PAnsiChar(p^.v) < PAnsiChar(level) then Break;
    if p^.v = level then
    begin  { found a corresponding upvalue? }
      if isdead(g, obj2gco(p)) then  { is it dead? }
        changewhite(obj2gco(p));  { ressurect it }
      Exit(p);
    end;
    pp := @p^.next;
  end;
  uv := luaM_malloc(L, SizeOf(TUpVal));  { not found: create a new one }
  uv^.tt := LUA_TUPVAL;
  uv^.marked := luaC_white(g);
  uv^.v := level;  { current value lives in the stack }
  uv^.next := pp^;  { chain it in the proper position }
  pp^ := obj2gco(uv);
  uv^.prev := @g^.uvhead;  { double link it in `uvhead' list }
  uv^.lnext := g^.uvhead.lnext;
  uv^.lnext^.prev := uv;
  g^.uvhead.lnext := uv;
  Result := uv;
end;

procedure unlinkupval(uv: PUpVal);
begin
  uv^.lnext^.prev := uv^.prev;  { remove from `uvhead' list }
  uv^.prev^.lnext := uv^.lnext;
end;

procedure luaF_freeupval(L: Plua_State; uv: PUpVal);
begin
  if uv^.v <> @uv^.value then  { is it open? }
    unlinkupval(uv);  { remove from open list }
  luaM_freemem(L, uv, SizeOf(TUpVal));  { free upvalue }
end;

procedure luaF_close(L: Plua_State; level: StkId);
var uv: PUpVal; g: Pglobal_State; o: PGCObject;
begin
  g := L^.l_G;
  while L^.openupval <> nil do
  begin
    uv := gco2uv(L^.openupval);
    if PAnsiChar(uv^.v) < PAnsiChar(level) then Break;
    o := obj2gco(uv);
    L^.openupval := uv^.next;  { remove from `open' list }
    if isdead(g, o) then
      luaF_freeupval(L, uv)  { free upvalue }
    else
    begin
      unlinkupval(uv);
      setobj(L, @uv^.value, uv^.v);
      uv^.v := @uv^.value;  { now current value lives here }
      luaC_linkupval(L, uv);  { link upvalue into `gcroot' list }
    end;
  end;
end;

function luaF_newproto(L: Plua_State): PProto;
var f: PProto;
begin
  f := luaM_malloc(L, SizeOf(TProto));
  luaC_link(L, obj2gco(f), LUA_TPROTO);
  f^.k := nil;
  f^.sizek := 0;
  f^.p := nil;
  f^.sizep := 0;
  f^.code := nil;
  f^.sizecode := 0;
  f^.sizelineinfo := 0;
  f^.sizeupvalues := 0;
  f^.nups := 0;
  f^.upvalues := nil;
  f^.numparams := 0;
  f^.is_vararg := 0;
  f^.maxstacksize := 0;
  f^.lineinfo := nil;
  f^.sizelocvars := 0;
  f^.locvars := nil;
  f^.linedefined := 0;
  f^.lastlinedefined := 0;
  f^.source := nil;
  Result := f;
end;

procedure luaF_freeproto(L: Plua_State; f: PProto);
begin
  luaM_freearray(L, f^.code, f^.sizecode, SizeOf(Instruction));
  luaM_freearray(L, f^.p, f^.sizep, SizeOf(PProto));
  luaM_freearray(L, f^.k, f^.sizek, SizeOf(TValue));
  luaM_freearray(L, f^.lineinfo, f^.sizelineinfo, SizeOf(Integer));
  luaM_freearray(L, f^.locvars, f^.sizelocvars, SizeOf(TLocVar));
  luaM_freearray(L, f^.upvalues, f^.sizeupvalues, SizeOf(PTString));
  luaM_freemem(L, f, SizeOf(TProto));
end;

procedure luaF_freeclosure(L: Plua_State; c: PClosure);
var size: Integer;
begin
  if c^.c.isC <> 0 then size := sizeCclosure(c^.c.nupvalues)
  else size := sizeLclosure(c^.l.nupvalues);
  luaM_freemem(L, c, size);
end;

{ Look for n-th local variable at line `line' in function `func'.
  Returns NULL if not found. }
function luaF_getlocalname(f: PProto; local_number: Integer; pc: Integer): PAnsiChar;
var i: Integer;
begin
  i := 0;
  while (i < f^.sizelocvars) and (f^.locvars[i].startpc <= pc) do
  begin
    if pc < f^.locvars[i].endpc then
    begin  { is variable active? }
      Dec(local_number);
      if local_number = 0 then
        Exit(getstr(f^.locvars[i].varname));
    end;
    Inc(i);
  end;
  Result := nil;  { not found }
end;

end.
