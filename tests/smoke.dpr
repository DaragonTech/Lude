program smoke;
{$I ../src/lua.inc}
{$APPTYPE CONSOLE}
uses LuaTypes, LuaAPI, LuaAuxLib, LuaBaseLib, LuaState, LuaStdio, LuaFPU;
var L: Plua_State; st: Integer;
begin
  lua_set_c_fpu_mode;
  L := luaL_newstate;
  lua_pushcfunction(L, luaopen_base); lua_call(L, 0, 0);
  st := luaL_dofile(L, PAnsiChar(AnsiString(ParamStr(1))));
  if st <> 0 then begin c_fputs(lua_tostring(L, -1), c_stderr); c_fputs(#10, c_stderr); end;
  lua_close(L);
  c_flushall;
end.
