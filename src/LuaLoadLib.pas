{
  Lua 5.1.4 - Pascal port of loadlib.c
  Dynamic library loader for Lua (Windows DLL implementation)
}
unit LuaLoadLib;

{$I lua.inc}

interface

uses
  LuaTypes;

function luaopen_package(L: Plua_State): Integer; cdecl;

implementation

uses
  LuaCRT, LuaAPI, LuaAuxLib, LuaDebug, LuaStdio,
  {$IFDEF LUA_POSIX} LuaPosix {$ELSE} LuaWin {$ENDIF};

const
  LUA_POF = 'luaopen_';
  LUA_OFSEP = '_';
  LIBPREFIX = 'LOADLIB: ';
  POF = LUA_POF;
  LIB_FAIL = 'open';
  ERRLIB = 1;
  ERRFUNC = 2;
  MAX_PATH = 260;

{$IFDEF LUA_POSIX}
{ ======================================================================
  dlopen (LUA_DL_DLOPEN)
  ====================================================================== }

procedure setprogdir(L: Plua_State);
begin
  { only Windows replaces LUA_EXECDIR by the executable's directory }
end;

procedure ll_unloadlib(lib: Pointer);
begin
  px_dlclose(lib);
end;

function ll_load(L: Plua_State; path: PAnsiChar): Pointer;
begin
  Result := px_dlopen(path, RTLD_NOW);
  if Result = nil then lua_pushstring(L, px_dlerror);
end;

function ll_sym(L: Plua_State; lib: Pointer; sym: PAnsiChar): lua_CFunction;
var f: Pointer;
begin
  f := px_dlsym(lib, sym);
  if f = nil then lua_pushstring(L, px_dlerror);
  Result := lua_CFunction(f);
end;

{$ELSE}
procedure setprogdir(L: Plua_State);
var buff: array[0..MAX_PATH] of AnsiChar; lb, p: PAnsiChar; nsize, n: DWORD;
begin
  nsize := SizeOf(buff);
  n := GetModuleFileNameA(0, @buff[0], nsize);
  lb := nil;
  if (n <> 0) and (n <> nsize) then
  begin
    p := @buff[0];
    while p^ <> #0 do
    begin
      if p^ = '\' then lb := p;
      Inc(p);
    end;
  end;
  if lb = nil then
    luaL_errorf(L, 'unable to get ModuleFileName', [])
  else
  begin
    lb^ := #0;
    luaL_gsub(L, lua_tostring(L, -1), LUA_EXECDIR, @buff[0]);
    lua_remove(L, -2);  { remove original string }
  end;
end;

procedure pusherror(L: Plua_State);
var error: DWORD; buffer: array[0..127] of AnsiChar;
begin
  error := GetLastError;
  if FormatMessageA(FORMAT_MESSAGE_IGNORE_INSERTS or FORMAT_MESSAGE_FROM_SYSTEM,
       nil, error, 0, @buffer[0], SizeOf(buffer), nil) <> 0 then
    lua_pushstring(L, @buffer[0])
  else
    lua_pushfstringf(L, 'system error %d'#10, [Integer(error)]);
end;

procedure ll_unloadlib(lib: Pointer);
begin
  FreeLibrary(HMODULE(lib));
end;

function ll_load(L: Plua_State; path: PAnsiChar): Pointer;
var lib: HMODULE;
begin
  lib := LoadLibraryA(path);
  if lib = 0 then pusherror(L);
  Result := Pointer(lib);
end;

function ll_sym(L: Plua_State; lib: Pointer; sym: PAnsiChar): lua_CFunction;
var f: Pointer;
begin
  f := GetProcAddress(HMODULE(lib), sym);
  if f = nil then pusherror(L);
  Result := lua_CFunction(f);
end;

{$ENDIF}

function ll_register(L: Plua_State; path: PAnsiChar): PPointer;
var plib: PPointer;
begin
  lua_pushfstringf(L, '%s%s', [LIBPREFIX, path]);
  lua_gettable(L, LUA_REGISTRYINDEX);  { check library in registry? }
  if not lua_isnil(L, -1) then  { is there an entry? }
    plib := PPointer(lua_touserdata(L, -1))
  else
  begin  { no entry yet; create one }
    lua_pop(L, 1);
    plib := PPointer(lua_newuserdata(L, SizeOf(Pointer)));
    plib^ := nil;
    luaL_getmetatable(L, '_LOADLIB');
    lua_setmetatable(L, -2);
    lua_pushfstringf(L, '%s%s', [LIBPREFIX, path]);
    lua_pushvalue(L, -2);
    lua_settable(L, LUA_REGISTRYINDEX);
  end;
  Result := plib;
end;

{ __gc tag method: calls library's `ll_unloadlib' function with the lib
  handle }
function gctm(L: Plua_State): Integer; cdecl;
var lib: PPointer;
begin
  lib := PPointer(luaL_checkudata(L, 1, '_LOADLIB'));
  if lib^ <> nil then ll_unloadlib(lib^);
  lib^ := nil;  { mark library as closed }
  Result := 0;
end;

function ll_loadfunc(L: Plua_State; path, sym: PAnsiChar): Integer;
var reg: PPointer; f: lua_CFunction;
begin
  reg := ll_register(L, path);
  if reg^ = nil then reg^ := ll_load(L, path);
  if reg^ = nil then
    Result := ERRLIB  { unable to load library }
  else
  begin
    f := ll_sym(L, reg^, sym);
    if not Assigned(f) then
      Exit(ERRFUNC);  { unable to find function }
    lua_pushcfunction(L, f);
    Result := 0;  { return function }
  end;
end;

function ll_loadlib(L: Plua_State): Integer; cdecl;
var path, init: PAnsiChar; stat: Integer;
begin
  path := luaL_checkstring(L, 1);
  init := luaL_checkstring(L, 2);
  stat := ll_loadfunc(L, path, init);
  if stat = 0 then  { no errors? }
    Result := 1  { return the loaded function }
  else
  begin  { error; error message is on stack top }
    lua_pushnil(L);
    lua_insert(L, -2);
    if stat = ERRLIB then lua_pushstring(L, LIB_FAIL) else lua_pushstring(L, 'init');
    Result := 3;  { return nil, error message, and where }
  end;
end;

{ ======================================================
  'require' function
  ======================================================= }

function readable(filename: PAnsiChar): Boolean;
var f: PCFile;
begin
  f := c_fopen(filename, 'r');  { try to open file }
  if f = nil then Exit(False);  { open failed }
  c_fclose(f);
  Result := True;
end;

function pushnexttemplate(L: Plua_State; path: PAnsiChar): PAnsiChar;
var l_: PAnsiChar;
begin
  while path^ = LUA_PATHSEP do Inc(path);  { skip separators }
  if path^ = #0 then Exit(nil);  { no more templates }
  l_ := c_strchr(path, Ord(LUA_PATHSEP));  { find next separator }
  if l_ = nil then l_ := path + c_strlen(path);
  lua_pushlstring(L, path, l_ - path);  { template }
  Result := l_;
end;

function findfile(L: Plua_State; name, pname: PAnsiChar): PAnsiChar;
var path, filename: PAnsiChar;
begin
  name := luaL_gsub(L, name, '.', LUA_DIRSEP);
  lua_getfield(L, LUA_ENVIRONINDEX, pname);
  path := lua_tostring(L, -1);
  if path = nil then
    luaL_errorf(L, '''package.%s'' must be a string', [pname]);
  lua_pushlstring(L, '', 0);  { error accumulator }
  while True do
  begin
    path := pushnexttemplate(L, path);
    if path = nil then Break;
    filename := luaL_gsub(L, lua_tostring(L, -1), LUA_PATH_MARK, name);
    lua_remove(L, -2);  { remove path template }
    if readable(filename) then  { does file exist and is readable? }
      Exit(filename);  { return that file name }
    lua_pushfstringf(L, #10#9'no file ''%s''', [filename]);
    lua_remove(L, -2);  { remove file name }
    lua_concat(L, 2);  { add entry to possible error message }
  end;
  Result := nil;  { not found }
end;

procedure loaderror(L: Plua_State; filename: PAnsiChar);
begin
  luaL_errorf(L, 'error loading module ''%s'' from file ''%s'':'#10#9'%s',
              [lua_tostring(L, 1), filename, lua_tostring(L, -1)]);
end;

function loader_Lua(L: Plua_State): Integer; cdecl;
var filename, name: PAnsiChar;
begin
  name := luaL_checkstring(L, 1);
  filename := findfile(L, name, 'path');
  if filename = nil then Exit(1);  { library not found in this path }
  if luaL_loadfile(L, filename) <> 0 then
    loaderror(L, filename);
  Result := 1;  { library loaded successfully }
end;

function mkfuncname(L: Plua_State; modname: PAnsiChar): PAnsiChar;
var funcname, mark: PAnsiChar;
begin
  mark := c_strchr(modname, Ord(LUA_IGMARK));
  if mark <> nil then modname := mark + 1;
  funcname := luaL_gsub(L, modname, '.', LUA_OFSEP);
  funcname := lua_pushfstringf(L, POF + '%s', [funcname]);
  lua_remove(L, -2);  { remove 'gsub' result }
  Result := funcname;
end;

function loader_C(L: Plua_State): Integer; cdecl;
var funcname, name, filename: PAnsiChar;
begin
  name := luaL_checkstring(L, 1);
  filename := findfile(L, name, 'cpath');
  if filename = nil then Exit(1);  { library not found in this path }
  funcname := mkfuncname(L, name);
  if ll_loadfunc(L, filename, funcname) <> 0 then
    loaderror(L, filename);
  Result := 1;  { library loaded successfully }
end;

function loader_Croot(L: Plua_State): Integer; cdecl;
var funcname, filename, name, p: PAnsiChar; stat: Integer;
begin
  name := luaL_checkstring(L, 1);
  p := c_strchr(name, Ord('.'));
  if p = nil then Exit(0);  { is root }
  lua_pushlstring(L, name, p - name);
  filename := findfile(L, lua_tostring(L, -1), 'cpath');
  if filename = nil then Exit(1);  { root not found }
  funcname := mkfuncname(L, name);
  stat := ll_loadfunc(L, filename, funcname);
  if stat <> 0 then
  begin
    if stat <> ERRFUNC then loaderror(L, filename);  { real error }
    lua_pushfstringf(L, #10#9'no module ''%s'' in file ''%s''', [name, filename]);
    Exit(1);  { function not found }
  end;
  Result := 1;
end;

function loader_preload(L: Plua_State): Integer; cdecl;
var name: PAnsiChar;
begin
  name := luaL_checkstring(L, 1);
  lua_getfield(L, LUA_ENVIRONINDEX, 'preload');
  if not lua_istable(L, -1) then
    luaL_errorf(L, '''package.preload'' must be a table', []);
  lua_getfield(L, -1, name);
  if lua_isnil(L, -1) then  { not found? }
    lua_pushfstringf(L, #10#9'no field package.preload[''%s'']', [name]);
  Result := 1;
end;

var
  sentinel_: Integer = 0;

function sentinel: Pointer; inline;
begin
  Result := @sentinel_;
end;

function ll_require(L: Plua_State): Integer; cdecl;
var name: PAnsiChar; i: Integer;
begin
  name := luaL_checkstring(L, 1);
  lua_settop(L, 1);  { _LOADED table will be at index 2 }
  lua_getfield(L, LUA_REGISTRYINDEX, '_LOADED');
  lua_getfield(L, 2, name);
  if lua_toboolean(L, -1) <> 0 then
  begin  { is it there? }
    if lua_touserdata(L, -1) = sentinel then  { check loops }
      luaL_errorf(L, 'loop or previous error loading module ''%s''', [name]);
    Exit(1);  { package is already loaded }
  end;
  { else must load it; iterate over available loaders }
  lua_getfield(L, LUA_ENVIRONINDEX, 'loaders');
  if not lua_istable(L, -1) then
    luaL_errorf(L, '''package.loaders'' must be a table', []);
  lua_pushlstring(L, '', 0);  { error message accumulator }
  i := 1;
  while True do
  begin
    lua_rawgeti(L, -2, i);  { get a loader }
    if lua_isnil(L, -1) then
      luaL_errorf(L, 'module ''%s'' not found:%s', [name, lua_tostring(L, -2)]);
    lua_pushstring(L, name);
    lua_call(L, 1, 1);  { call it }
    if lua_isfunction(L, -1) then  { did it find module? }
      Break  { module loaded successfully }
    else if lua_isstring(L, -1) <> 0 then  { loader returned error message? }
      lua_concat(L, 2)  { accumulate it }
    else
      lua_pop(L, 1);
    Inc(i);
  end;
  lua_pushlightuserdata(L, sentinel);
  lua_setfield(L, 2, name);  { _LOADED[name] = sentinel }
  lua_pushstring(L, name);  { pass name as argument to module }
  lua_call(L, 1, 1);  { run loaded module }
  if not lua_isnil(L, -1) then  { non-nil return? }
    lua_setfield(L, 2, name);  { _LOADED[name] = returned value }
  lua_getfield(L, 2, name);
  if lua_touserdata(L, -1) = sentinel then
  begin  { module did not set a value? }
    lua_pushboolean(L, 1);  { use true as result }
    lua_pushvalue(L, -1);  { extra copy to be returned }
    lua_setfield(L, 2, name);  { _LOADED[name] = true }
  end;
  Result := 1;
end;

{ ======================================================
  'module' function
  ======================================================= }

procedure setfenv_(L: Plua_State);
var ar: lua_Debug;
begin
  if (lua_getstack(L, 1, @ar) = 0) or
     (lua_getinfo(L, 'f', @ar) = 0) or  { get calling function }
     (lua_iscfunction(L, -1) <> 0) then
    luaL_errorf(L, '''module'' not called from a Lua function', []);
  lua_pushvalue(L, -2);
  lua_setfenv(L, -2);
  lua_pop(L, 1);
end;

procedure dooptions(L: Plua_State; n: Integer);
var i: Integer;
begin
  for i := 2 to n do
  begin
    lua_pushvalue(L, i);  { get option (a function) }
    lua_pushvalue(L, -2);  { module }
    lua_call(L, 1, 0);
  end;
end;

procedure modinit(L: Plua_State; modname: PAnsiChar);
var dot, p: PAnsiChar;
begin
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, '_M');  { module._M = module }
  lua_pushstring(L, modname);
  lua_setfield(L, -2, '_NAME');
  dot := nil;  { strrchr(modname, '.') }
  p := modname;
  while p^ <> #0 do
  begin
    if p^ = '.' then dot := p;
    Inc(p);
  end;
  if dot = nil then dot := modname
  else Inc(dot);
  { set _PACKAGE as package name (full module name minus last part) }
  lua_pushlstring(L, modname, dot - modname);
  lua_setfield(L, -2, '_PACKAGE');
end;

function ll_module(L: Plua_State): Integer; cdecl;
var modname: PAnsiChar; loaded: Integer;
begin
  modname := luaL_checkstring(L, 1);
  loaded := lua_gettop(L) + 1;  { index of _LOADED table }
  lua_getfield(L, LUA_REGISTRYINDEX, '_LOADED');
  lua_getfield(L, loaded, modname);  { get _LOADED[modname] }
  if not lua_istable(L, -1) then
  begin  { not found? }
    lua_pop(L, 1);  { remove previous result }
    { try global variable (and create one if it does not exist) }
    if luaL_findtable(L, LUA_GLOBALSINDEX, modname, 1) <> nil then
      Exit(luaL_errorf(L, 'name conflict for module ''%s''', [modname]));
    lua_pushvalue(L, -1);
    lua_setfield(L, loaded, modname);  { _LOADED[modname] = new table }
  end;
  { check whether table already has a _NAME field }
  lua_getfield(L, -1, '_NAME');
  if not lua_isnil(L, -1) then  { is table an initialized module? }
    lua_pop(L, 1)
  else
  begin  { no; initialize it }
    lua_pop(L, 1);
    modinit(L, modname);
  end;
  lua_pushvalue(L, -1);
  setfenv_(L);
  dooptions(L, loaded - 1);
  Result := 0;
end;

function ll_seeall(L: Plua_State): Integer; cdecl;
begin
  luaL_checktype(L, 1, LUA_TTABLE);
  if lua_getmetatable(L, 1) = 0 then
  begin
    lua_createtable(L, 0, 1);  { create new metatable }
    lua_pushvalue(L, -1);
    lua_setmetatable(L, 1);
  end;
  lua_pushvalue(L, LUA_GLOBALSINDEX);
  lua_setfield(L, -2, '__index');  { mt.__index = _G }
  Result := 0;
end;

{ ====================================================== }

const
  AUXMARK = #1;

procedure setpath(L: Plua_State; fieldname, envname, def: PAnsiChar);
var path: PAnsiChar;
begin
  path := c_getenv(envname);
  if path = nil then  { no environment variable? }
    lua_pushstring(L, def)  { use default }
  else
  begin
    { replace ";;" by ";AUXMARK;" and then AUXMARK by default path }
    path := luaL_gsub(L, path, LUA_PATHSEP + LUA_PATHSEP, LUA_PATHSEP + AUXMARK + LUA_PATHSEP);
    luaL_gsub(L, path, AUXMARK, def);
    lua_remove(L, -2);
  end;
  setprogdir(L);
  lua_setfield(L, -2, fieldname);
end;

const
  pk_funcs: array[0..2] of luaL_Reg = (
    (name: 'loadlib'; func: ll_loadlib),
    (name: 'seeall'; func: ll_seeall),
    (name: nil; func: nil));

  ll_funcs: array[0..2] of luaL_Reg = (
    (name: 'module'; func: ll_module),
    (name: 'require'; func: ll_require),
    (name: nil; func: nil));

  loaders: array[0..4] of lua_CFunction =
    (loader_preload, loader_Lua, loader_C, loader_Croot, nil);

function luaopen_package(L: Plua_State): Integer; cdecl;
var i: Integer;
begin
  { create new type _LOADLIB }
  luaL_newmetatable(L, '_LOADLIB');
  lua_pushcfunction(L, gctm);
  lua_setfield(L, -2, '__gc');
  { create `package' table }
  luaL_register(L, LUA_LOADLIBNAME, @pk_funcs[0]);
  lua_pushvalue(L, -1);
  lua_replace(L, LUA_ENVIRONINDEX);
  { create `loaders' table }
  lua_createtable(L, 0, Length(loaders) - 1);
  { fill it with pre-defined loaders }
  i := 0;
  while Assigned(loaders[i]) do
  begin
    lua_pushcfunction(L, loaders[i]);
    lua_rawseti(L, -2, i + 1);
    Inc(i);
  end;
  lua_setfield(L, -2, 'loaders');  { put it in field `loaders' }
  setpath(L, 'path', LUA_PATH_ENV, LUA_PATH_DEFAULT);  { set field `path' }
  setpath(L, 'cpath', LUA_CPATH_ENV, LUA_CPATH_DEFAULT);  { set field `cpath' }
  { store config information }
  lua_pushstring(L, LUA_DIRSEP + #10 + LUA_PATHSEP + #10 + LUA_PATH_MARK + #10 +
                    LUA_EXECDIR + #10 + LUA_IGMARK);
  lua_setfield(L, -2, 'config');
  { set field `loaded' }
  luaL_findtable(L, LUA_REGISTRYINDEX, '_LOADED', 2);
  lua_setfield(L, -2, 'loaded');
  { set field `preload' }
  lua_newtable(L);
  lua_setfield(L, -2, 'preload');
  lua_pushvalue(L, LUA_GLOBALSINDEX);
  luaL_register(L, nil, @ll_funcs[0]);  { open lib into global table }
  lua_pop(L, 1);
  Result := 1;  { return 'package' table }
end;

end.
