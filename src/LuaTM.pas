{
  Lua 5.1.4 - Pascal port of ltm.c
  Tag methods
}
unit LuaTM;

{$I lua.inc}

interface

uses
  LuaTypes;

const
  luaT_typenames: array[0..10] of PAnsiChar = (
    'nil', 'boolean', 'userdata', 'number',
    'string', 'table', 'function', 'userdata', 'thread',
    'proto', 'upval');

procedure luaT_init(L: Plua_State);
function luaT_gettm(events: PTable; event: TMS; ename: PTString): PTValue;
function luaT_gettmbyobj(L: Plua_State; o: PTValue; event: TMS): PTValue;
function gfasttm(g: Pglobal_State; et: PTable; e: TMS): PTValue; inline;
function fasttm(L: Plua_State; et: PTable; e: TMS): PTValue; inline;

implementation

uses
  LuaObject, LuaString, LuaTable;

const
  luaT_eventname: array[0..TM_N - 1] of PAnsiChar = (
    '__index', '__newindex',
    '__gc', '__mode', '__eq',
    '__add', '__sub', '__mul', '__div', '__mod',
    '__pow', '__unm', '__len', '__lt', '__le',
    '__concat', '__call');

procedure luaT_init(L: Plua_State);
var i: Integer;
begin
  for i := 0 to TM_N - 1 do
  begin
    L^.l_G^.tmname[i] := luaS_new(L, luaT_eventname[i]);
    luaS_fix(L^.l_G^.tmname[i]);  { never collect these names }
  end;
end;

{ function to be used with macro "fasttm": optimized for absence of tag methods }
function luaT_gettm(events: PTable; event: TMS; ename: PTString): PTValue;
var tm: PTValue;
begin
  tm := luaH_getstr(events, ename);
  if ttisnil(tm) then
  begin  { no tag method? }
    events^.flags := events^.flags or lu_byte(1 shl event);  { cache this fact }
    Result := nil;
  end
  else
    Result := tm;
end;

function luaT_gettmbyobj(L: Plua_State; o: PTValue; event: TMS): PTValue;
var mt: PTable;
begin
  case o^.tt of
    LUA_TTABLE: mt := hvalue(o)^.metatable;
    LUA_TUSERDATA: mt := uvalue(o)^.metatable;
  else
    mt := L^.l_G^.mt[o^.tt];
  end;
  if mt <> nil then Result := luaH_getstr(mt, L^.l_G^.tmname[event])
  else Result := luaO_nilobject;
end;

function gfasttm(g: Pglobal_State; et: PTable; e: TMS): PTValue;
begin
  if et = nil then Result := nil
  else if (et^.flags and (1 shl e)) <> 0 then Result := nil
  else Result := luaT_gettm(et, e, g^.tmname[e]);
end;

function fasttm(L: Plua_State; et: PTable; e: TMS): PTValue;
begin
  Result := gfasttm(L^.l_G, et, e);
end;

end.
