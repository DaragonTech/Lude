{
  lua51.dll - proxy DLL.
  Every export is forwarded to lua5.1.dll (the real implementation), so
  programs and modules linked against either name share one Lua runtime,
  like the LuaBinaries distribution.  The exported entries are the import
  thunks (jmp [IAT]) of lua5.1.dll, so varargs functions
  (lua_pushfstring, luaL_error) are forwarded untouched.
}
library lua51;

{$I src/lua.inc}

const
  LUADLL = 'lua5.1.dll';

procedure luaL_addlstring; external LUADLL;
procedure luaL_addstring; external LUADLL;
procedure luaL_addvalue; external LUADLL;
procedure luaL_argerror; external LUADLL;
procedure luaL_buffinit; external LUADLL;
procedure luaL_callmeta; external LUADLL;
procedure luaL_checkany; external LUADLL;
procedure luaL_checkinteger; external LUADLL;
procedure luaL_checklstring; external LUADLL;
procedure luaL_checknumber; external LUADLL;
procedure luaL_checkoption; external LUADLL;
procedure luaL_checkstack; external LUADLL;
procedure luaL_checktype; external LUADLL;
procedure luaL_checkudata; external LUADLL;
procedure luaL_error; external LUADLL;
procedure luaL_findtable; external LUADLL;
procedure luaL_getmetafield; external LUADLL;
procedure luaL_gsub; external LUADLL;
procedure luaL_loadbuffer; external LUADLL;
procedure luaL_loadfile; external LUADLL;
procedure luaL_loadstring; external LUADLL;
procedure luaL_newmetatable; external LUADLL;
procedure luaL_newstate; external LUADLL;
procedure luaL_openlib; external LUADLL;
procedure luaL_openlibs; external LUADLL;
procedure luaL_optinteger; external LUADLL;
procedure luaL_optlstring; external LUADLL;
procedure luaL_optnumber; external LUADLL;
procedure luaL_prepbuffer; external LUADLL;
procedure luaL_pushresult; external LUADLL;
procedure luaL_ref; external LUADLL;
procedure luaL_register; external LUADLL;
procedure luaL_typerror; external LUADLL;
procedure luaL_unref; external LUADLL;
procedure luaL_where; external LUADLL;
procedure lua_atpanic; external LUADLL;
procedure lua_call; external LUADLL;
procedure lua_checkstack; external LUADLL;
procedure lua_close; external LUADLL;
procedure lua_concat; external LUADLL;
procedure lua_cpcall; external LUADLL;
procedure lua_createtable; external LUADLL;
procedure lua_dump; external LUADLL;
procedure lua_equal; external LUADLL;
procedure lua_error; external LUADLL;
procedure lua_gc; external LUADLL;
procedure lua_getallocf; external LUADLL;
procedure lua_getfenv; external LUADLL;
procedure lua_getfield; external LUADLL;
procedure lua_gethook; external LUADLL;
procedure lua_gethookcount; external LUADLL;
procedure lua_gethookmask; external LUADLL;
procedure lua_getinfo; external LUADLL;
procedure lua_getlocal; external LUADLL;
procedure lua_getmetatable; external LUADLL;
procedure lua_getstack; external LUADLL;
procedure lua_gettable; external LUADLL;
procedure lua_gettop; external LUADLL;
procedure lua_getupvalue; external LUADLL;
procedure lua_insert; external LUADLL;
procedure lua_iscfunction; external LUADLL;
procedure lua_isnumber; external LUADLL;
procedure lua_isstring; external LUADLL;
procedure lua_isuserdata; external LUADLL;
procedure lua_lessthan; external LUADLL;
procedure lua_load; external LUADLL;
procedure lua_newstate; external LUADLL;
procedure lua_newthread; external LUADLL;
procedure lua_newuserdata; external LUADLL;
procedure lua_next; external LUADLL;
procedure lua_objlen; external LUADLL;
procedure lua_pcall; external LUADLL;
procedure lua_pushboolean; external LUADLL;
procedure lua_pushcclosure; external LUADLL;
procedure lua_pushfstring; external LUADLL;
procedure lua_pushinteger; external LUADLL;
procedure lua_pushlightuserdata; external LUADLL;
procedure lua_pushlstring; external LUADLL;
procedure lua_pushnil; external LUADLL;
procedure lua_pushnumber; external LUADLL;
procedure lua_pushstring; external LUADLL;
procedure lua_pushthread; external LUADLL;
procedure lua_pushvalue; external LUADLL;
procedure lua_pushvfstring; external LUADLL;
procedure lua_rawequal; external LUADLL;
procedure lua_rawget; external LUADLL;
procedure lua_rawgeti; external LUADLL;
procedure lua_rawset; external LUADLL;
procedure lua_rawseti; external LUADLL;
procedure lua_remove; external LUADLL;
procedure lua_replace; external LUADLL;
procedure lua_resume; external LUADLL;
procedure lua_setallocf; external LUADLL;
procedure lua_setfenv; external LUADLL;
procedure lua_setfield; external LUADLL;
procedure lua_sethook; external LUADLL;
procedure lua_setlevel; external LUADLL;
procedure lua_setlocal; external LUADLL;
procedure lua_setmetatable; external LUADLL;
procedure lua_settable; external LUADLL;
procedure lua_settop; external LUADLL;
procedure lua_setupvalue; external LUADLL;
procedure lua_status; external LUADLL;
procedure lua_toboolean; external LUADLL;
procedure lua_tocfunction; external LUADLL;
procedure lua_tointeger; external LUADLL;
procedure lua_tolstring; external LUADLL;
procedure lua_tonumber; external LUADLL;
procedure lua_topointer; external LUADLL;
procedure lua_tothread; external LUADLL;
procedure lua_touserdata; external LUADLL;
procedure lua_type; external LUADLL;
procedure lua_typename; external LUADLL;
procedure lua_xmove; external LUADLL;
procedure lua_yield; external LUADLL;
procedure luaopen_base; external LUADLL;
procedure luaopen_debug; external LUADLL;
procedure luaopen_io; external LUADLL;
procedure luaopen_math; external LUADLL;
procedure luaopen_os; external LUADLL;
procedure luaopen_package; external LUADLL;
procedure luaopen_string; external LUADLL;
procedure luaopen_table; external LUADLL;

exports
  luaL_addlstring,
  luaL_addstring,
  luaL_addvalue,
  luaL_argerror,
  luaL_buffinit,
  luaL_callmeta,
  luaL_checkany,
  luaL_checkinteger,
  luaL_checklstring,
  luaL_checknumber,
  luaL_checkoption,
  luaL_checkstack,
  luaL_checktype,
  luaL_checkudata,
  luaL_error,
  luaL_findtable,
  luaL_getmetafield,
  luaL_gsub,
  luaL_loadbuffer,
  luaL_loadfile,
  luaL_loadstring,
  luaL_newmetatable,
  luaL_newstate,
  luaL_openlib,
  luaL_openlibs,
  luaL_optinteger,
  luaL_optlstring,
  luaL_optnumber,
  luaL_prepbuffer,
  luaL_pushresult,
  luaL_ref,
  luaL_register,
  luaL_typerror,
  luaL_unref,
  luaL_where,
  lua_atpanic,
  lua_call,
  lua_checkstack,
  lua_close,
  lua_concat,
  lua_cpcall,
  lua_createtable,
  lua_dump,
  lua_equal,
  lua_error,
  lua_gc,
  lua_getallocf,
  lua_getfenv,
  lua_getfield,
  lua_gethook,
  lua_gethookcount,
  lua_gethookmask,
  lua_getinfo,
  lua_getlocal,
  lua_getmetatable,
  lua_getstack,
  lua_gettable,
  lua_gettop,
  lua_getupvalue,
  lua_insert,
  lua_iscfunction,
  lua_isnumber,
  lua_isstring,
  lua_isuserdata,
  lua_lessthan,
  lua_load,
  lua_newstate,
  lua_newthread,
  lua_newuserdata,
  lua_next,
  lua_objlen,
  lua_pcall,
  lua_pushboolean,
  lua_pushcclosure,
  lua_pushfstring,
  lua_pushinteger,
  lua_pushlightuserdata,
  lua_pushlstring,
  lua_pushnil,
  lua_pushnumber,
  lua_pushstring,
  lua_pushthread,
  lua_pushvalue,
  lua_pushvfstring,
  lua_rawequal,
  lua_rawget,
  lua_rawgeti,
  lua_rawset,
  lua_rawseti,
  lua_remove,
  lua_replace,
  lua_resume,
  lua_setallocf,
  lua_setfenv,
  lua_setfield,
  lua_sethook,
  lua_setlevel,
  lua_setlocal,
  lua_setmetatable,
  lua_settable,
  lua_settop,
  lua_setupvalue,
  lua_status,
  lua_toboolean,
  lua_tocfunction,
  lua_tointeger,
  lua_tolstring,
  lua_tonumber,
  lua_topointer,
  lua_tothread,
  lua_touserdata,
  lua_type,
  lua_typename,
  lua_xmove,
  lua_yield,
  luaopen_base,
  luaopen_debug,
  luaopen_io,
  luaopen_math,
  luaopen_os,
  luaopen_package,
  luaopen_string,
  luaopen_table;

begin
end.
