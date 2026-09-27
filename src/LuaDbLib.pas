{
  Lua 5.1.4 - Pascal port of ldblib.c
  Interface from Lua to its debug API
}
unit LuaDbLib;

{$I lua.inc}

interface

uses
  LuaTypes;

function luaopen_debug(L: Plua_State): Integer; cdecl;

implementation

uses
  LuaCRT, LuaAPI, LuaAuxLib, LuaDebug, LuaStdio;

function db_getregistry(L: Plua_State): Integer; cdecl;
begin
  lua_pushvalue(L, LUA_REGISTRYINDEX);
  Result := 1;
end;

function db_getmetatable(L: Plua_State): Integer; cdecl;
begin
  luaL_checkany(L, 1);
  if lua_getmetatable(L, 1) = 0 then
    lua_pushnil(L);  { no metatable }
  Result := 1;
end;

function db_setmetatable(L: Plua_State): Integer; cdecl;
var t: Integer;
begin
  t := lua_type(L, 2);
  luaL_argcheck(L, (t = LUA_TNIL) or (t = LUA_TTABLE), 2, 'nil or table expected');
  lua_settop(L, 2);
  lua_pushboolean(L, lua_setmetatable(L, 1));
  Result := 1;
end;

function db_getfenv(L: Plua_State): Integer; cdecl;
begin
  lua_getfenv(L, 1);
  Result := 1;
end;

function db_setfenv(L: Plua_State): Integer; cdecl;
begin
  luaL_checktype(L, 2, LUA_TTABLE);
  lua_settop(L, 2);
  if lua_setfenv(L, 1) = 0 then
    luaL_errorf(L, '''setfenv'' cannot change environment of given object', []);
  Result := 1;
end;

procedure settabss(L: Plua_State; i, v: PAnsiChar);
begin
  lua_pushstring(L, v);
  lua_setfield(L, -2, i);
end;

procedure settabsi(L: Plua_State; i: PAnsiChar; v: Integer);
begin
  lua_pushinteger(L, v);
  lua_setfield(L, -2, i);
end;

function getthread(L: Plua_State; var arg: Integer): Plua_State;
begin
  if lua_isthread(L, 1) then
  begin
    arg := 1;
    Result := lua_tothread(L, 1);
  end
  else
  begin
    arg := 0;
    Result := L;
  end;
end;

procedure treatstackoption(L, L1: Plua_State; fname: PAnsiChar);
begin
  if L = L1 then
  begin
    lua_pushvalue(L, -2);
    lua_remove(L, -3);
  end
  else
    lua_xmove(L1, L, 1);
  lua_setfield(L, -2, fname);
end;

function db_getinfo(L: Plua_State): Integer; cdecl;
var ar: lua_Debug; arg: Integer; L1: Plua_State; options: PAnsiChar;
begin
  L1 := getthread(L, arg);
  options := luaL_optstring(L, arg + 2, 'flnSu');
  if lua_isnumber(L, arg + 1) <> 0 then
  begin
    if lua_getstack(L1, Integer(lua_tointeger(L, arg + 1)), @ar) = 0 then
    begin
      lua_pushnil(L);  { level out of range }
      Exit(1);
    end;
  end
  else if lua_isfunction(L, arg + 1) then
  begin
    lua_pushfstringf(L, '>%s', [options]);
    options := lua_tostring(L, -1);
    lua_pushvalue(L, arg + 1);
    lua_xmove(L, L1, 1);
  end
  else
    Exit(luaL_argerror(L, arg + 1, 'function or level expected'));
  if lua_getinfo(L1, options, @ar) = 0 then
    Exit(luaL_argerror(L, arg + 2, 'invalid option'));
  lua_createtable(L, 0, 2);
  if c_strchr(options, Ord('S')) <> nil then
  begin
    settabss(L, 'source', ar.source);
    settabss(L, 'short_src', @ar.short_src[0]);
    settabsi(L, 'linedefined', ar.linedefined);
    settabsi(L, 'lastlinedefined', ar.lastlinedefined);
    settabss(L, 'what', ar.what);
  end;
  if c_strchr(options, Ord('l')) <> nil then
    settabsi(L, 'currentline', ar.currentline);
  if c_strchr(options, Ord('u')) <> nil then
    settabsi(L, 'nups', ar.nups);
  if c_strchr(options, Ord('n')) <> nil then
  begin
    settabss(L, 'name', ar.name);
    settabss(L, 'namewhat', ar.namewhat);
  end;
  if c_strchr(options, Ord('L')) <> nil then
    treatstackoption(L, L1, 'activelines');
  if c_strchr(options, Ord('f')) <> nil then
    treatstackoption(L, L1, 'func');
  Result := 1;  { return table }
end;

function db_getlocal(L: Plua_State): Integer; cdecl;
var arg: Integer; L1: Plua_State; ar: lua_Debug; name: PAnsiChar;
begin
  L1 := getthread(L, arg);
  if lua_getstack(L1, luaL_checkint(L, arg + 1), @ar) = 0 then  { out of range? }
    Exit(luaL_argerror(L, arg + 1, 'level out of range'));
  name := lua_getlocal(L1, @ar, luaL_checkint(L, arg + 2));
  if name <> nil then
  begin
    lua_xmove(L1, L, 1);
    lua_pushstring(L, name);
    lua_pushvalue(L, -2);
    Result := 2;
  end
  else
  begin
    lua_pushnil(L);
    Result := 1;
  end;
end;

function db_setlocal(L: Plua_State): Integer; cdecl;
var arg: Integer; L1: Plua_State; ar: lua_Debug;
begin
  L1 := getthread(L, arg);
  if lua_getstack(L1, luaL_checkint(L, arg + 1), @ar) = 0 then  { out of range? }
    Exit(luaL_argerror(L, arg + 1, 'level out of range'));
  luaL_checkany(L, arg + 3);
  lua_settop(L, arg + 3);
  lua_xmove(L, L1, 1);
  lua_pushstring(L, lua_setlocal(L1, @ar, luaL_checkint(L, arg + 2)));
  Result := 1;
end;

function auxupvalue(L: Plua_State; get: Integer): Integer;
var name: PAnsiChar; n: Integer;
begin
  n := luaL_checkint(L, 2);
  luaL_checktype(L, 1, LUA_TFUNCTION);
  if lua_iscfunction(L, 1) <> 0 then Exit(0);  { cannot touch C upvalues from Lua }
  if get <> 0 then name := lua_getupvalue(L, 1, n)
  else name := lua_setupvalue(L, 1, n);
  if name = nil then Exit(0);
  lua_pushstring(L, name);
  lua_insert(L, -(get + 1));
  Result := get + 1;
end;

function db_getupvalue(L: Plua_State): Integer; cdecl;
begin
  Result := auxupvalue(L, 1);
end;

function db_setupvalue(L: Plua_State): Integer; cdecl;
begin
  luaL_checkany(L, 3);
  Result := auxupvalue(L, 0);
end;

var
  KEY_HOOK: AnsiChar = 'h';

const
  hooknames: array[0..4] of PAnsiChar = ('call', 'return', 'line', 'count', 'tail return');

procedure hookf(L: Plua_State; ar: Plua_Debug); cdecl;
begin
  lua_pushlightuserdata(L, @KEY_HOOK);
  lua_rawget(L, LUA_REGISTRYINDEX);
  lua_pushlightuserdata(L, L);
  lua_rawget(L, -2);
  if lua_isfunction(L, -1) then
  begin
    lua_pushstring(L, hooknames[ar^.event]);
    if ar^.currentline >= 0 then
      lua_pushinteger(L, ar^.currentline)
    else
      lua_pushnil(L);
    lua_call(L, 2, 0);
  end;
end;

function makemask(smask: PAnsiChar; count: Integer): Integer;
var mask: Integer;
begin
  mask := 0;
  if c_strchr(smask, Ord('c')) <> nil then mask := mask or LUA_MASKCALL;
  if c_strchr(smask, Ord('r')) <> nil then mask := mask or LUA_MASKRET;
  if c_strchr(smask, Ord('l')) <> nil then mask := mask or LUA_MASKLINE;
  if count > 0 then mask := mask or LUA_MASKCOUNT;
  Result := mask;
end;

function unmakemask(mask: Integer; smask: PAnsiChar): PAnsiChar;
var i: Integer;
begin
  i := 0;
  if (mask and LUA_MASKCALL) <> 0 then begin smask[i] := 'c'; Inc(i); end;
  if (mask and LUA_MASKRET) <> 0 then begin smask[i] := 'r'; Inc(i); end;
  if (mask and LUA_MASKLINE) <> 0 then begin smask[i] := 'l'; Inc(i); end;
  smask[i] := #0;
  Result := smask;
end;

procedure gethooktable(L: Plua_State);
begin
  lua_pushlightuserdata(L, @KEY_HOOK);
  lua_rawget(L, LUA_REGISTRYINDEX);
  if not lua_istable(L, -1) then
  begin
    lua_pop(L, 1);
    lua_createtable(L, 0, 1);
    lua_pushlightuserdata(L, @KEY_HOOK);
    lua_pushvalue(L, -2);
    lua_rawset(L, LUA_REGISTRYINDEX);
  end;
end;

function db_sethook(L: Plua_State): Integer; cdecl;
var arg, mask, count: Integer; func: lua_Hook; L1: Plua_State; smask: PAnsiChar;
begin
  L1 := getthread(L, arg);
  if lua_isnoneornil(L, arg + 1) then
  begin
    lua_settop(L, arg + 1);
    func := nil; mask := 0; count := 0;  { turn off hooks }
  end
  else
  begin
    smask := luaL_checkstring(L, arg + 2);
    luaL_checktype(L, arg + 1, LUA_TFUNCTION);
    count := luaL_optint(L, arg + 3, 0);
    func := hookf;
    mask := makemask(smask, count);
  end;
  gethooktable(L);
  lua_pushlightuserdata(L, L1);
  lua_pushvalue(L, arg + 1);
  lua_rawset(L, -3);  { set new hook }
  lua_pop(L, 1);  { remove hook table }
  lua_sethook(L1, func, mask, count);  { set hooks }
  Result := 0;
end;

function db_gethook(L: Plua_State): Integer; cdecl;
var arg, mask: Integer; L1: Plua_State; buff: array[0..4] of AnsiChar; hook: lua_Hook;
begin
  L1 := getthread(L, arg);
  mask := lua_gethookmask(L1);
  hook := lua_gethook(L1);
  if Assigned(hook) and (@hook <> @hookf) then  { external hook? }
    lua_pushlstring(L, 'external hook', 13)
  else
  begin
    gethooktable(L);
    lua_pushlightuserdata(L, L1);
    lua_rawget(L, -2);  { get hook }
    lua_remove(L, -2);  { remove hook table }
  end;
  lua_pushstring(L, unmakemask(mask, @buff[0]));
  lua_pushinteger(L, lua_gethookcount(L1));
  Result := 3;
end;

function db_debug(L: Plua_State): Integer; cdecl;
var buffer: array[0..249] of AnsiChar;
begin
  while True do
  begin
    c_fputs('lua_debug> ', c_stderr);
    if (c_fgets(@buffer[0], SizeOf(buffer), c_stdin) = nil) or
       (c_strcmp(@buffer[0], 'cont'#10) = 0) then
      Exit(0);
    if (luaL_loadbuffer(L, @buffer[0], c_strlen(@buffer[0]), '=(debug command)') <> 0) or
       (lua_pcall(L, 0, 0, 0) <> 0) then
    begin
      c_fputs(lua_tostring(L, -1), c_stderr);
      c_fputs(#10, c_stderr);
    end;
    lua_settop(L, 0);  { remove eventual returns }
  end;
end;

const
  LEVELS1 = 12;  { size of the first part of the stack }
  LEVELS2 = 10;  { size of the second part of the stack }

function db_errorfb(L: Plua_State): Integer; cdecl;
var level, arg: Integer; firstpart: Boolean; L1: Plua_State; ar: lua_Debug;
begin
  firstpart := True;  { still before eventual `...' }
  L1 := getthread(L, arg);
  if lua_isnumber(L, arg + 2) <> 0 then
  begin
    level := Integer(lua_tointeger(L, arg + 2));
    lua_pop(L, 1);
  end
  else
  begin
    if L = L1 then level := 1 else level := 0;  { level 0 may be this own function }
  end;
  if lua_gettop(L) = arg then
    lua_pushlstring(L, '', 0)
  else if lua_isstring(L, arg + 1) = 0 then
    Exit(1)  { message is not a string }
  else
    lua_pushlstring(L, #10, 1);
  lua_pushlstring(L, 'stack traceback:', 16);
  while lua_getstack(L1, level, @ar) <> 0 do
  begin
    Inc(level);
    if (level > LEVELS1) and firstpart then
    begin
      { no more than `LEVELS2' more levels? }
      if lua_getstack(L1, level + LEVELS2, @ar) = 0 then
        Dec(level)  { keep going }
      else
      begin
        lua_pushlstring(L, #10#9'...', 5);  { too many levels }
        while lua_getstack(L1, level + LEVELS2, @ar) <> 0 do  { find last levels }
          Inc(level);
      end;
      firstpart := False;
      Continue;
    end;
    lua_pushlstring(L, #10#9, 2);
    lua_getinfo(L1, 'Snl', @ar);
    lua_pushfstringf(L, '%s:', [PAnsiChar(@ar.short_src[0])]);
    if ar.currentline > 0 then
      lua_pushfstringf(L, '%d:', [ar.currentline]);
    if ar.namewhat^ <> #0 then  { is there a name? }
      lua_pushfstringf(L, ' in function ''%s''', [ar.name])
    else
    begin
      if ar.what^ = 'm' then  { main? }
        lua_pushfstringf(L, ' in main chunk', [])
      else if (ar.what^ = 'C') or (ar.what^ = 't') then
        lua_pushlstring(L, ' ?', 2)  { C function or tail call }
      else
        lua_pushfstringf(L, ' in function <%s:%d>', [PAnsiChar(@ar.short_src[0]), ar.linedefined]);
    end;
    lua_concat(L, lua_gettop(L) - arg);
  end;
  { the while loop in C increments `level' also when getstack fails }
  lua_concat(L, lua_gettop(L) - arg);
  Result := 1;
end;

const
  dblib: array[0..14] of luaL_Reg = (
    (name: 'debug'; func: db_debug),
    (name: 'getfenv'; func: db_getfenv),
    (name: 'gethook'; func: db_gethook),
    (name: 'getinfo'; func: db_getinfo),
    (name: 'getlocal'; func: db_getlocal),
    (name: 'getregistry'; func: db_getregistry),
    (name: 'getmetatable'; func: db_getmetatable),
    (name: 'getupvalue'; func: db_getupvalue),
    (name: 'setfenv'; func: db_setfenv),
    (name: 'sethook'; func: db_sethook),
    (name: 'setlocal'; func: db_setlocal),
    (name: 'setmetatable'; func: db_setmetatable),
    (name: 'setupvalue'; func: db_setupvalue),
    (name: 'traceback'; func: db_errorfb),
    (name: nil; func: nil));

function luaopen_debug(L: Plua_State): Integer; cdecl;
begin
  luaL_register(L, LUA_DBLIBNAME, @dblib[0]);
  Result := 1;
end;

end.
