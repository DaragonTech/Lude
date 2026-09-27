{
  Lua 5.1.4 - Pascal port of linit.c
  Initialization of libraries for lua.c
}
unit LuaInit;

{$I lua.inc}

interface

uses
  LuaTypes;

procedure luaL_openlibs(L: Plua_State); cdecl;

implementation

uses
  LuaAPI, LuaBaseLib, LuaLoadLib, LuaTabLib, LuaIOLib, LuaOSLib, LuaStrLib,
  LuaMathLib, LuaDbLib;

const
  lualibs: array[0..8] of luaL_Reg = (
    (name: ''; func: luaopen_base),
    (name: LUA_LOADLIBNAME; func: luaopen_package),
    (name: LUA_TABLIBNAME; func: luaopen_table),
    (name: LUA_IOLIBNAME; func: luaopen_io),
    (name: LUA_OSLIBNAME; func: luaopen_os),
    (name: LUA_STRLIBNAME; func: luaopen_string),
    (name: LUA_MATHLIBNAME; func: luaopen_math),
    (name: LUA_DBLIBNAME; func: luaopen_debug),
    (name: nil; func: nil));

procedure luaL_openlibs(L: Plua_State); cdecl;
var lib: PluaL_Reg;
begin
  lib := @lualibs[0];
  while Assigned(lib^.func) do
  begin
    lua_pushcfunction(L, lib^.func);
    lua_pushstring(L, lib^.name);
    lua_call(L, 1, 0);
    Inc(lib);
  end;
end;

end.
