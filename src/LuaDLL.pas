{
  Lua 5.1.4 - import unit for lua5.1.dll (or lua51.dll)

  Declares the complete C API of lua.h, lauxlib.h and lualib.h for Pascal
  programs that use the DLL (this Pascal build or any C build).
  Varargs functions (lua_pushfstring, luaL_error) are declared `varargs'.
  lua_pushfstringf / luaL_errorf take a Pascal array of const instead and
  also exist in LuaStatic.pas, so code using them compiles with both units.

  Define LUA_USE_LUA51 to import from lua51.dll instead of lua5.1.dll.
}
unit LuaDLL;

{$I lua.inc}

interface

const
{$IFDEF LUA_POSIX}
  LUA_LIB_NAME = 'lua5.1';        { liblua5.1.so / liblua5.1.dylib }
{$IFDEF DARWIN}
  { Free Pascal for macOS does not pass the libraries named in 'external'
    to the linker; ask for it explicitly }
  {$LINKLIB lua5.1}
{$ENDIF}
{$ELSE}
{$IFDEF LUA_USE_LUA51}
  LUA_LIB_NAME = 'lua51.dll';
{$ELSE}
  LUA_LIB_NAME = 'lua5.1.dll';
{$ENDIF}
{$ENDIF}

  LUA_VERSION   = 'Lua 5.1';
  LUA_RELEASE   = 'Lua 5.1.4';
  LUA_VERSION_NUM = 501;
  LUA_COPYRIGHT = 'Copyright (C) 1994-2008 Lua.org, PUC-Rio';
  LUA_AUTHORS   = 'R. Ierusalimschy, L. H. de Figueiredo & W. Celes';
  LUA_SIGNATURE = #27'Lua';
  LUA_MULTRET = -1;
  LUA_REGISTRYINDEX = -10000;
  LUA_ENVIRONINDEX  = -10001;
  LUA_GLOBALSINDEX  = -10002;
  LUA_YIELD_    = 1;   { LUA_YIELD in C (renamed: Pascal is case-insensitive) }
  LUA_ERRRUN    = 2;
  LUA_ERRSYNTAX = 3;
  LUA_ERRMEM    = 4;
  LUA_ERRERR    = 5;
  LUA_ERRFILE   = 6;
  LUA_TNONE          = -1;
  LUA_TNIL           = 0;
  LUA_TBOOLEAN       = 1;
  LUA_TLIGHTUSERDATA = 2;
  LUA_TNUMBER        = 3;
  LUA_TSTRING        = 4;
  LUA_TTABLE         = 5;
  LUA_TFUNCTION      = 6;
  LUA_TUSERDATA      = 7;
  LUA_TTHREAD        = 8;
  LUA_MINSTACK = 20;
  LUA_GCSTOP = 0; LUA_GCRESTART = 1; LUA_GCCOLLECT = 2; LUA_GCCOUNT = 3;
  LUA_GCCOUNTB = 4; LUA_GCSTEP = 5; LUA_GCSETPAUSE = 6; LUA_GCSETSTEPMUL = 7;
  LUA_HOOKCALL = 0; LUA_HOOKRET = 1; LUA_HOOKLINE = 2; LUA_HOOKCOUNT = 3; LUA_HOOKTAILRET = 4;
  LUA_MASKCALL = 1 shl LUA_HOOKCALL;
  LUA_MASKRET = 1 shl LUA_HOOKRET;
  LUA_MASKLINE = 1 shl LUA_HOOKLINE;
  LUA_MASKCOUNT = 1 shl LUA_HOOKCOUNT;
  LUA_IDSIZE = 60;
  LUAL_BUFFERSIZE = 512;
  LUA_NOREF = -2;
  LUA_REFNIL = -1;
  LUA_FILEHANDLE  = 'FILE*';
  LUA_COLIBNAME   = 'coroutine';
  LUA_TABLIBNAME  = 'table';
  LUA_IOLIBNAME   = 'io';
  LUA_OSLIBNAME   = 'os';
  LUA_STRLIBNAME  = 'string';
  LUA_MATHLIBNAME = 'math';
  LUA_DBLIBNAME   = 'debug';
  LUA_LOADLIBNAME = 'package';

type
  size_t = NativeUInt;
  Psize_t = ^size_t;
  lua_Number = Double;
  lua_Integer = NativeInt;
  { C 'long': 32-bit on Windows, 64-bit on Linux x86-64 }
{$IFDEF LUA_POSIX}
  c_long = Int64;
{$ELSE}
  c_long = Integer;
{$ENDIF}

  Plua_State = Pointer;
  Plua_Debug = ^lua_Debug;

  lua_CFunction = function(L: Plua_State): Integer; cdecl;
  lua_Reader = function(L: Plua_State; ud: Pointer; sz: Psize_t): PAnsiChar; cdecl;
  lua_Writer = function(L: Plua_State; p: Pointer; sz: size_t; ud: Pointer): Integer; cdecl;
  lua_Alloc  = function(ud, ptr: Pointer; osize, nsize: size_t): Pointer; cdecl;
  lua_Hook   = procedure(L: Plua_State; ar: Plua_Debug); cdecl;

  lua_Debug = record
    event: Integer;
    name: PAnsiChar;
    namewhat: PAnsiChar;
    what: PAnsiChar;
    source: PAnsiChar;
    currentline: Integer;
    nups: Integer;
    linedefined: Integer;
    lastlinedefined: Integer;
    short_src: array[0..LUA_IDSIZE - 1] of AnsiChar;
    i_ci: Integer;
  end;

  PluaL_Reg = ^luaL_Reg;
  luaL_Reg = record
    name: PAnsiChar;
    func: lua_CFunction;
  end;

  PluaL_Buffer = ^luaL_Buffer;
  luaL_Buffer = record
    p: PAnsiChar;
    lvl: Integer;
    L: Plua_State;
    buffer: array[0..LUAL_BUFFERSIZE - 1] of AnsiChar;
  end;

{ lua.h }
function lua_newstate(f: lua_Alloc; ud: Pointer): Plua_State; cdecl; external LUA_LIB_NAME;
procedure lua_close(L: Plua_State); cdecl; external LUA_LIB_NAME;
function lua_newthread(L: Plua_State): Plua_State; cdecl; external LUA_LIB_NAME;
function lua_atpanic(L: Plua_State; panicf: lua_CFunction): lua_CFunction; cdecl; external LUA_LIB_NAME;
function lua_gettop(L: Plua_State): Integer; cdecl; external LUA_LIB_NAME;
procedure lua_settop(L: Plua_State; idx: Integer); cdecl; external LUA_LIB_NAME;
procedure lua_pushvalue(L: Plua_State; idx: Integer); cdecl; external LUA_LIB_NAME;
procedure lua_remove(L: Plua_State; idx: Integer); cdecl; external LUA_LIB_NAME;
procedure lua_insert(L: Plua_State; idx: Integer); cdecl; external LUA_LIB_NAME;
procedure lua_replace(L: Plua_State; idx: Integer); cdecl; external LUA_LIB_NAME;
function lua_checkstack(L: Plua_State; sz: Integer): Integer; cdecl; external LUA_LIB_NAME;
procedure lua_xmove(from, to_: Plua_State; n: Integer); cdecl; external LUA_LIB_NAME;
function lua_isnumber(L: Plua_State; idx: Integer): Integer; cdecl; external LUA_LIB_NAME;
function lua_isstring(L: Plua_State; idx: Integer): Integer; cdecl; external LUA_LIB_NAME;
function lua_iscfunction(L: Plua_State; idx: Integer): Integer; cdecl; external LUA_LIB_NAME;
function lua_isuserdata(L: Plua_State; idx: Integer): Integer; cdecl; external LUA_LIB_NAME;
function lua_type(L: Plua_State; idx: Integer): Integer; cdecl; external LUA_LIB_NAME;
function lua_typename(L: Plua_State; tp: Integer): PAnsiChar; cdecl; external LUA_LIB_NAME;
function lua_equal(L: Plua_State; idx1, idx2: Integer): Integer; cdecl; external LUA_LIB_NAME;
function lua_rawequal(L: Plua_State; idx1, idx2: Integer): Integer; cdecl; external LUA_LIB_NAME;
function lua_lessthan(L: Plua_State; idx1, idx2: Integer): Integer; cdecl; external LUA_LIB_NAME;
function lua_tonumber(L: Plua_State; idx: Integer): lua_Number; cdecl; external LUA_LIB_NAME;
function lua_tointeger(L: Plua_State; idx: Integer): lua_Integer; cdecl; external LUA_LIB_NAME;
function lua_toboolean(L: Plua_State; idx: Integer): Integer; cdecl; external LUA_LIB_NAME;
function lua_tolstring(L: Plua_State; idx: Integer; len: Psize_t): PAnsiChar; cdecl; external LUA_LIB_NAME;
function lua_objlen(L: Plua_State; idx: Integer): size_t; cdecl; external LUA_LIB_NAME;
function lua_tocfunction(L: Plua_State; idx: Integer): lua_CFunction; cdecl; external LUA_LIB_NAME;
function lua_touserdata(L: Plua_State; idx: Integer): Pointer; cdecl; external LUA_LIB_NAME;
function lua_tothread(L: Plua_State; idx: Integer): Plua_State; cdecl; external LUA_LIB_NAME;
function lua_topointer(L: Plua_State; idx: Integer): Pointer; cdecl; external LUA_LIB_NAME;
procedure lua_pushnil(L: Plua_State); cdecl; external LUA_LIB_NAME;
procedure lua_pushnumber(L: Plua_State; n: lua_Number); cdecl; external LUA_LIB_NAME;
procedure lua_pushinteger(L: Plua_State; n: lua_Integer); cdecl; external LUA_LIB_NAME;
procedure lua_pushlstring(L: Plua_State; s: PAnsiChar; l_: size_t); cdecl; external LUA_LIB_NAME;
procedure lua_pushstring(L: Plua_State; s: PAnsiChar); cdecl; external LUA_LIB_NAME;
function lua_pushvfstring(L: Plua_State; fmt: PAnsiChar; argp: Pointer): PAnsiChar; cdecl; external LUA_LIB_NAME;
function lua_pushfstring(L: Plua_State; fmt: PAnsiChar): PAnsiChar; cdecl; varargs; external LUA_LIB_NAME;
procedure lua_pushcclosure(L: Plua_State; fn: lua_CFunction; n: Integer); cdecl; external LUA_LIB_NAME;
procedure lua_pushboolean(L: Plua_State; b: Integer); cdecl; external LUA_LIB_NAME;
procedure lua_pushlightuserdata(L: Plua_State; p: Pointer); cdecl; external LUA_LIB_NAME;
function lua_pushthread(L: Plua_State): Integer; cdecl; external LUA_LIB_NAME;
procedure lua_gettable(L: Plua_State; idx: Integer); cdecl; external LUA_LIB_NAME;
procedure lua_getfield(L: Plua_State; idx: Integer; k: PAnsiChar); cdecl; external LUA_LIB_NAME;
procedure lua_rawget(L: Plua_State; idx: Integer); cdecl; external LUA_LIB_NAME;
procedure lua_rawgeti(L: Plua_State; idx, n: Integer); cdecl; external LUA_LIB_NAME;
procedure lua_createtable(L: Plua_State; narr, nrec: Integer); cdecl; external LUA_LIB_NAME;
function lua_newuserdata(L: Plua_State; sz: size_t): Pointer; cdecl; external LUA_LIB_NAME;
function lua_getmetatable(L: Plua_State; objindex: Integer): Integer; cdecl; external LUA_LIB_NAME;
procedure lua_getfenv(L: Plua_State; idx: Integer); cdecl; external LUA_LIB_NAME;
procedure lua_settable(L: Plua_State; idx: Integer); cdecl; external LUA_LIB_NAME;
procedure lua_setfield(L: Plua_State; idx: Integer; k: PAnsiChar); cdecl; external LUA_LIB_NAME;
procedure lua_rawset(L: Plua_State; idx: Integer); cdecl; external LUA_LIB_NAME;
procedure lua_rawseti(L: Plua_State; idx, n: Integer); cdecl; external LUA_LIB_NAME;
function lua_setmetatable(L: Plua_State; objindex: Integer): Integer; cdecl; external LUA_LIB_NAME;
function lua_setfenv(L: Plua_State; idx: Integer): Integer; cdecl; external LUA_LIB_NAME;
procedure lua_call(L: Plua_State; nargs, nresults: Integer); cdecl; external LUA_LIB_NAME;
function lua_pcall(L: Plua_State; nargs, nresults, errfunc: Integer): Integer; cdecl; external LUA_LIB_NAME;
function lua_cpcall(L: Plua_State; func: lua_CFunction; ud: Pointer): Integer; cdecl; external LUA_LIB_NAME;
function lua_load(L: Plua_State; reader: lua_Reader; dt: Pointer; chunkname: PAnsiChar): Integer; cdecl; external LUA_LIB_NAME;
function lua_dump(L: Plua_State; writer: lua_Writer; data: Pointer): Integer; cdecl; external LUA_LIB_NAME;
function lua_yield(L: Plua_State; nresults: Integer): Integer; cdecl; external LUA_LIB_NAME;
function lua_resume(L: Plua_State; narg: Integer): Integer; cdecl; external LUA_LIB_NAME;
function lua_status(L: Plua_State): Integer; cdecl; external LUA_LIB_NAME;
function lua_gc(L: Plua_State; what, data: Integer): Integer; cdecl; external LUA_LIB_NAME;
function lua_error(L: Plua_State): Integer; cdecl; external LUA_LIB_NAME;
function lua_next(L: Plua_State; idx: Integer): Integer; cdecl; external LUA_LIB_NAME;
procedure lua_concat(L: Plua_State; n: Integer); cdecl; external LUA_LIB_NAME;
function lua_getallocf(L: Plua_State; ud: PPointer): lua_Alloc; cdecl; external LUA_LIB_NAME;
procedure lua_setallocf(L: Plua_State; f: lua_Alloc; ud: Pointer); cdecl; external LUA_LIB_NAME;
procedure lua_setlevel(from, to_: Plua_State); cdecl; external LUA_LIB_NAME;
function lua_getstack(L: Plua_State; level: Integer; ar: Plua_Debug): Integer; cdecl; external LUA_LIB_NAME;
function lua_getinfo(L: Plua_State; what: PAnsiChar; ar: Plua_Debug): Integer; cdecl; external LUA_LIB_NAME;
function lua_getlocal(L: Plua_State; ar: Plua_Debug; n: Integer): PAnsiChar; cdecl; external LUA_LIB_NAME;
function lua_setlocal(L: Plua_State; ar: Plua_Debug; n: Integer): PAnsiChar; cdecl; external LUA_LIB_NAME;
function lua_getupvalue(L: Plua_State; funcindex, n: Integer): PAnsiChar; cdecl; external LUA_LIB_NAME;
function lua_setupvalue(L: Plua_State; funcindex, n: Integer): PAnsiChar; cdecl; external LUA_LIB_NAME;
function lua_sethook(L: Plua_State; func: lua_Hook; mask, count: Integer): Integer; cdecl; external LUA_LIB_NAME;
function lua_gethook(L: Plua_State): lua_Hook; cdecl; external LUA_LIB_NAME;
function lua_gethookmask(L: Plua_State): Integer; cdecl; external LUA_LIB_NAME;
function lua_gethookcount(L: Plua_State): Integer; cdecl; external LUA_LIB_NAME;

{ lauxlib.h }
procedure luaL_openlib(L: Plua_State; libname: PAnsiChar; l_: PluaL_Reg; nup: Integer); cdecl; external LUA_LIB_NAME;
procedure luaL_register(L: Plua_State; libname: PAnsiChar; l_: PluaL_Reg); cdecl; external LUA_LIB_NAME;
function luaL_getmetafield(L: Plua_State; obj: Integer; e: PAnsiChar): Integer; cdecl; external LUA_LIB_NAME;
function luaL_callmeta(L: Plua_State; obj: Integer; e: PAnsiChar): Integer; cdecl; external LUA_LIB_NAME;
function luaL_typerror(L: Plua_State; narg: Integer; tname: PAnsiChar): Integer; cdecl; external LUA_LIB_NAME;
function luaL_argerror(L: Plua_State; numarg: Integer; extramsg: PAnsiChar): Integer; cdecl; external LUA_LIB_NAME;
function luaL_checklstring(L: Plua_State; numArg: Integer; l_: Psize_t): PAnsiChar; cdecl; external LUA_LIB_NAME;
function luaL_optlstring(L: Plua_State; numArg: Integer; def: PAnsiChar; l_: Psize_t): PAnsiChar; cdecl; external LUA_LIB_NAME;
function luaL_checknumber(L: Plua_State; numArg: Integer): lua_Number; cdecl; external LUA_LIB_NAME;
function luaL_optnumber(L: Plua_State; nArg: Integer; def: lua_Number): lua_Number; cdecl; external LUA_LIB_NAME;
function luaL_checkinteger(L: Plua_State; numArg: Integer): lua_Integer; cdecl; external LUA_LIB_NAME;
function luaL_optinteger(L: Plua_State; nArg: Integer; def: lua_Integer): lua_Integer; cdecl; external LUA_LIB_NAME;
procedure luaL_checkstack(L: Plua_State; sz: Integer; msg: PAnsiChar); cdecl; external LUA_LIB_NAME;
procedure luaL_checktype(L: Plua_State; narg, t: Integer); cdecl; external LUA_LIB_NAME;
procedure luaL_checkany(L: Plua_State; narg: Integer); cdecl; external LUA_LIB_NAME;
function luaL_newmetatable(L: Plua_State; tname: PAnsiChar): Integer; cdecl; external LUA_LIB_NAME;
function luaL_checkudata(L: Plua_State; ud: Integer; tname: PAnsiChar): Pointer; cdecl; external LUA_LIB_NAME;
procedure luaL_where(L: Plua_State; lvl: Integer); cdecl; external LUA_LIB_NAME;
function luaL_error(L: Plua_State; fmt: PAnsiChar): Integer; cdecl; varargs; external LUA_LIB_NAME;
function luaL_checkoption(L: Plua_State; narg: Integer; def: PAnsiChar; lst: PPAnsiChar): Integer; cdecl; external LUA_LIB_NAME;
function luaL_ref(L: Plua_State; t: Integer): Integer; cdecl; external LUA_LIB_NAME;
procedure luaL_unref(L: Plua_State; t, ref: Integer); cdecl; external LUA_LIB_NAME;
function luaL_loadfile(L: Plua_State; filename: PAnsiChar): Integer; cdecl; external LUA_LIB_NAME;
function luaL_loadbuffer(L: Plua_State; buff: PAnsiChar; sz: size_t; name: PAnsiChar): Integer; cdecl; external LUA_LIB_NAME;
function luaL_loadstring(L: Plua_State; s: PAnsiChar): Integer; cdecl; external LUA_LIB_NAME;
function luaL_newstate: Plua_State; cdecl; external LUA_LIB_NAME;
function luaL_gsub(L: Plua_State; s, p, r: PAnsiChar): PAnsiChar; cdecl; external LUA_LIB_NAME;
function luaL_findtable(L: Plua_State; idx: Integer; fname: PAnsiChar; szhint: Integer): PAnsiChar; cdecl; external LUA_LIB_NAME;
procedure luaL_buffinit(L: Plua_State; B: PluaL_Buffer); cdecl; external LUA_LIB_NAME;
function luaL_prepbuffer(B: PluaL_Buffer): PAnsiChar; cdecl; external LUA_LIB_NAME;
procedure luaL_addlstring(B: PluaL_Buffer; s: PAnsiChar; l_: size_t); cdecl; external LUA_LIB_NAME;
procedure luaL_addstring(B: PluaL_Buffer; s: PAnsiChar); cdecl; external LUA_LIB_NAME;
procedure luaL_addvalue(B: PluaL_Buffer); cdecl; external LUA_LIB_NAME;
procedure luaL_pushresult(B: PluaL_Buffer); cdecl; external LUA_LIB_NAME;

{ lualib.h }
function luaopen_base(L: Plua_State): Integer; cdecl; external LUA_LIB_NAME;
function luaopen_table(L: Plua_State): Integer; cdecl; external LUA_LIB_NAME;
function luaopen_io(L: Plua_State): Integer; cdecl; external LUA_LIB_NAME;
function luaopen_os(L: Plua_State): Integer; cdecl; external LUA_LIB_NAME;
function luaopen_string(L: Plua_State): Integer; cdecl; external LUA_LIB_NAME;
function luaopen_math(L: Plua_State): Integer; cdecl; external LUA_LIB_NAME;
function luaopen_debug(L: Plua_State): Integer; cdecl; external LUA_LIB_NAME;
function luaopen_package(L: Plua_State): Integer; cdecl; external LUA_LIB_NAME;
procedure luaL_openlibs(L: Plua_State); cdecl; external LUA_LIB_NAME;

{ formatted messages with a Pascal array of const (%d %f %s %p %c %%);
  same as LuaStatic, e.g. luaL_errorf(L, 'bad value %d', [n]) }
function lua_pushfstringf(L: Plua_State; fmt: PAnsiChar; const args: array of const): PAnsiChar;
function luaL_errorf(L: Plua_State; fmt: PAnsiChar; const args: array of const): Integer;

{ puts the FPU in the state a C program has (all FP exceptions masked);
  call once at startup so 0/0 and 1/0 give NaN/inf instead of raising }
procedure lua_set_c_fpu_mode;

{ macros from lua.h / lauxlib.h }
function lua_upvalueindex(i: Integer): Integer; inline;
procedure lua_pop(L: Plua_State; n: Integer); inline;
procedure lua_newtable(L: Plua_State); inline;
procedure lua_register(L: Plua_State; n: PAnsiChar; f: lua_CFunction); inline;
procedure lua_pushcfunction(L: Plua_State; f: lua_CFunction); inline;
function lua_strlen(L: Plua_State; i: Integer): size_t; inline;
function lua_isfunction(L: Plua_State; n: Integer): Boolean; inline;
function lua_istable(L: Plua_State; n: Integer): Boolean; inline;
function lua_islightuserdata(L: Plua_State; n: Integer): Boolean; inline;
function lua_isnil(L: Plua_State; n: Integer): Boolean; inline;
function lua_isboolean(L: Plua_State; n: Integer): Boolean; inline;
function lua_isthread(L: Plua_State; n: Integer): Boolean; inline;
function lua_isnone(L: Plua_State; n: Integer): Boolean; inline;
function lua_isnoneornil(L: Plua_State; n: Integer): Boolean; inline;
procedure lua_pushliteral(L: Plua_State; const s: AnsiString); inline;
procedure lua_setglobal(L: Plua_State; s: PAnsiChar); inline;
procedure lua_getglobal(L: Plua_State; s: PAnsiChar); inline;
function lua_tostring(L: Plua_State; i: Integer): PAnsiChar; inline;
function lua_open: Plua_State; inline;
procedure lua_getregistry(L: Plua_State); inline;
function lua_getgccount(L: Plua_State): Integer; inline;
procedure luaL_argcheck(L: Plua_State; cond: Boolean; numarg: Integer; extramsg: PAnsiChar); inline;
function luaL_checkstring(L: Plua_State; n: Integer): PAnsiChar; inline;
function luaL_optstring(L: Plua_State; n: Integer; d: PAnsiChar): PAnsiChar; inline;
function luaL_checkint(L: Plua_State; n: Integer): Integer; inline;
function luaL_optint(L: Plua_State; n, d: Integer): Integer; inline;
function luaL_checklong(L: Plua_State; n: Integer): c_long; inline;
function luaL_optlong(L: Plua_State; n: Integer; d: c_long): c_long; inline;
function luaL_typename(L: Plua_State; i: Integer): PAnsiChar; inline;
function luaL_dofile(L: Plua_State; fn: PAnsiChar): Integer; inline;
function luaL_dostring(L: Plua_State; s: PAnsiChar): Integer; inline;
procedure luaL_getmetatable(L: Plua_State; n: PAnsiChar); inline;
procedure luaL_addchar(B: PluaL_Buffer; c: AnsiChar); inline;
procedure luaL_addsize(B: PluaL_Buffer; n: size_t); inline;
function luaL_getn(L: Plua_State; i: Integer): Integer; inline;
function lua_ref(L: Plua_State; lock: Boolean): Integer; inline;
procedure lua_unref(L: Plua_State; ref: Integer); inline;
procedure lua_getref(L: Plua_State; ref: Integer); inline;

implementation

{ Builds a C va_list from an array of const: int/pointer arguments take
  one slot (4 bytes on Win32, 8 on 64-bit), doubles 8 bytes.  Windows: the
  va_list is a pointer to the slots.  Linux x86-64 (System V): the va_list
  points to a descriptor whose register areas are marked as used up, so
  every argument is read from the slots ("overflow area"). }
type
{$IFDEF CPUAARCH64}
  TSysVVaList = record          { AAPCS64 va_list }
    stack, gr_top, vr_top: Pointer;
    gr_offs, vr_offs: Integer;
  end;
{$ELSE}
  TSysVVaList = record          { System V x86-64 va_list }
    gp_offset, fp_offset: Cardinal;
    overflow_arg_area, reg_save_area: Pointer;
  end;
{$ENDIF}
  TVaList = record
    slots: array[0..63] of NativeUInt;
    strs: array[0..15] of AnsiString;   { converted Unicode/short strings }
    sysv: TSysVVaList;
  end;

function VaListPtr(var va: TVaList): Pointer;
begin
{$IF defined(LUA_POSIX) and not (defined(DARWIN) and defined(CPUAARCH64))}
{$IFDEF CPUAARCH64}
  va.sysv.stack := @va.slots[0];   { register areas empty: all from the slots }
  va.sysv.gr_top := nil;
  va.sysv.vr_top := nil;
  va.sysv.gr_offs := 0;
  va.sysv.vr_offs := 0;
{$ELSE}
  va.sysv.gp_offset := 48;
  va.sysv.fp_offset := 176;
  va.sysv.overflow_arg_area := @va.slots[0];
  va.sysv.reg_save_area := nil;
{$ENDIF}
  Result := @va.sysv;
{$ELSE}
  Result := @va.slots[0];   { Windows, Apple ARM64: pointer to the slots }
{$IFEND}
end;

procedure BuildVaList(const args: array of const; var va: TVaList);
var i, n, ns: Integer; d: Double; p: Pointer;
  procedure PutPtr(x: Pointer);
  begin
    if n <= High(va.slots) then va.slots[n] := NativeUInt(x);
    Inc(n);
  end;
  procedure PutInt(x: Integer);
  begin
    if n <= High(va.slots) then va.slots[n] := NativeUInt(NativeInt(x));
    Inc(n);
  end;
  procedure PutStr(const s: AnsiString);
  begin
    if ns > High(va.strs) then begin PutPtr(nil); Exit; end;
    va.strs[ns] := s;
    if s = '' then PutPtr(PAnsiChar('')) else PutPtr(PAnsiChar(va.strs[ns]));
    Inc(ns);
  end;
begin
  n := 0; ns := 0;
  for i := 0 to High(args) do
    case args[i].VType of
      vtInteger: PutInt(args[i].VInteger);
      vtInt64: PutInt(Integer(args[i].VInt64^));
      vtBoolean: PutInt(Ord(args[i].VBoolean));
      vtChar: PutInt(Ord(args[i].VChar));
      vtWideChar: PutInt(Ord(args[i].VWideChar));
      vtExtended, vtCurrency:
        begin
          if args[i].VType = vtExtended then d := args[i].VExtended^ else d := args[i].VCurrency^;
          if n + SizeOf(Double) div SizeOf(NativeUInt) - 1 <= High(va.slots) then
            PDouble(@va.slots[n])^ := d;
          Inc(n, (SizeOf(Double) + SizeOf(NativeUInt) - 1) div SizeOf(NativeUInt));
        end;
      vtPChar: PutPtr(args[i].VPChar);
      vtPointer: PutPtr(args[i].VPointer);
      vtObject: PutPtr(args[i].VObject);
      vtAnsiString:
        begin
          p := args[i].VAnsiString;
          if p = nil then PutPtr(PAnsiChar('')) else PutPtr(p);
        end;
      vtUnicodeString: PutStr(AnsiString(UnicodeString(args[i].VUnicodeString)));
      vtWideString: PutStr(AnsiString(WideString(args[i].VWideString)));
      vtPWideChar: PutStr(AnsiString(WideString(args[i].VPWideChar)));
      vtString: PutStr(AnsiString(args[i].VString^));
    else
      PutPtr(nil);
    end;
end;

function lua_pushfstringf(L: Plua_State; fmt: PAnsiChar; const args: array of const): PAnsiChar;
var va: TVaList;
begin
  BuildVaList(args, va);
  Result := lua_pushvfstring(L, fmt, VaListPtr(va));
end;

function luaL_errorf(L: Plua_State; fmt: PAnsiChar; const args: array of const): Integer;
var va: TVaList; i: Integer;
begin
  BuildVaList(args, va);
  luaL_where(L, 1);
  lua_pushvfstring(L, fmt, VaListPtr(va));
  for i := 0 to High(va.strs) do va.strs[i] := '';  { free them before lua_error unwinds }
  lua_concat(L, 2);
  Result := lua_error(L);
end;

{$IFDEF CPUAARCH64}
{ AArch64: clear the FPCR trap-enable bits (IOE, DZE, OFE, UFE, IXE, IDE).
  Free Pascal programs start with IOE/DZE/OFE set; most ARM cores ignore
  them, but Apple Silicon traps (SIGILL) on 0/0 or 1/0. }
procedure clear_fp_traps; assembler; nostackframe;
asm
  mrs x0, fpcr
  movz x1, #40704         { $9F00: the trap-enable bits }
  mvn x1, x1
  and x0, x0, x1
  msr fpcr, x0
end;
{$ENDIF}

procedure lua_set_c_fpu_mode;
begin
{$IFDEF LUA_X86}
  Set8087CW($027F);   { MSVC default: 53-bit precision, round to nearest, exceptions masked }
{$ENDIF}
{$IFDEF LUA_64}{$IFNDEF CPUAARCH64}
  SetMXCSR($1F80);    { all SSE exceptions masked, round to nearest }
{$ENDIF}{$ENDIF}
{$IFDEF CPUAARCH64}
  clear_fp_traps;
{$IFDEF FPC}
  softfloat_exception_mask := [exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision];
{$ENDIF}
{$ENDIF}
end;

function lua_upvalueindex(i: Integer): Integer; begin Result := LUA_GLOBALSINDEX - i; end;
procedure lua_pop(L: Plua_State; n: Integer); begin lua_settop(L, -n - 1); end;
procedure lua_newtable(L: Plua_State); begin lua_createtable(L, 0, 0); end;
procedure lua_register(L: Plua_State; n: PAnsiChar; f: lua_CFunction);
begin
  lua_pushcclosure(L, f, 0);
  lua_setfield(L, LUA_GLOBALSINDEX, n);
end;
procedure lua_pushcfunction(L: Plua_State; f: lua_CFunction); begin lua_pushcclosure(L, f, 0); end;
function lua_strlen(L: Plua_State; i: Integer): size_t; begin Result := lua_objlen(L, i); end;
function lua_isfunction(L: Plua_State; n: Integer): Boolean; begin Result := lua_type(L, n) = LUA_TFUNCTION; end;
function lua_istable(L: Plua_State; n: Integer): Boolean; begin Result := lua_type(L, n) = LUA_TTABLE; end;
function lua_islightuserdata(L: Plua_State; n: Integer): Boolean; begin Result := lua_type(L, n) = LUA_TLIGHTUSERDATA; end;
function lua_isnil(L: Plua_State; n: Integer): Boolean; begin Result := lua_type(L, n) = LUA_TNIL; end;
function lua_isboolean(L: Plua_State; n: Integer): Boolean; begin Result := lua_type(L, n) = LUA_TBOOLEAN; end;
function lua_isthread(L: Plua_State; n: Integer): Boolean; begin Result := lua_type(L, n) = LUA_TTHREAD; end;
function lua_isnone(L: Plua_State; n: Integer): Boolean; begin Result := lua_type(L, n) = LUA_TNONE; end;
function lua_isnoneornil(L: Plua_State; n: Integer): Boolean; begin Result := lua_type(L, n) <= 0; end;
procedure lua_pushliteral(L: Plua_State; const s: AnsiString); begin lua_pushlstring(L, PAnsiChar(s), Length(s)); end;
procedure lua_setglobal(L: Plua_State; s: PAnsiChar); begin lua_setfield(L, LUA_GLOBALSINDEX, s); end;
procedure lua_getglobal(L: Plua_State; s: PAnsiChar); begin lua_getfield(L, LUA_GLOBALSINDEX, s); end;
function lua_tostring(L: Plua_State; i: Integer): PAnsiChar; begin Result := lua_tolstring(L, i, nil); end;
function lua_open: Plua_State; begin Result := luaL_newstate; end;
procedure lua_getregistry(L: Plua_State); begin lua_pushvalue(L, LUA_REGISTRYINDEX); end;
function lua_getgccount(L: Plua_State): Integer; begin Result := lua_gc(L, LUA_GCCOUNT, 0); end;
procedure luaL_argcheck(L: Plua_State; cond: Boolean; numarg: Integer; extramsg: PAnsiChar);
begin
  if not cond then luaL_argerror(L, numarg, extramsg);
end;
function luaL_checkstring(L: Plua_State; n: Integer): PAnsiChar; begin Result := luaL_checklstring(L, n, nil); end;
function luaL_optstring(L: Plua_State; n: Integer; d: PAnsiChar): PAnsiChar; begin Result := luaL_optlstring(L, n, d, nil); end;
function luaL_checkint(L: Plua_State; n: Integer): Integer; begin Result := Integer(luaL_checkinteger(L, n)); end;
function luaL_optint(L: Plua_State; n, d: Integer): Integer; begin Result := Integer(luaL_optinteger(L, n, d)); end;
function luaL_checklong(L: Plua_State; n: Integer): c_long; begin Result := c_long(luaL_checkinteger(L, n)); end;
function luaL_optlong(L: Plua_State; n: Integer; d: c_long): c_long; begin Result := c_long(luaL_optinteger(L, n, d)); end;
function luaL_typename(L: Plua_State; i: Integer): PAnsiChar; begin Result := lua_typename(L, lua_type(L, i)); end;
function luaL_dofile(L: Plua_State; fn: PAnsiChar): Integer;
begin
  Result := luaL_loadfile(L, fn);
  if Result = 0 then Result := lua_pcall(L, 0, LUA_MULTRET, 0);
end;
function luaL_dostring(L: Plua_State; s: PAnsiChar): Integer;
begin
  Result := luaL_loadstring(L, s);
  if Result = 0 then Result := lua_pcall(L, 0, LUA_MULTRET, 0);
end;
procedure luaL_getmetatable(L: Plua_State; n: PAnsiChar); begin lua_getfield(L, LUA_REGISTRYINDEX, n); end;
procedure luaL_addchar(B: PluaL_Buffer; c: AnsiChar);
begin
  if not (NativeUInt(B^.p) < NativeUInt(@B^.buffer[0]) + LUAL_BUFFERSIZE) then
    luaL_prepbuffer(B);
  B^.p^ := c;
  Inc(B^.p);
end;
procedure luaL_addsize(B: PluaL_Buffer; n: size_t); begin Inc(B^.p, n); end;
function luaL_getn(L: Plua_State; i: Integer): Integer; begin Result := Integer(lua_objlen(L, i)); end;
function lua_ref(L: Plua_State; lock: Boolean): Integer;
begin
  if lock then
    Result := luaL_ref(L, LUA_REGISTRYINDEX)
  else
  begin
    lua_pushstring(L, 'unlocked references are obsolete');
    lua_error(L);
    Result := 0;
  end;
end;
procedure lua_unref(L: Plua_State; ref: Integer); begin luaL_unref(L, LUA_REGISTRYINDEX, ref); end;
procedure lua_getref(L: Plua_State; ref: Integer); begin lua_rawgeti(L, LUA_REGISTRYINDEX, ref); end;

end.
