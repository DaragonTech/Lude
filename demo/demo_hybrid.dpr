{ Demo: Lua linked into the program (LuaStatic) AND C extension modules.

  LuaHostExports makes this program export the Lua C API.
  Windows: the hybrid shim lua5.1.dll (hybrid/lua5.dpr) placed next to the
  EXE forwards C modules such as hello.dll to the Lua inside the EXE:
    demo_hybrid.exe  lua5.1.dll (the SHIM)  [lua51.dll proxy]  hello.dll
  Linux: no shim is needed; hello.so finds the API in the executable (link
  with -k--dynamic-list=src/luaapi.dynlist, see build-linux.sh).
  macOS: the same; link with -k-exported_symbols_list -ksrc/luaapi.exp
  (see build-macos.sh).

  usage: demo_hybrid [script.lua [args]]   (without a script: built-in demo) }
program demo_hybrid;

{$IFDEF MSWINDOWS}{$APPTYPE CONSOLE}{$ENDIF}
{$I lua.inc}

uses
  LuaStatic,
  LuaHostExports;

{ a Pascal function, to show both kinds of functions side by side }
function l_pascal_twice(L: Plua_State): Integer; cdecl;
begin
  lua_pushnumber(L, 2 * luaL_checknumber(L, 1));
  Result := 1;
end;

const
  SCRIPT =
    'io.stdout:setvbuf("no")'#10 +
    'print(_VERSION .. ", linked into the program; C module uses its exported API")'#10 +
    'local hello = require "hello"'#10 +
    'print(hello.greet("Delphi"))'#10 +
    'print("hello.sum(1, 2, 3.5) =", hello.sum(1, 2, 3.5))'#10 +
    'print("pcall(hello.fail):", pcall(hello.fail))'#10 +
    'print("C calls Lua calls Pascal:", hello.call(function(x) return twice(x) + 1 end, 20))'#10 +
    'print("same Lua state: package.loaded.hello == hello ->", package.loaded.hello == hello)';

var
  L: Plua_State;
  i, status: Integer;
  arg: AnsiString;
begin
  lua_set_c_fpu_mode;
  L := luaL_newstate;
  luaL_openlibs(L);
  lua_register(L, 'twice', l_pascal_twice);
  if ParamCount = 0 then
    status := luaL_dostring(L, SCRIPT)
  else
  begin
    { script mode: arg table like lua.exe, then run the file }
    lua_createtable(L, ParamCount, 0);
    for i := 0 to ParamCount - 1 do
    begin
      arg := AnsiString(ParamStr(i + 1));
      lua_pushstring(L, PAnsiChar(arg));
      lua_rawseti(L, -2, i);
    end;
    lua_setglobal(L, 'arg');
    arg := AnsiString(ParamStr(1));
    status := luaL_dofile(L, PAnsiChar(arg));
  end;
  if status <> 0 then
    Writeln('error: ', lua_tostring(L, -1));
  lua_close(L);
  if status <> 0 then Halt(1);
end.
