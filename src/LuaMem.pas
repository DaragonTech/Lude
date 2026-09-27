{
  Lua 5.1.4 - Pascal port of lmem.c
  Interface to Memory Manager
}
unit LuaMem;

{$I lua.inc}

interface

uses
  LuaTypes;

const
  MEMERRMSG = 'not enough memory';

function luaM_realloc_(L: Plua_State; block: Pointer; osize, nsize: size_t): Pointer;
function luaM_toobig(L: Plua_State): Pointer;
function luaM_growaux_(L: Plua_State; block: Pointer; var size: Integer; size_elems: size_t;
  limit: Integer; errormsg: PAnsiChar): Pointer;
function luaM_reallocv(L: Plua_State; b: Pointer; on, n: size_t; e: size_t): Pointer; inline;
procedure luaM_freemem(L: Plua_State; b: Pointer; s: size_t); inline;
function luaM_malloc(L: Plua_State; t: size_t): Pointer; inline;
function luaM_newvector(L: Plua_State; n: size_t; e: size_t): Pointer; inline;
procedure luaM_freearray(L: Plua_State; b: Pointer; n: size_t; e: size_t); inline;

implementation

uses
  LuaDo, LuaDebug;

const
  MINSIZEARRAY = 4;

function luaM_growaux_(L: Plua_State; block: Pointer; var size: Integer; size_elems: size_t;
  limit: Integer; errormsg: PAnsiChar): Pointer;
var newsize: Integer;
begin
  if size >= limit div 2 then
  begin  { cannot double it? }
    if size >= limit then  { cannot grow even a little? }
      luaG_runerror(L, errormsg, []);
    newsize := limit;  { still have at least one free place }
  end
  else
  begin
    newsize := size * 2;
    if newsize < MINSIZEARRAY then
      newsize := MINSIZEARRAY;  { minimum size }
  end;
  Result := luaM_reallocv(L, block, size, newsize, size_elems);
  size := newsize;  { update only when everything else is OK }
end;

function luaM_toobig(L: Plua_State): Pointer;
begin
  luaG_runerror(L, 'memory allocation error: block too big', []);
  Result := nil;  { to avoid warnings }
end;

{ generic allocation routine. }
function luaM_realloc_(L: Plua_State; block: Pointer; osize, nsize: size_t): Pointer;
var g: Pglobal_State;
begin
  g := L^.l_G;
  block := g^.frealloc(g^.ud, block, osize, nsize);
  if (block = nil) and (nsize > 0) then
    luaD_throw(L, LUA_ERRMEM);
  g^.totalbytes := (g^.totalbytes - osize) + nsize;
  Result := block;
end;

function luaM_reallocv(L: Plua_State; b: Pointer; on, n: size_t; e: size_t): Pointer;
begin
  if n + 1 <= MAX_SIZET div e then  { +1 to avoid warnings }
    Result := luaM_realloc_(L, b, on * e, n * e)
  else
    Result := luaM_toobig(L);
end;

procedure luaM_freemem(L: Plua_State; b: Pointer; s: size_t);
begin
  luaM_realloc_(L, b, s, 0);
end;

function luaM_malloc(L: Plua_State; t: size_t): Pointer;
begin
  Result := luaM_realloc_(L, nil, 0, t);
end;

function luaM_newvector(L: Plua_State; n: size_t; e: size_t): Pointer;
begin
  Result := luaM_reallocv(L, nil, 0, n, e);
end;

procedure luaM_freearray(L: Plua_State; b: Pointer; n: size_t; e: size_t);
begin
  luaM_reallocv(L, b, n, 0, e);
end;

end.
