{
  Lua 5.1.4 - Pascal port of lbaselib.c
  Basic library
}
unit LuaBaseLib;

{$I lua.inc}

interface

uses
  LuaTypes;

function luaopen_base(L: Plua_State): Integer; cdecl;

implementation

uses
  LuaCRT, LuaAPI, LuaAuxLib, LuaDebug, LuaDo, LuaState, LuaStdio;

{ If your system does not support `stdout', you can just remove this function.
  If you need, you can define your own `print' function, following this
  model but changing `fputs' to put the strings at a proper place
  (a console window or a log file, for instance). }
function luaB_print(L: Plua_State): Integer; cdecl;
var n, i: Integer; s: PAnsiChar;
begin
  n := lua_gettop(L);  { number of arguments }
  lua_getglobal(L, 'tostring');
  for i := 1 to n do
  begin
    lua_pushvalue(L, -1);  { function to be called }
    lua_pushvalue(L, i);  { value to print }
    lua_call(L, 1, 1);
    s := lua_tostring(L, -1);  { get result }
    if s = nil then
      Exit(luaL_errorf(L, '''tostring'' must return a string to ''print''', []));
    if i > 1 then c_fputs(#9, c_stdout);
    c_fputs(s, c_stdout);
    lua_pop(L, 1);  { pop result }
  end;
  c_fputs(#10, c_stdout);
  Result := 0;
end;

function luaB_tonumber(L: Plua_State): Integer; cdecl;
var base: Integer; s1, s2: PAnsiChar; n: c_ulong;
begin
  base := luaL_optint(L, 2, 10);
  if base = 10 then
  begin  { standard conversion }
    luaL_checkany(L, 1);
    if lua_isnumber(L, 1) <> 0 then
    begin
      lua_pushnumber(L, lua_tonumber(L, 1));
      Exit(1);
    end;
  end
  else
  begin
    s1 := luaL_checkstring(L, 1);
    luaL_argcheck(L, (2 <= base) and (base <= 36), 2, 'base out of range');
    n := c_strtoul(s1, @s2, base);
    if s1 <> s2 then
    begin  { at least one valid digit? }
      while c_isspace(Ord(s2^)) do Inc(s2);  { skip trailing spaces }
      if s2^ = #0 then
      begin  { no invalid trailing characters? }
        lua_pushnumber(L, n);
        Exit(1);
      end;
    end;
  end;
  lua_pushnil(L);  { else not a number }
  Result := 1;
end;

function luaB_error(L: Plua_State): Integer; cdecl;
var level: Integer;
begin
  level := luaL_optint(L, 2, 1);
  lua_settop(L, 1);
  if (lua_isstring(L, 1) <> 0) and (level > 0) then
  begin  { add extra information? }
    luaL_where(L, level);
    lua_pushvalue(L, 1);
    lua_concat(L, 2);
  end;
  Result := lua_error(L);
end;

function luaB_getmetatable(L: Plua_State): Integer; cdecl;
begin
  luaL_checkany(L, 1);
  if lua_getmetatable(L, 1) = 0 then
  begin
    lua_pushnil(L);
    Exit(1);  { no metatable }
  end;
  luaL_getmetafield(L, 1, '__metatable');
  Result := 1;  { returns either __metatable field (if present) or metatable }
end;

function luaB_setmetatable(L: Plua_State): Integer; cdecl;
var t: Integer;
begin
  t := lua_type(L, 2);
  luaL_checktype(L, 1, LUA_TTABLE);
  luaL_argcheck(L, (t = LUA_TNIL) or (t = LUA_TTABLE), 2, 'nil or table expected');
  if luaL_getmetafield(L, 1, '__metatable') <> 0 then
    luaL_errorf(L, 'cannot change a protected metatable', []);
  lua_settop(L, 2);
  lua_setmetatable(L, 1);
  Result := 1;
end;

procedure getfunc(L: Plua_State; opt: Boolean);
var ar: lua_Debug; level: Integer;
begin
  if lua_isfunction(L, 1) then lua_pushvalue(L, 1)
  else
  begin
    if opt then level := luaL_optint(L, 1, 1) else level := luaL_checkint(L, 1);
    luaL_argcheck(L, level >= 0, 1, 'level must be non-negative');
    if lua_getstack(L, level, @ar) = 0 then
      luaL_argerror(L, 1, 'invalid level');
    lua_getinfo(L, 'f', @ar);
    if lua_isnil(L, -1) then
      luaL_errorf(L, 'no function environment for tail call at level %d', [level]);
  end;
end;

function luaB_getfenv(L: Plua_State): Integer; cdecl;
begin
  getfunc(L, True);
  if lua_iscfunction(L, -1) <> 0 then  { is a C function? }
    lua_pushvalue(L, LUA_GLOBALSINDEX)  { return the thread's global env. }
  else
    lua_getfenv(L, -1);
  Result := 1;
end;

function luaB_setfenv(L: Plua_State): Integer; cdecl;
begin
  luaL_checktype(L, 2, LUA_TTABLE);
  getfunc(L, False);
  lua_pushvalue(L, 2);
  if (lua_isnumber(L, 1) <> 0) and luai_numeq(lua_tonumber(L, 1), 0) then
  begin
    { change environment of current thread }
    lua_pushthread(L);
    lua_insert(L, -2);
    lua_setfenv(L, -2);
    Exit(0);
  end
  else if (lua_iscfunction(L, -2) <> 0) or (lua_setfenv(L, -2) = 0) then
    luaL_errorf(L, '''setfenv'' cannot change environment of given object', []);
  Result := 1;
end;

function luaB_rawequal(L: Plua_State): Integer; cdecl;
begin
  luaL_checkany(L, 1);
  luaL_checkany(L, 2);
  lua_pushboolean(L, lua_rawequal(L, 1, 2));
  Result := 1;
end;

function luaB_rawget(L: Plua_State): Integer; cdecl;
begin
  luaL_checktype(L, 1, LUA_TTABLE);
  luaL_checkany(L, 2);
  lua_settop(L, 2);
  lua_rawget(L, 1);
  Result := 1;
end;

function luaB_rawset(L: Plua_State): Integer; cdecl;
begin
  luaL_checktype(L, 1, LUA_TTABLE);
  luaL_checkany(L, 2);
  luaL_checkany(L, 3);
  lua_settop(L, 3);
  lua_rawset(L, 1);
  Result := 1;
end;

function luaB_gcinfo(L: Plua_State): Integer; cdecl;
begin
  lua_pushinteger(L, lua_gc(L, LUA_GCCOUNT, 0));
  Result := 1;
end;

const
  gc_opts: array[0..7] of PAnsiChar = ('stop', 'restart', 'collect',
    'count', 'step', 'setpause', 'setstepmul', nil);
  gc_optsnum: array[0..6] of Integer = (LUA_GCSTOP, LUA_GCRESTART, LUA_GCCOLLECT,
    LUA_GCCOUNT, LUA_GCSTEP, LUA_GCSETPAUSE, LUA_GCSETSTEPMUL);

function luaB_collectgarbage(L: Plua_State): Integer; cdecl;
var o, ex, res, b: Integer;
begin
  o := luaL_checkoption(L, 1, 'collect', @gc_opts[0]);
  ex := luaL_optint(L, 2, 0);
  res := lua_gc(L, gc_optsnum[o], ex);
  case gc_optsnum[o] of
    LUA_GCCOUNT:
      begin
        b := lua_gc(L, LUA_GCCOUNTB, 0);
        lua_pushnumber(L, res + (b / 1024));
      end;
    LUA_GCSTEP:
      lua_pushboolean(L, res);
  else
    lua_pushnumber(L, res);
  end;
  Result := 1;
end;

function luaB_type(L: Plua_State): Integer; cdecl;
begin
  luaL_checkany(L, 1);
  lua_pushstring(L, luaL_typename(L, 1));
  Result := 1;
end;

function luaB_next(L: Plua_State): Integer; cdecl;
begin
  luaL_checktype(L, 1, LUA_TTABLE);
  lua_settop(L, 2);  { create a 2nd argument if there isn't one }
  if lua_next(L, 1) <> 0 then
    Result := 2
  else
  begin
    lua_pushnil(L);
    Result := 1;
  end;
end;

function luaB_pairs(L: Plua_State): Integer; cdecl;
begin
  luaL_checktype(L, 1, LUA_TTABLE);
  lua_pushvalue(L, lua_upvalueindex(1));  { return generator, }
  lua_pushvalue(L, 1);  { state, }
  lua_pushnil(L);  { and initial value }
  Result := 3;
end;

function ipairsaux(L: Plua_State): Integer; cdecl;
var i: Integer;
begin
  i := luaL_checkint(L, 2);
  luaL_checktype(L, 1, LUA_TTABLE);
  Inc(i);  { next value }
  lua_pushinteger(L, i);
  lua_rawgeti(L, 1, i);
  if lua_isnil(L, -1) then Result := 0 else Result := 2;
end;

function luaB_ipairs(L: Plua_State): Integer; cdecl;
begin
  luaL_checktype(L, 1, LUA_TTABLE);
  lua_pushvalue(L, lua_upvalueindex(1));  { return generator, }
  lua_pushvalue(L, 1);  { state, }
  lua_pushinteger(L, 0);  { and initial value }
  Result := 3;
end;

function load_aux(L: Plua_State; status: Integer): Integer;
begin
  if status = 0 then  { OK? }
    Result := 1
  else
  begin
    lua_pushnil(L);
    lua_insert(L, -2);  { put before error message }
    Result := 2;  { return nil plus error message }
  end;
end;

function luaB_loadstring(L: Plua_State): Integer; cdecl;
var len: size_t; s, chunkname: PAnsiChar;
begin
  s := luaL_checklstring(L, 1, @len);
  chunkname := luaL_optstring(L, 2, s);
  Result := load_aux(L, luaL_loadbuffer(L, s, len, chunkname));
end;

function luaB_loadfile(L: Plua_State): Integer; cdecl;
var fname: PAnsiChar;
begin
  fname := luaL_optstring(L, 1, nil);
  Result := load_aux(L, luaL_loadfile(L, fname));
end;

{ Reader for generic `load' function: `lua_load' uses the
  stack for internal stuff, so the reader cannot change the
  stack top. Instead, it keeps its resulting string in a
  reserved slot inside the stack. }
function generic_reader(L: Plua_State; ud: Pointer; size: Psize_t): PAnsiChar; cdecl;
begin
  luaL_checkstack(L, 2, 'too many nested functions');
  lua_pushvalue(L, 1);  { get function }
  lua_call(L, 0, 1);  { call it }
  if lua_isnil(L, -1) then
  begin
    size^ := 0;
    Result := nil;
  end
  else if lua_isstring(L, -1) <> 0 then
  begin
    lua_replace(L, 3);  { save string in a reserved stack slot }
    Result := lua_tolstring(L, 3, size);
  end
  else
  begin
    luaL_errorf(L, 'reader function must return a string', []);
    Result := nil;  { to avoid warnings }
  end;
end;

function luaB_load(L: Plua_State): Integer; cdecl;
var status: Integer; cname: PAnsiChar;
begin
  cname := luaL_optstring(L, 2, '=(load)');
  luaL_checktype(L, 1, LUA_TFUNCTION);
  lua_settop(L, 3);  { function, eventual name, plus one reserved slot }
  status := lua_load(L, generic_reader, nil, cname);
  Result := load_aux(L, status);
end;

function luaB_dofile(L: Plua_State): Integer; cdecl;
var fname: PAnsiChar; n: Integer;
begin
  fname := luaL_optstring(L, 1, nil);
  n := lua_gettop(L);
  if luaL_loadfile(L, fname) <> 0 then lua_error(L);
  lua_call(L, 0, LUA_MULTRET);
  Result := lua_gettop(L) - n;
end;

function luaB_assert(L: Plua_State): Integer; cdecl;
begin
  luaL_checkany(L, 1);
  if lua_toboolean(L, 1) = 0 then
    Exit(luaL_errorf(L, '%s', [luaL_optstring(L, 2, 'assertion failed!')]));
  Result := lua_gettop(L);
end;

function luaB_unpack(L: Plua_State): Integer; cdecl;
var i, e, n: Integer;
begin
  luaL_checktype(L, 1, LUA_TTABLE);
  i := luaL_optint(L, 2, 1);
  if lua_isnoneornil(L, 3) then e := luaL_getn(L, 1) else e := luaL_checkint(L, 3);
  if i > e then Exit(0);  { empty range }
  n := e - i + 1;  { number of elements }
  if (n <= 0) or (lua_checkstack(L, n) = 0) then  { n <= 0 means arith. overflow }
    Exit(luaL_errorf(L, 'too many results to unpack', []));
  lua_rawgeti(L, 1, i);  { push arg[i] (avoiding overflow problems) }
  while i < e do  { push arg[i + 1...e] }
  begin
    Inc(i);
    lua_rawgeti(L, 1, i);
  end;
  Result := n;
end;

function luaB_select(L: Plua_State): Integer; cdecl;
var n, i: Integer;
begin
  n := lua_gettop(L);
  if (lua_type(L, 1) = LUA_TSTRING) and (lua_tostring(L, 1)^ = '#') then
  begin
    lua_pushinteger(L, n - 1);
    Result := 1;
  end
  else
  begin
    i := luaL_checkint(L, 1);
    if i < 0 then i := n + i
    else if i > n then i := n;
    luaL_argcheck(L, 1 <= i, 1, 'index out of range');
    Result := n - i;
  end;
end;

function luaB_pcall(L: Plua_State): Integer; cdecl;
var status: Integer;
begin
  luaL_checkany(L, 1);
  status := lua_pcall(L, lua_gettop(L) - 1, LUA_MULTRET, 0);
  lua_pushboolean(L, Ord(status = 0));
  lua_insert(L, 1);
  Result := lua_gettop(L);  { return status + all results }
end;

function luaB_xpcall(L: Plua_State): Integer; cdecl;
var status: Integer;
begin
  luaL_checkany(L, 2);
  lua_settop(L, 2);
  lua_insert(L, 1);  { put error function under function to be called }
  status := lua_pcall(L, 0, LUA_MULTRET, 1);
  lua_pushboolean(L, Ord(status = 0));
  lua_replace(L, 1);
  Result := lua_gettop(L);  { return status + all results }
end;

function luaB_tostring(L: Plua_State): Integer; cdecl;
begin
  luaL_checkany(L, 1);
  if luaL_callmeta(L, 1, '__tostring') <> 0 then  { is there a metafield? }
    Exit(1);  { use its value }
  case lua_type(L, 1) of
    LUA_TNUMBER:
      lua_pushstring(L, lua_tostring(L, 1));
    LUA_TSTRING:
      lua_pushvalue(L, 1);
    LUA_TBOOLEAN:
      if lua_toboolean(L, 1) <> 0 then lua_pushstring(L, 'true')
      else lua_pushstring(L, 'false');
    LUA_TNIL:
      lua_pushlstring(L, 'nil', 3);
  else
    lua_pushfstringf(L, '%s: %p', [luaL_typename(L, 1), lua_topointer(L, 1)]);
  end;
  Result := 1;
end;

function luaB_newproxy(L: Plua_State): Integer; cdecl;
var validproxy: Integer;
begin
  lua_settop(L, 1);
  lua_newuserdata(L, 0);  { create proxy }
  if lua_toboolean(L, 1) = 0 then
    Exit(1)  { no metatable }
  else if lua_isboolean(L, 1) then
  begin
    lua_newtable(L);  { create a new metatable `m' ... }
    lua_pushvalue(L, -1);  { ... and mark `m' as a valid metatable }
    lua_pushboolean(L, 1);
    lua_rawset(L, lua_upvalueindex(1));  { weaktable[m] = true }
  end
  else
  begin
    validproxy := 0;  { to check if weaktable[metatable(u)] == true }
    if lua_getmetatable(L, 1) <> 0 then
    begin
      lua_rawget(L, lua_upvalueindex(1));
      validproxy := lua_toboolean(L, -1);
      lua_pop(L, 1);  { remove value }
    end;
    luaL_argcheck(L, validproxy <> 0, 1, 'boolean or proxy expected');
    lua_getmetatable(L, 1);  { metatable is valid; get it }
  end;
  lua_setmetatable(L, 2);
  Result := 1;
end;

const
  base_funcs: array[0..24] of luaL_Reg = (
    (name: 'assert'; func: luaB_assert),
    (name: 'collectgarbage'; func: luaB_collectgarbage),
    (name: 'dofile'; func: luaB_dofile),
    (name: 'error'; func: luaB_error),
    (name: 'gcinfo'; func: luaB_gcinfo),
    (name: 'getfenv'; func: luaB_getfenv),
    (name: 'getmetatable'; func: luaB_getmetatable),
    (name: 'loadfile'; func: luaB_loadfile),
    (name: 'load'; func: luaB_load),
    (name: 'loadstring'; func: luaB_loadstring),
    (name: 'next'; func: luaB_next),
    (name: 'pcall'; func: luaB_pcall),
    (name: 'print'; func: luaB_print),
    (name: 'rawequal'; func: luaB_rawequal),
    (name: 'rawget'; func: luaB_rawget),
    (name: 'rawset'; func: luaB_rawset),
    (name: 'select'; func: luaB_select),
    (name: 'setfenv'; func: luaB_setfenv),
    (name: 'setmetatable'; func: luaB_setmetatable),
    (name: 'tonumber'; func: luaB_tonumber),
    (name: 'tostring'; func: luaB_tostring),
    (name: 'type'; func: luaB_type),
    (name: 'unpack'; func: luaB_unpack),
    (name: 'xpcall'; func: luaB_xpcall),
    (name: nil; func: nil));

{ ======================================================
  Coroutine library
  ======================================================= }

const
  CO_RUN = 0;  { running }
  CO_SUS = 1;  { suspended }
  CO_NOR = 2;  { 'normal' (it resumed another coroutine) }
  CO_DEAD = 3;

  statnames: array[0..3] of PAnsiChar = ('running', 'suspended', 'normal', 'dead');

function costatus(L, co: Plua_State): Integer;
var ar: lua_Debug;
begin
  if L = co then Exit(CO_RUN);
  case lua_status(co) of
    LUA_YIELD_:
      Result := CO_SUS;
    0:
      begin
        if lua_getstack(co, 0, @ar) > 0 then  { does it have frames? }
          Result := CO_NOR  { it is running }
        else if lua_gettop(co) = 0 then
          Result := CO_DEAD
        else
          Result := CO_SUS;  { initial state }
      end;
  else  { some error occured }
    Result := CO_DEAD;
  end;
end;

function luaB_costatus(L: Plua_State): Integer; cdecl;
var co: Plua_State;
begin
  co := lua_tothread(L, 1);
  luaL_argcheck(L, co <> nil, 1, 'coroutine expected');
  lua_pushstring(L, statnames[costatus(L, co)]);
  Result := 1;
end;

function auxresume(L, co: Plua_State; narg: Integer): Integer;
var status, nres: Integer;
begin
  status := costatus(L, co);
  if lua_checkstack(co, narg) = 0 then
    luaL_errorf(L, 'too many arguments to resume', []);
  if status <> CO_SUS then
  begin
    lua_pushfstringf(L, 'cannot resume %s coroutine', [statnames[status]]);
    Exit(-1);  { error flag }
  end;
  lua_xmove(L, co, narg);
  lua_setlevel(L, co);
  status := lua_resume(co, narg);
  if (status = 0) or (status = LUA_YIELD_) then
  begin
    nres := lua_gettop(co);
    if lua_checkstack(L, nres + 1) = 0 then
      luaL_errorf(L, 'too many results to resume', []);
    lua_xmove(co, L, nres);  { move yielded values }
    Result := nres;
  end
  else
  begin
    lua_xmove(co, L, 1);  { move error message }
    Result := -1;  { error flag }
  end;
end;

function luaB_coresume(L: Plua_State): Integer; cdecl;
var co: Plua_State; r: Integer;
begin
  co := lua_tothread(L, 1);
  luaL_argcheck(L, co <> nil, 1, 'coroutine expected');
  r := auxresume(L, co, lua_gettop(L) - 1);
  if r < 0 then
  begin
    lua_pushboolean(L, 0);
    lua_insert(L, -2);
    Result := 2;  { return false + error message }
  end
  else
  begin
    lua_pushboolean(L, 1);
    lua_insert(L, -(r + 1));
    Result := r + 1;  { return true + `resume' returns }
  end;
end;

function luaB_auxwrap(L: Plua_State): Integer; cdecl;
var co: Plua_State; r: Integer;
begin
  co := lua_tothread(L, lua_upvalueindex(1));
  r := auxresume(L, co, lua_gettop(L));
  if r < 0 then
  begin
    if lua_isstring(L, -1) <> 0 then
    begin  { error object is a string? }
      luaL_where(L, 1);  { get extra info }
      lua_insert(L, -2);
      lua_concat(L, 2);
    end;
    lua_error(L);  { propagate error }
  end;
  Result := r;
end;

function luaB_cocreate(L: Plua_State): Integer; cdecl;
var NL: Plua_State;
begin
  NL := lua_newthread(L);
  luaL_argcheck(L, lua_isfunction(L, 1) and (lua_iscfunction(L, 1) = 0), 1,
    'Lua function expected');
  lua_pushvalue(L, 1);  { move function to top }
  lua_xmove(L, NL, 1);  { move function from L to NL }
  Result := 1;
end;

function luaB_cowrap(L: Plua_State): Integer; cdecl;
begin
  luaB_cocreate(L);
  lua_pushcclosure(L, luaB_auxwrap, 1);
  Result := 1;
end;

function luaB_yield(L: Plua_State): Integer; cdecl;
begin
  Result := lua_yield(L, lua_gettop(L));
end;

function luaB_corunning(L: Plua_State): Integer; cdecl;
begin
  if lua_pushthread(L) <> 0 then
    lua_pushnil(L);  { main thread is not a coroutine }
  Result := 1;
end;

const
  co_funcs: array[0..6] of luaL_Reg = (
    (name: 'create'; func: luaB_cocreate),
    (name: 'resume'; func: luaB_coresume),
    (name: 'running'; func: luaB_corunning),
    (name: 'status'; func: luaB_costatus),
    (name: 'wrap'; func: luaB_cowrap),
    (name: 'yield'; func: luaB_yield),
    (name: nil; func: nil));

procedure auxopen(L: Plua_State; name: PAnsiChar; f, u: lua_CFunction);
begin
  lua_pushcfunction(L, u);
  lua_pushcclosure(L, f, 1);
  lua_setfield(L, -2, name);
end;

procedure base_open(L: Plua_State);
begin
  { set global _G }
  lua_pushvalue(L, LUA_GLOBALSINDEX);
  lua_setglobal(L, '_G');
  { open lib into global table }
  luaL_register(L, '_G', @base_funcs[0]);
  lua_pushlstring(L, LUA_VERSION, Length(LUA_VERSION));
  lua_setglobal(L, '_VERSION');  { set global _VERSION }
  { `ipairs' and `pairs' need auxliary functions as upvalues }
  auxopen(L, 'ipairs', luaB_ipairs, ipairsaux);
  auxopen(L, 'pairs', luaB_pairs, luaB_next);
  { `newproxy' needs a weaktable as upvalue }
  lua_createtable(L, 0, 1);  { new table `w' }
  lua_pushvalue(L, -1);  { `w' will be its own metatable }
  lua_setmetatable(L, -2);
  lua_pushlstring(L, 'kv', 2);
  lua_setfield(L, -2, '__mode');  { metatable(w).__mode = "kv" }
  lua_pushcclosure(L, luaB_newproxy, 1);
  lua_setglobal(L, 'newproxy');  { set global `newproxy' }
end;

function luaopen_base(L: Plua_State): Integer; cdecl;
begin
  base_open(L);
  luaL_register(L, LUA_COLIBNAME, @co_funcs[0]);
  Result := 2;
end;

end.
