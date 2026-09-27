/* hello.dll - a small C extension module for the demos.
   Build (MinGW-w64):  gcc -O2 -shared -s -I<lua-5.1.4>/src -o hello.dll hello.c <path>/lua5.1.dll
   It imports from lua5.1.dll by name, so it works with the C DLL, the Pascal
   DLL, and the hybrid shim (Lua linked into the program). */
#include "lua.h"
#include "lauxlib.h"

#ifdef _WIN32
#define DLLEXPORT __declspec(dllexport)
#else
#define DLLEXPORT __attribute__((visibility("default")))
#endif

static int greet(lua_State *L) {
  const char *name = luaL_optstring(L, 1, "world");
  lua_pushfstring(L, "hello %s, from a C module (%d args)", name, lua_gettop(L));
  return 1;
}

static int sum(lua_State *L) {
  int i, n = lua_gettop(L);
  lua_Number s = 0;
  for (i = 1; i <= n; i++) s += luaL_checknumber(L, i);
  lua_pushnumber(L, s);
  return 1;
}

static int fail(lua_State *L) {
  return luaL_error(L, "error raised in C: %s %d", "code", 42);
}

static int callback(lua_State *L) {   /* hello.call(f, ...) calls a Lua function from C */
  luaL_checktype(L, 1, LUA_TFUNCTION);
  lua_call(L, lua_gettop(L) - 1, 1);
  return 1;
}

static const luaL_Reg funcs[] = {
  {"greet", greet}, {"sum", sum}, {"fail", fail}, {"call", callback}, {NULL, NULL}
};

DLLEXPORT int luaopen_hello(lua_State *L) {
  luaL_register(L, "hello", funcs);
  return 1;
}
