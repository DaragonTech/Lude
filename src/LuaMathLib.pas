{
  Lua 5.1.4 - Pascal port of lmathlib.c
  Standard mathematical library
}
unit LuaMathLib;

{$I lua.inc}

interface

uses
  LuaTypes;

function luaopen_math(L: Plua_State): Integer; cdecl;

implementation

uses
  LuaCRT, LuaAPI, LuaAuxLib;

const
  PI_ = 3.14159265358979323846;
  RADIANS_PER_DEGREE = PI_ / 180.0;

function math_abs(L: Plua_State): Integer; cdecl;
begin
  lua_pushnumber(L, c_fabs(luaL_checknumber(L, 1)));
  Result := 1;
end;

function math_sin(L: Plua_State): Integer; cdecl;
begin
  lua_pushnumber(L, c_sin(luaL_checknumber(L, 1)));
  Result := 1;
end;

function math_sinh(L: Plua_State): Integer; cdecl;
begin
  lua_pushnumber(L, c_sinh(luaL_checknumber(L, 1)));
  Result := 1;
end;

function math_cos(L: Plua_State): Integer; cdecl;
begin
  lua_pushnumber(L, c_cos(luaL_checknumber(L, 1)));
  Result := 1;
end;

function math_cosh(L: Plua_State): Integer; cdecl;
begin
  lua_pushnumber(L, c_cosh(luaL_checknumber(L, 1)));
  Result := 1;
end;

function math_tan(L: Plua_State): Integer; cdecl;
begin
  lua_pushnumber(L, c_tan(luaL_checknumber(L, 1)));
  Result := 1;
end;

function math_tanh(L: Plua_State): Integer; cdecl;
begin
  lua_pushnumber(L, c_tanh(luaL_checknumber(L, 1)));
  Result := 1;
end;

function math_asin(L: Plua_State): Integer; cdecl;
begin
  lua_pushnumber(L, c_asin(luaL_checknumber(L, 1)));
  Result := 1;
end;

function math_acos(L: Plua_State): Integer; cdecl;
begin
  lua_pushnumber(L, c_acos(luaL_checknumber(L, 1)));
  Result := 1;
end;

function math_atan(L: Plua_State): Integer; cdecl;
begin
  lua_pushnumber(L, c_atan(luaL_checknumber(L, 1)));
  Result := 1;
end;

function math_atan2(L: Plua_State): Integer; cdecl;
var y: lua_Number;
begin
  y := luaL_checknumber(L, 1);
  lua_pushnumber(L, c_atan2(y, luaL_checknumber(L, 2)));
  Result := 1;
end;

function math_ceil(L: Plua_State): Integer; cdecl;
begin
  lua_pushnumber(L, c_ceil(luaL_checknumber(L, 1)));
  Result := 1;
end;

function math_floor(L: Plua_State): Integer; cdecl;
begin
  lua_pushnumber(L, c_floor(luaL_checknumber(L, 1)));
  Result := 1;
end;

function math_fmod(L: Plua_State): Integer; cdecl;
var x: lua_Number;
begin
  x := luaL_checknumber(L, 1);
  lua_pushnumber(L, c_fmod(x, luaL_checknumber(L, 2)));
  Result := 1;
end;

function math_modf(L: Plua_State): Integer; cdecl;
var ip, fp: Double;
begin
  fp := c_modf(luaL_checknumber(L, 1), ip);
  lua_pushnumber(L, ip);
  lua_pushnumber(L, fp);
  Result := 2;
end;

function math_sqrt(L: Plua_State): Integer; cdecl;
begin
  lua_pushnumber(L, c_sqrt(luaL_checknumber(L, 1)));
  Result := 1;
end;

function math_pow(L: Plua_State): Integer; cdecl;
var x: lua_Number;
begin
  x := luaL_checknumber(L, 1);
  lua_pushnumber(L, c_pow(x, luaL_checknumber(L, 2)));
  Result := 1;
end;

function math_log(L: Plua_State): Integer; cdecl;
begin
  lua_pushnumber(L, c_log(luaL_checknumber(L, 1)));
  Result := 1;
end;

function math_log10(L: Plua_State): Integer; cdecl;
begin
  lua_pushnumber(L, c_log10(luaL_checknumber(L, 1)));
  Result := 1;
end;

function math_exp(L: Plua_State): Integer; cdecl;
begin
  lua_pushnumber(L, c_exp(luaL_checknumber(L, 1)));
  Result := 1;
end;

function math_deg(L: Plua_State): Integer; cdecl;
begin
  lua_pushnumber(L, luaL_checknumber(L, 1) / RADIANS_PER_DEGREE);
  Result := 1;
end;

function math_rad(L: Plua_State): Integer; cdecl;
begin
  lua_pushnumber(L, luaL_checknumber(L, 1) * RADIANS_PER_DEGREE);
  Result := 1;
end;

function math_frexp(L: Plua_State): Integer; cdecl;
var e: Integer;
begin
  e := 0;
  lua_pushnumber(L, c_frexp(luaL_checknumber(L, 1), e));
  lua_pushinteger(L, e);
  Result := 2;
end;

function math_ldexp(L: Plua_State): Integer; cdecl;
var x: lua_Number;
begin
  x := luaL_checknumber(L, 1);
  lua_pushnumber(L, c_ldexp(x, luaL_checkint(L, 2)));
  Result := 1;
end;

function math_min(L: Plua_State): Integer; cdecl;
var n, i: Integer; dmin, d: lua_Number;
begin
  n := lua_gettop(L);  { number of arguments }
  dmin := luaL_checknumber(L, 1);
  for i := 2 to n do
  begin
    d := luaL_checknumber(L, i);
    if luai_numlt(d, dmin) then
      dmin := d;
  end;
  lua_pushnumber(L, dmin);
  Result := 1;
end;

function math_max(L: Plua_State): Integer; cdecl;
var n, i: Integer; dmax, d: lua_Number;
begin
  n := lua_gettop(L);  { number of arguments }
  dmax := luaL_checknumber(L, 1);
  for i := 2 to n do
  begin
    d := luaL_checknumber(L, i);
    if luai_numlt(dmax, d) then
      dmax := d;
  end;
  lua_pushnumber(L, dmax);
  Result := 1;
end;

function math_random(L: Plua_State): Integer; cdecl;
var r: lua_Number; u, lo: Integer;
begin
  { the `%' avoids the (rare) case of r==1, and is needed also because on
    some systems (SunOS!) `rand()' may return a value larger than RAND_MAX }
  r := (c_rand mod RAND_MAX) / RAND_MAX;
  case lua_gettop(L) of  { check number of arguments }
    0:
      lua_pushnumber(L, r);  { Number between 0 and 1 }
    1:
      begin  { only upper limit }
        u := luaL_checkint(L, 1);
        luaL_argcheck(L, 1 <= u, 1, 'interval is empty');
        lua_pushnumber(L, c_floor(r * u) + 1);  { int between 1 and `u' }
      end;
    2:
      begin  { lower and upper limits }
        lo := luaL_checkint(L, 1);
        u := luaL_checkint(L, 2);
        luaL_argcheck(L, lo <= u, 2, 'interval is empty');
        lua_pushnumber(L, c_floor(r * (u - lo + 1)) + lo);  { int between `l' and `u' }
      end;
  else
    Exit(luaL_errorf(L, 'wrong number of arguments', []));
  end;
  Result := 1;
end;

function math_randomseed(L: Plua_State): Integer; cdecl;
begin
  c_srand(Cardinal(luaL_checkint(L, 1)));
  Result := 0;
end;

const
  mathlib: array[0..28] of luaL_Reg = (
    (name: 'abs'; func: math_abs),
    (name: 'acos'; func: math_acos),
    (name: 'asin'; func: math_asin),
    (name: 'atan2'; func: math_atan2),
    (name: 'atan'; func: math_atan),
    (name: 'ceil'; func: math_ceil),
    (name: 'cosh'; func: math_cosh),
    (name: 'cos'; func: math_cos),
    (name: 'deg'; func: math_deg),
    (name: 'exp'; func: math_exp),
    (name: 'floor'; func: math_floor),
    (name: 'fmod'; func: math_fmod),
    (name: 'frexp'; func: math_frexp),
    (name: 'ldexp'; func: math_ldexp),
    (name: 'log10'; func: math_log10),
    (name: 'log'; func: math_log),
    (name: 'max'; func: math_max),
    (name: 'min'; func: math_min),
    (name: 'modf'; func: math_modf),
    (name: 'pow'; func: math_pow),
    (name: 'rad'; func: math_rad),
    (name: 'random'; func: math_random),
    (name: 'randomseed'; func: math_randomseed),
    (name: 'sinh'; func: math_sinh),
    (name: 'sin'; func: math_sin),
    (name: 'sqrt'; func: math_sqrt),
    (name: 'tanh'; func: math_tanh),
    (name: 'tan'; func: math_tan),
    (name: nil; func: nil));

function luaopen_math(L: Plua_State): Integer; cdecl;
begin
  luaL_register(L, LUA_MATHLIBNAME, @mathlib[0]);
  lua_pushnumber(L, PI_);
  lua_setfield(L, -2, 'pi');
  lua_pushnumber(L, HUGE_VAL);
  lua_setfield(L, -2, 'huge');
  lua_getfield(L, -1, 'fmod');
  lua_setfield(L, -2, 'mod');
  Result := 1;
end;

end.
