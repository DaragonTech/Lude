/* C extension module used to check that the Pascal lua5.1.dll is a drop-in
   replacement at the C ABI level. */
#include <string.h>
#include <stdio.h>
#include "lua.h"
#include "lauxlib.h"

#ifdef _WIN32
#define DLLEXPORT __declspec(dllexport)
#else
#define DLLEXPORT __attribute__((visibility("default")))
#endif

static int c_fmt(lua_State *L) {
  /* varargs through lua_pushfstring */
  lua_pushfstring(L, "[%s|%d|%f|%c|%%|%s]", "str", -42, 3.5, 'Z', luaL_checkstring(L, 1));
  return 1;
}

static int c_fmtptr(lua_State *L) {
  lua_pushfstring(L, "%p", (void *)0x1234);
  return 1;
}

static int deep(lua_State *L, int n) {
  /* recursion through C frames before raising the error */
  if (n == 0) return luaL_error(L, "deep error %d %s", 7, "x");
  return deep(L, n - 1) + 1;
}

static int c_error(lua_State *L) {
  return deep(L, 10);
}

static int c_errtable(lua_State *L) {
  lua_newtable(L);
  lua_pushinteger(L, 99);
  lua_setfield(L, -2, "code");
  return lua_error(L);
}

static int c_buffer(lua_State *L) {
  luaL_Buffer b;
  int i, n = luaL_checkint(L, 1);
  luaL_buffinit(L, &b);
  for (i = 0; i < n; i++) luaL_addchar(&b, 'a' + i % 26);   /* macro: touches B->p */
  luaL_addstring(&b, "|");
  lua_pushinteger(L, n); luaL_addvalue(&b);
  {
    char *p = luaL_prepbuffer(&b);
    memcpy(p, "<end>", 5);
    luaL_addsize(&b, 5);
  }
  luaL_pushresult(&b);
  return 1;
}

static int c_where(lua_State *L) {
  lua_Debug ar;
  if (!lua_getstack(L, 1, &ar)) return 0;
  lua_getinfo(L, "nSl", &ar);
  lua_pushstring(L, ar.short_src);
  lua_pushinteger(L, ar.currentline);
  lua_pushstring(L, ar.what);
  lua_pushinteger(L, ar.linedefined);
  lua_pushinteger(L, (int)sizeof(lua_Debug));
  return 5;
}

typedef struct { double d; int i; char s[16]; } Point;

static int c_newpoint(lua_State *L) {
  Point *p = (Point *)lua_newuserdata(L, sizeof(Point));
  p->d = luaL_checknumber(L, 1);
  p->i = luaL_checkint(L, 2);
  strcpy(p->s, "point");
  luaL_getmetatable(L, "ctest.Point");
  lua_setmetatable(L, -2);
  return 1;
}

static int c_pointinfo(lua_State *L) {
  Point *p = (Point *)luaL_checkudata(L, 1, "ctest.Point");
  lua_pushnumber(L, p->d);
  lua_pushinteger(L, p->i);
  lua_pushstring(L, p->s);
  lua_pushinteger(L, (int)(((size_t)p) % 8));   /* alignment of userdata */
  lua_pushinteger(L, (int)lua_objlen(L, 1));
  return 5;
}

static int cp_func(lua_State *L) {
  int *pv = (int *)lua_touserdata(L, 1);
  *pv += 1;
  if (*pv > 1) luaL_error(L, "cpcall error");
  return 0;
}

static int c_cpcall(lua_State *L) {
  int v = 0, r1, r2;
  r1 = lua_cpcall(L, cp_func, &v);
  r2 = lua_cpcall(L, cp_func, &v);
  lua_pushinteger(L, r1);
  lua_pushinteger(L, r2);
  lua_pushvalue(L, -3);  /* error message of the second call */
  lua_pushinteger(L, v);
  return 4;
}

static int c_pcallerr(lua_State *L) {
  /* lua_pcall from C of a Lua function that errors */
  int st;
  luaL_checktype(L, 1, LUA_TFUNCTION);
  lua_pushvalue(L, 1);
  st = lua_pcall(L, 0, 0, 0);
  lua_pushinteger(L, st);
  lua_insert(L, -2);
  return 2;
}

static int c_yield(lua_State *L) {
  lua_pushinteger(L, 10);
  lua_pushinteger(L, 20);
  return lua_yield(L, 2);
}

static int c_ref(lua_State *L) {
  int r;
  lua_pushstring(L, "refval");
  r = luaL_ref(L, LUA_REGISTRYINDEX);
  lua_rawgeti(L, LUA_REGISTRYINDEX, r);
  luaL_unref(L, LUA_REGISTRYINDEX, r);
  lua_pushinteger(L, r > 0);
  return 2;
}

static int c_misc(lua_State *L) {
  size_t len;
  const char *s;
  lua_pushnumber(L, 12.5);
  s = lua_tolstring(L, -1, &len);
  lua_pushfstring(L, "%s/%d", s, (int)len);
  lua_pushinteger(L, lua_tointeger(L, -2));          /* 12.5 -> 12 (x64) or 12 (x86: round-half-even) */
  lua_pushnumber(L, 13.5);
  lua_pushinteger(L, lua_tointeger(L, -1));
  lua_remove(L, -2);
  lua_pushboolean(L, lua_isnumber(L, -1));
  lua_pushstring(L, lua_typename(L, lua_type(L, -1)));
  return 5;
}

static int c_gsub(lua_State *L) {
  lua_pushstring(L, luaL_gsub(L, luaL_checkstring(L, 1), "a", "XY"));
  return 1;
}

static const luaL_Reg funcs[] = {
  {"fmt", c_fmt}, {"fmtptr", c_fmtptr}, {"error", c_error}, {"errtable", c_errtable},
  {"buffer", c_buffer}, {"where", c_where}, {"newpoint", c_newpoint},
  {"pointinfo", c_pointinfo}, {"cpcall", c_cpcall}, {"pcallerr", c_pcallerr},
  {"yield", c_yield}, {"ref", c_ref}, {"misc", c_misc}, {"gsub", c_gsub},
  {NULL, NULL}
};

DLLEXPORT int luaopen_ctest(lua_State *L) {
  luaL_newmetatable(L, "ctest.Point");
  lua_pop(L, 1);
  luaL_register(L, "ctest", funcs);
  return 1;
}
