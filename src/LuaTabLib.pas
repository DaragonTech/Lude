{
  Lua 5.1.4 - Pascal port of ltablib.c
  Library for Table Manipulation
}
unit LuaTabLib;

{$I lua.inc}

interface

uses
  LuaTypes;

function luaopen_table(L: Plua_State): Integer; cdecl;

implementation

uses
  LuaCRT, LuaAPI, LuaAuxLib;

function aux_getn(L: Plua_State; n: Integer): Integer;
begin
  luaL_checktype(L, n, LUA_TTABLE);
  Result := luaL_getn(L, n);
end;

function foreachi(L: Plua_State): Integer; cdecl;
var i, n: Integer;
begin
  n := aux_getn(L, 1);
  luaL_checktype(L, 2, LUA_TFUNCTION);
  for i := 1 to n do
  begin
    lua_pushvalue(L, 2);  { function }
    lua_pushinteger(L, i);  { 1st argument }
    lua_rawgeti(L, 1, i);  { 2nd argument }
    lua_call(L, 2, 1);
    if not lua_isnil(L, -1) then
      Exit(1);
    lua_pop(L, 1);  { remove nil result }
  end;
  Result := 0;
end;

function foreach(L: Plua_State): Integer; cdecl;
begin
  luaL_checktype(L, 1, LUA_TTABLE);
  luaL_checktype(L, 2, LUA_TFUNCTION);
  lua_pushnil(L);  { first key }
  while lua_next(L, 1) <> 0 do
  begin
    lua_pushvalue(L, 2);  { function }
    lua_pushvalue(L, -3);  { key }
    lua_pushvalue(L, -3);  { value }
    lua_call(L, 2, 1);
    if not lua_isnil(L, -1) then
      Exit(1);
    lua_pop(L, 2);  { remove value and result }
  end;
  Result := 0;
end;

function maxn(L: Plua_State): Integer; cdecl;
var max, v: lua_Number;
begin
  max := 0;
  luaL_checktype(L, 1, LUA_TTABLE);
  lua_pushnil(L);  { first key }
  while lua_next(L, 1) <> 0 do
  begin
    lua_pop(L, 1);  { remove value }
    if lua_type(L, -1) = LUA_TNUMBER then
    begin
      v := lua_tonumber(L, -1);
      if luai_numlt(max, v) then max := v;
    end;
  end;
  lua_pushnumber(L, max);
  Result := 1;
end;

function getn(L: Plua_State): Integer; cdecl;
begin
  lua_pushinteger(L, aux_getn(L, 1));
  Result := 1;
end;

function setn(L: Plua_State): Integer; cdecl;
begin
  luaL_checktype(L, 1, LUA_TTABLE);
  luaL_errorf(L, '''setn'' is obsolete', []);
  lua_pushvalue(L, 1);
  Result := 1;
end;

function tinsert(L: Plua_State): Integer; cdecl;
var e, pos, i: Integer;
begin
  e := aux_getn(L, 1) + 1;  { first empty element }
  case lua_gettop(L) of
    2:
      pos := e;  { insert new element at the end }
    3:
      begin
        pos := luaL_checkint(L, 2);  { 2nd argument is the position }
        if pos > e then e := pos;  { `grow' array if necessary }
        i := e;
        while i > pos do
        begin  { move up elements }
          lua_rawgeti(L, 1, i - 1);
          lua_rawseti(L, 1, i);  { t[i] = t[i-1] }
          Dec(i);
        end;
      end;
  else
    Exit(luaL_errorf(L, 'wrong number of arguments to ''insert''', []));
  end;
  lua_rawseti(L, 1, pos);  { t[pos] = v }
  Result := 0;
end;

function tremove(L: Plua_State): Integer; cdecl;
var e, pos: Integer;
begin
  e := aux_getn(L, 1);
  pos := luaL_optint(L, 2, e);
  if not ((1 <= pos) and (pos <= e)) then  { position is outside bounds? }
    Exit(0);  { nothing to remove }
  lua_rawgeti(L, 1, pos);  { result = t[pos] }
  while pos < e do
  begin
    lua_rawgeti(L, 1, pos + 1);
    lua_rawseti(L, 1, pos);  { t[pos] = t[pos+1] }
    Inc(pos);
  end;
  lua_pushnil(L);
  lua_rawseti(L, 1, e);  { t[e] = nil }
  Result := 1;
end;

procedure addfield(L: Plua_State; b: PluaL_Buffer; i: Integer);
begin
  lua_rawgeti(L, 1, i);
  if lua_isstring(L, -1) = 0 then
    luaL_errorf(L, 'invalid value (%s) at index %d in table for ''concat''',
                [luaL_typename(L, -1), i]);
  luaL_addvalue(b);
end;

function tconcat(L: Plua_State): Integer; cdecl;
var b: luaL_Buffer; lsep: size_t; i, last: Integer; sep: PAnsiChar;
begin
  sep := luaL_optlstring(L, 2, '', @lsep);
  luaL_checktype(L, 1, LUA_TTABLE);
  i := luaL_optint(L, 3, 1);
  if lua_isnoneornil(L, 4) then last := luaL_getn(L, 1) else last := luaL_checkint(L, 4);
  luaL_buffinit(L, @b);
  while i < last do
  begin
    addfield(L, @b, i);
    luaL_addlstring(@b, sep, lsep);
    Inc(i);
  end;
  if i = last then  { add last value (if interval was not empty) }
    addfield(L, @b, i);
  luaL_pushresult(@b);
  Result := 1;
end;

{ ==============================================================
  Quicksort
  (based on `Algorithms in MODULA-3', Robert Sedgewick;
  Addison-Wesley, 1993.)
  ============================================================== }

procedure set2(L: Plua_State; i, j: Integer);
begin
  lua_rawseti(L, 1, i);
  lua_rawseti(L, 1, j);
end;

function sort_comp(L: Plua_State; a, b: Integer): Boolean;
var res: Integer;
begin
  if not lua_isnil(L, 2) then
  begin  { function? }
    lua_pushvalue(L, 2);
    lua_pushvalue(L, a - 1);  { -1 to compensate function }
    lua_pushvalue(L, b - 2);  { -2 to compensate function and `a' }
    lua_call(L, 2, 1);
    res := lua_toboolean(L, -1);
    lua_pop(L, 1);
    Result := res <> 0;
  end
  else  { a < b? }
    Result := lua_lessthan(L, a, b) <> 0;
end;

procedure auxsort(L: Plua_State; lo, up: Integer);
var i, j: Integer;
begin
  while lo < up do
  begin  { for tail recursion }
    { sort elements a[l], a[(l+u)/2] and a[u] }
    lua_rawgeti(L, 1, lo);
    lua_rawgeti(L, 1, up);
    if sort_comp(L, -1, -2) then  { a[u] < a[l]? }
      set2(L, lo, up)  { swap a[l] - a[u] }
    else
      lua_pop(L, 2);
    if up - lo = 1 then Break;  { only 2 elements }
    i := (lo + up) div 2;
    lua_rawgeti(L, 1, i);
    lua_rawgeti(L, 1, lo);
    if sort_comp(L, -2, -1) then  { a[i]<a[l]? }
      set2(L, i, lo)
    else
    begin
      lua_pop(L, 1);  { remove a[l] }
      lua_rawgeti(L, 1, up);
      if sort_comp(L, -1, -2) then  { a[u]<a[i]? }
        set2(L, i, up)
      else
        lua_pop(L, 2);
    end;
    if up - lo = 2 then Break;  { only 3 elements }
    lua_rawgeti(L, 1, i);  { Pivot }
    lua_pushvalue(L, -1);
    lua_rawgeti(L, 1, up - 1);
    set2(L, i, up - 1);
    { a[l] <= P == a[u-1] <= a[u], only need to sort from l+1 to u-2 }
    i := lo;
    j := up - 1;
    while True do
    begin  { invariant: a[l..i] <= P <= a[j..u] }
      { repeat ++i until a[i] >= P }
      while True do
      begin
        Inc(i);
        lua_rawgeti(L, 1, i);
        if not sort_comp(L, -1, -2) then Break;
        if i > up then luaL_errorf(L, 'invalid order function for sorting', []);
        lua_pop(L, 1);  { remove a[i] }
      end;
      { repeat --j until a[j] <= P }
      while True do
      begin
        Dec(j);
        lua_rawgeti(L, 1, j);
        if not sort_comp(L, -3, -1) then Break;
        if j < lo then luaL_errorf(L, 'invalid order function for sorting', []);
        lua_pop(L, 1);  { remove a[j] }
      end;
      if j < i then
      begin
        lua_pop(L, 3);  { pop pivot, a[i], a[j] }
        Break;
      end;
      set2(L, i, j);
    end;
    lua_rawgeti(L, 1, up - 1);
    lua_rawgeti(L, 1, i);
    set2(L, up - 1, i);  { swap pivot (a[u-1]) with a[i] }
    { a[l..i-1] <= a[i] == P <= a[i+1..u] }
    { adjust so that smaller half is in [j..i] and larger one in [l..u] }
    if i - lo < up - i then
    begin
      j := lo;
      i := i - 1;
      lo := i + 2;
    end
    else
    begin
      j := i + 1;
      i := up;
      up := j - 2;
    end;
    auxsort(L, j, i);  { call recursively the smaller one }
  end;  { repeat the routine for the larger one }
end;

function sort(L: Plua_State): Integer; cdecl;
var n: Integer;
begin
  n := aux_getn(L, 1);
  luaL_checkstack(L, 40, '');  { assume array is smaller than 2^40 }
  if not lua_isnoneornil(L, 2) then  { is there a 2nd argument? }
    luaL_checktype(L, 2, LUA_TFUNCTION);
  lua_settop(L, 2);  { make sure there is two arguments }
  auxsort(L, 1, n);
  Result := 0;
end;

const
  tab_funcs: array[0..9] of luaL_Reg = (
    (name: 'concat'; func: tconcat),
    (name: 'foreach'; func: foreach),
    (name: 'foreachi'; func: foreachi),
    (name: 'getn'; func: getn),
    (name: 'maxn'; func: maxn),
    (name: 'insert'; func: tinsert),
    (name: 'remove'; func: tremove),
    (name: 'setn'; func: setn),
    (name: 'sort'; func: sort),
    (name: nil; func: nil));

function luaopen_table(L: Plua_State): Integer; cdecl;
begin
  luaL_register(L, LUA_TABLIBNAME, @tab_funcs[0]);
  Result := 1;
end;

end.
