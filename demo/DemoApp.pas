{
  DemoApp - the host program shared by demo_dll.dpr and demo_static.dpr.

  It is written once against the LuaDLL interface; LuaStatic has the same
  interface, so the conditional in the uses clause is the only difference.

  Because a unit cannot see $DEFINEs made in a .dpr, LUA_STATIC must be a
  project-wide define (Delphi: Project Options > Delphi Compiler >
  Conditional defines, or dcc -DLUA_STATIC; FPC: -dLUA_STATIC).  Give the two
  projects different unit output folders so they never share a compiled
  DemoApp.dcu/.ppu built with the other setting.
}
unit DemoApp;

{$I lua.inc}

interface

uses
  {$IFDEF LUA_STATIC} LuaStatic {$ELSE} LuaDLL {$ENDIF};

{$IFDEF LUA_STATIC}
const
  DEMO_LINKS_STATIC = True;   { checked by demo_static.dpr at compile time }
{$ENDIF}

procedure RunDemo;

implementation

type
  PCounter = ^TCounter;
  TCounter = record
    value: Integer;
  end;

const
  COUNTER_MT = 'demo.Counter';

{ a Pascal function callable from Lua: add(a, b) -> a + b }
function l_add(L: Plua_State): Integer; cdecl;
begin
  lua_pushnumber(L, luaL_checknumber(L, 1) + luaL_checknumber(L, 2));
  Result := 1;
end;

{ greet(name) -> "Hello, <name>! (<n> chars)"  - uses lua_pushfstringf }
function l_greet(L: Plua_State): Integer; cdecl;
var name: PAnsiChar;
begin
  name := luaL_checkstring(L, 1);
  lua_pushfstringf(L, 'Hello, %s! (%d chars)', [name, Integer(lua_objlen(L, 1))]);
  Result := 1;
end;

{ checked(n) raises a Lua error from Pascal when n < 0 - uses luaL_errorf }
function l_checked(L: Plua_State): Integer; cdecl;
var n: lua_Number;
begin
  n := luaL_checknumber(L, 1);
  if n < 0 then
    Exit(luaL_errorf(L, 'negative value not allowed: %f', [n]));
  lua_pushnumber(L, Sqrt(n));
  Result := 1;
end;

{ userdata: Counter.new(start), c:inc([step]), c:get() }
function counter_new(L: Plua_State): Integer; cdecl;
var c: PCounter;
begin
  c := lua_newuserdata(L, SizeOf(TCounter));
  c^.value := luaL_optint(L, 1, 0);
  luaL_getmetatable(L, COUNTER_MT);
  lua_setmetatable(L, -2);
  Result := 1;
end;

function counter_inc(L: Plua_State): Integer; cdecl;
var c: PCounter;
begin
  c := luaL_checkudata(L, 1, COUNTER_MT);
  Inc(c^.value, luaL_optint(L, 2, 1));
  lua_settop(L, 1);
  Result := 1;   { return self, so calls can be chained }
end;

function counter_get(L: Plua_State): Integer; cdecl;
begin
  lua_pushinteger(L, PCounter(luaL_checkudata(L, 1, COUNTER_MT))^.value);
  Result := 1;
end;

const
  counter_methods: array[0..2] of luaL_Reg = (
    (name: 'inc'; func: counter_inc),
    (name: 'get'; func: counter_get),
    (name: nil; func: nil));
  counter_funcs: array[0..1] of luaL_Reg = (
    (name: 'new'; func: counter_new),
    (name: nil; func: nil));

procedure open_demo(L: Plua_State);
begin
  lua_register(L, 'add', l_add);
  lua_register(L, 'greet', l_greet);
  lua_register(L, 'checked', l_checked);
  luaL_newmetatable(L, COUNTER_MT);
  lua_pushvalue(L, -1);
  lua_setfield(L, -2, '__index');
  luaL_register(L, nil, @counter_methods[0]);
  lua_pop(L, 1);
  luaL_register(L, 'Counter', @counter_funcs[0]);
  lua_pop(L, 1);
end;

procedure run(L: Plua_State; const code: AnsiString);
begin
  if luaL_dostring(L, PAnsiChar(code)) <> 0 then
  begin
    Writeln('error: ', lua_tostring(L, -1));
    lua_pop(L, 1);
  end;
end;

const
  SCRIPT =
    'print(_VERSION, "running with " .. MODE)'#10 +
    'print("add(2, 3) =", add(2, 3))'#10 +
    'print(greet("Delphi"))'#10 +
    'print("checked(16) =", checked(16))'#10 +
    'print("pcall(checked, -1):", pcall(checked, -1))'#10 +
    'local c = Counter.new(10)'#10 +
    'c:inc():inc(5)'#10 +
    'print("counter:", c:get())'#10 +
    'local t = {} for i = 1, 5 do t[i] = i * i end'#10 +
    'print("squares:", table.concat(t, ","), "  0/0 =", 0/0, "  1/0 =", 1/0)'#10 +
    'print(string.format("%5.2f | %s | %q", math.pi, os.date("!%Y", 0), "a\n"))';

procedure RunDemo;
var
  L: Plua_State;
begin
  lua_set_c_fpu_mode;   { mask FP exceptions: 0/0 -> nan instead of EInvalidOp }
  L := luaL_newstate;
  luaL_openlibs(L);
  open_demo(L);
{$IFDEF LUA_STATIC}
  lua_pushstring(L, 'Lua linked statically (LuaStatic)');
{$ELSE}
  lua_pushstring(L, {$IFDEF MSWINDOWS}'lua5.1.dll (LuaDLL)'{$ELSE}{$IFDEF DARWIN}'liblua5.1.dylib (LuaDLL)'{$ELSE}'liblua5.1.so (LuaDLL)'{$ENDIF}{$ENDIF});
{$ENDIF}
  lua_setglobal(L, 'MODE');
  { Lua's print() and the host's Writeln use different stdio buffers; make
    Lua's stdout unbuffered so the output interleaves correctly in pipes }
  run(L, 'io.stdout:setvbuf("no")');
  run(L, SCRIPT);
  run(L, 'error("script errors are reported to the host")');
  { reading a global back from Lua }
  run(L, 'answer = 6 * 7');
  lua_getglobal(L, 'answer');
  Writeln('host reads answer = ', lua_tointeger(L, -1));
  lua_pop(L, 1);
  lua_close(L);
end;

end.
