{
  Lua 5.1.4 - Pascal port
  Types, constants and macros from lua.h, luaconf.h, llimits.h, lobject.h,
  lstate.h, ltm.h, lzio.h, lopcodes.h, lgc.h, llex.h, lparser.h, lcode.h,
  lauxlib.h and lualib.h.

  Copyright (C) 1994-2008 Lua.org, PUC-Rio.  (MIT license, see LICENSE)
}
unit LuaTypes;

{$I lua.inc}

interface
const

{ ======================================================================
  Basic C types
  ====================================================================== }
  LUA_PATH_ENV   = 'LUA_PATH';
  LUA_CPATH_ENV  = 'LUA_CPATH';
  LUA_INIT_ENV   = 'LUA_INIT';
{$IFDEF LUA_POSIX}
  LUA_ROOT  = '/usr/local/';
  LUA_LDIR  = LUA_ROOT + 'share/lua/5.1/';
  LUA_CDIR  = LUA_ROOT + 'lib/lua/5.1/';
  LUA_PATH_DEFAULT  = './?.lua;' + LUA_LDIR + '?.lua;' + LUA_LDIR + '?/init.lua;' +
                      LUA_CDIR + '?.lua;' + LUA_CDIR + '?/init.lua';
  LUA_CPATH_DEFAULT = './?.so;' + LUA_CDIR + '?.so;' + LUA_CDIR + 'loadall.so';
  LUA_DIRSEP    = '/';
{$ELSE}
  LUA_LDIR  = '!\lua\';
  LUA_CDIR  = '!\';
  LUA_PATH_DEFAULT  = '.\?.lua;' + LUA_LDIR + '?.lua;' + LUA_LDIR + '?\init.lua;' +
                      LUA_CDIR + '?.lua;' + LUA_CDIR + '?\init.lua';
  LUA_CPATH_DEFAULT = '.\?.dll;' + LUA_CDIR + '?.dll;' + LUA_CDIR + 'loadall.dll';
  LUA_DIRSEP    = '\';
{$ENDIF}
  LUA_PATHSEP   = ';';
  LUA_PATH_MARK = '?';
  LUA_EXECDIR   = '!';
  LUA_IGMARK    = '-';
  LUA_IDSIZE    = 60;
  LUAI_GCPAUSE  = 200;
  LUAI_GCMUL    = 200;
  LUAI_BITSINT  = 32;
  LUAI_MAXCALLS = 20000;
  LUAI_MAXCSTACK = 8000;
  LUAI_MAXCCALLS = 200;
  LUAI_MAXVARS  = 200;
  LUAI_MAXUPVALUES = 60;
  LUAL_BUFFERSIZE = 512;            { BUFSIZ of the MS C runtime }
  LUAI_MAXNUMBER2STR = 32;
  LUA_MAXCAPTURES = 32;
  LUAI_EXTRASPACE = 0;

{ ======================================================================
  lua.h
  ====================================================================== }
  LUA_VERSION   = 'Lua 5.1';
  LUA_RELEASE   = 'Lua 5.1.4';
  LUA_VERSION_NUM = 501;
  LUA_COPYRIGHT = 'Copyright (C) 1994-2008 Lua.org, PUC-Rio';
  LUA_AUTHORS   = 'R. Ierusalimschy, L. H. de Figueiredo & W. Celes';
  LUA_SIGNATURE = #27'Lua';
  LUA_SIGNATURE_CHAR = AnsiChar(#27);  { LUA_SIGNATURE[0] in C }

  LUA_MULTRET = -1;

  LUA_REGISTRYINDEX = -10000;
  LUA_ENVIRONINDEX  = -10001;
  LUA_GLOBALSINDEX  = -10002;

  LUA_YIELD_    = 1;
  LUA_ERRRUN    = 2;
  LUA_ERRSYNTAX = 3;
  LUA_ERRMEM    = 4;
  LUA_ERRERR    = 5;

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

  LUA_GCSTOP       = 0;
  LUA_GCRESTART    = 1;
  LUA_GCCOLLECT    = 2;
  LUA_GCCOUNT      = 3;
  LUA_GCCOUNTB     = 4;
  LUA_GCSTEP       = 5;
  LUA_GCSETPAUSE   = 6;
  LUA_GCSETSTEPMUL = 7;

  LUA_HOOKCALL    = 0;
  LUA_HOOKRET     = 1;
  LUA_HOOKLINE    = 2;
  LUA_HOOKCOUNT   = 3;
  LUA_HOOKTAILRET = 4;

  LUA_MASKCALL  = 1 shl LUA_HOOKCALL;
  LUA_MASKRET   = 1 shl LUA_HOOKRET;
  LUA_MASKLINE  = 1 shl LUA_HOOKLINE;
  LUA_MASKCOUNT = 1 shl LUA_HOOKCOUNT;

{ lauxlib.h / lualib.h }
  LUA_ERRFILE = LUA_ERRERR + 1;
  LUA_NOREF   = -2;
  LUA_REFNIL  = -1;
  LUA_FILEHANDLE  = 'FILE*';
  LUA_COLIBNAME   = 'coroutine';
  LUA_TABLIBNAME  = 'table';
  LUA_IOLIBNAME   = 'io';
  LUA_OSLIBNAME   = 'os';
  LUA_STRLIBNAME  = 'string';
  LUA_MATHLIBNAME = 'math';
  LUA_DBLIBNAME   = 'debug';
  LUA_LOADLIBNAME = 'package';

  MAX_SIZET = High(NativeUInt) - 2;
  MAX_LUMEM = High(NativeUInt) - 2;
  MAX_INT   = High(Integer) - 2;
  MAXSTACK  = 250;
  MINSTRTABSIZE = 32;
  LUA_MINBUFFER = 32;

{ ======================================================================
  lobject.h
  ====================================================================== }
  LAST_TAG     = LUA_TTHREAD;
  NUM_TAGS     = LAST_TAG + 1;
  LUA_TPROTO   = LAST_TAG + 1;
  LUA_TUPVAL   = LAST_TAG + 2;
  LUA_TDEADKEY = LAST_TAG + 3;

  VARARG_HASARG   = 1;
  VARARG_ISVARARG = 2;
  VARARG_NEEDSARG = 4;

  TM_INDEX    = 0;
  TM_NEWINDEX = 1;
  TM_GC       = 2;
  TM_MODE     = 3;
  TM_EQ       = 4;
  TM_ADD      = 5;
  TM_SUB      = 6;
  TM_MUL      = 7;
  TM_DIV      = 8;
  TM_MOD      = 9;
  TM_POW      = 10;
  TM_UNM      = 11;
  TM_LEN      = 12;
  TM_LT       = 13;
  TM_LE       = 14;
  TM_CONCAT   = 15;
  TM_CALL     = 16;
  TM_N        = 17;
  EOZ = -1;
  EXTRA_STACK   = 5;
  BASIC_CI_SIZE = 8;
  BASIC_STACK_SIZE = 2 * LUA_MINSTACK;

  iABC = 0; iABx = 1; iAsBx = 2;

  SIZE_C  = 9;
  SIZE_B  = 9;
  SIZE_Bx = SIZE_C + SIZE_B;
  SIZE_A  = 8;
  SIZE_OP = 6;
  POS_OP  = 0;
  POS_A   = POS_OP + SIZE_OP;
  POS_C   = POS_A + SIZE_A;
  POS_B   = POS_C + SIZE_C;
  POS_Bx  = POS_C;

  MASK_OP = (1 shl SIZE_OP) - 1;
  MASK_A  = (1 shl SIZE_A) - 1;
  MASK_B  = (1 shl SIZE_B) - 1;
  MASK_C  = (1 shl SIZE_C) - 1;
  MASK_Bx = (1 shl SIZE_Bx) - 1;

  MAXARG_Bx  = (1 shl SIZE_Bx) - 1;
  MAXARG_sBx = MAXARG_Bx shr 1;
  MAXARG_A   = (1 shl SIZE_A) - 1;
  MAXARG_B   = (1 shl SIZE_B) - 1;
  MAXARG_C   = (1 shl SIZE_C) - 1;

  BITRK      = 1 shl (SIZE_B - 1);
  MAXINDEXRK = BITRK - 1;
  NO_REG     = MAXARG_A;

  OP_MOVE = 0;  OP_LOADK = 1;  OP_LOADBOOL = 2;  OP_LOADNIL = 3;
  OP_GETUPVAL = 4;  OP_GETGLOBAL = 5;  OP_GETTABLE = 6;  OP_SETGLOBAL = 7;
  OP_SETUPVAL = 8;  OP_SETTABLE = 9;  OP_NEWTABLE = 10;  OP_SELF = 11;
  OP_ADD = 12;  OP_SUB = 13;  OP_MUL = 14;  OP_DIV = 15;  OP_MOD = 16;
  OP_POW = 17;  OP_UNM = 18;  OP_NOT = 19;  OP_LEN = 20;  OP_CONCAT = 21;
  OP_JMP = 22;  OP_EQ = 23;  OP_LT = 24;  OP_LE = 25;  OP_TEST = 26;
  OP_TESTSET = 27;  OP_CALL = 28;  OP_TAILCALL = 29;  OP_RETURN = 30;
  OP_FORLOOP = 31;  OP_FORPREP = 32;  OP_TFORLOOP = 33;  OP_SETLIST = 34;
  OP_CLOSE = 35;  OP_CLOSURE = 36;  OP_VARARG = 37;
  NUM_OPCODES = OP_VARARG + 1;

  OpArgN = 0; OpArgU = 1; OpArgR = 2; OpArgK = 3;

  LFIELDS_PER_FLUSH = 50;

  GCSpause       = 0;
  GCSpropagate   = 1;
  GCSsweepstring = 2;
  GCSsweep       = 3;
  GCSfinalize    = 4;

  WHITE0BIT    = 0;
  WHITE1BIT    = 1;
  BLACKBIT     = 2;
  FINALIZEDBIT = 3;
  KEYWEAKBIT   = 3;
  VALUEWEAKBIT = 4;
  FIXEDBIT     = 5;
  SFIXEDBIT    = 6;
  WHITEBITS    = (1 shl WHITE0BIT) or (1 shl WHITE1BIT);

{ ======================================================================
  llex.h
  ====================================================================== }
  FIRST_RESERVED = 257;
  TK_AND = FIRST_RESERVED; TK_BREAK = 258; TK_DO = 259; TK_ELSE = 260;
  TK_ELSEIF = 261; TK_END = 262; TK_FALSE = 263; TK_FOR = 264;
  TK_FUNCTION = 265; TK_IF = 266; TK_IN = 267; TK_LOCAL = 268; TK_NIL = 269;
  TK_NOT = 270; TK_OR = 271; TK_REPEAT = 272; TK_RETURN = 273; TK_THEN = 274;
  TK_TRUE = 275; TK_UNTIL = 276; TK_WHILE = 277;
  TK_CONCAT = 278; TK_DOTS = 279; TK_EQ = 280; TK_GE = 281; TK_LE = 282;
  TK_NE = 283; TK_NUMBER = 284; TK_NAME = 285; TK_STRING = 286; TK_EOS = 287;
  NUM_RESERVED = TK_WHILE - FIRST_RESERVED + 1;

  VVOID = 0; VNIL = 1; VTRUE = 2; VFALSE = 3; VK = 4; VKNUM = 5; VLOCAL = 6;
  VUPVAL = 7; VGLOBAL = 8; VINDEXED = 9; VJMP = 10; VRELOCABLE = 11;
  VNONRELOC = 12; VCALL = 13; VVARARG = 14;

  NO_JUMP = -1;

  OPR_ADD = 0; OPR_SUB = 1; OPR_MUL = 2; OPR_DIV = 3; OPR_MOD = 4; OPR_POW = 5;
  OPR_CONCAT = 6; OPR_NE = 7; OPR_EQ = 8; OPR_LT = 9; OPR_LE = 10; OPR_GT = 11;
  OPR_GE = 12; OPR_AND = 13; OPR_OR = 14; OPR_NOBINOPR = 15;

  OPR_MINUS = 0; OPR_NOT = 1; OPR_LEN = 2; OPR_NOUNOPR = 3;

type
  size_t      = NativeUInt;
  Psize_t     = ^size_t;
  ptrdiff_t   = NativeInt;
  lua_Number  = Double;
  Plua_Number = ^lua_Number;
  lua_Integer = NativeInt;          { ptrdiff_t }
  lu_int32    = Cardinal;
  lu_mem      = NativeUInt;
  l_mem       = NativeInt;
  lu_byte     = Byte;
  Plu_byte    = ^lu_byte;
  Instruction = Cardinal;
  { C 'long' / 'unsigned long': 32-bit on Windows, 64-bit on Linux x86-64 }
{$IFDEF LUA_POSIX}
  c_long = Int64;
  c_ulong = {$IFDEF FPC}QWord{$ELSE}UInt64{$ENDIF};
{$ELSE}
  c_long = Integer;
  c_ulong = Cardinal;
{$ENDIF}
  PInstruction = ^Instruction;

{ ======================================================================
  luaconf.h
  ====================================================================== }
  Plua_State = ^lua_State;
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

{ ======================================================================
  llimits.h
  ====================================================================== }
  PGCObject  = ^TGCObject;
  PPGCObject = ^PGCObject;
  PTValue    = ^TValue;
  StkId      = PTValue;
  PTString   = ^TTString;
  PPTString  = ^PTString;
  PUdata     = ^TUdata;
  PProto     = ^TProto;
  PPProto    = ^PProto;
  PLocVar    = ^TLocVar;
  PUpVal     = ^TUpVal;
  PPUpVal    = ^PUpVal;
  PClosure   = ^TClosure;
  PCClosure  = ^TCClosure;
  PLClosure  = ^TLClosure;
  PTable     = ^TTable;
  PNode      = ^TNode;
  PCallInfo  = ^TCallInfo;
  Pglobal_State = ^global_State;
  Plua_longjmp = ^lua_longjmp;

  { common header of every collectable object (GCheader) }
  TGCObject = record
    next: PGCObject;
    tt: lu_byte;
    marked: lu_byte;
  end;

  TValueUnion = record
    case Integer of
      0: (gc: PGCObject);
      1: (p: Pointer);
      2: (n: lua_Number);
      3: (b: Integer);
  end;

  TValue = record
    value: TValueUnion;
    tt: Integer;
  end;

  TTString = record
    next: PGCObject;
    tt: lu_byte;
    marked: lu_byte;
    reserved: lu_byte;
    hash: Cardinal;
    len: size_t;
  end;

  TUdata = record
    next: PGCObject;
    tt: lu_byte;
    marked: lu_byte;
    metatable: PTable;
    env: PTable;
    len: size_t;
  end;

  TLocVar = record
    varname: PTString;
    startpc: Integer;
    endpc: Integer;
  end;

  TProto = record
    next: PGCObject;
    tt: lu_byte;
    marked: lu_byte;
    k: PTValue;
    code: PInstruction;
    p: PPProto;
    lineinfo: PInteger;
    locvars: PLocVar;
    upvalues: PPTString;
    source: PTString;
    sizeupvalues: Integer;
    sizek: Integer;
    sizecode: Integer;
    sizelineinfo: Integer;
    sizep: Integer;
    sizelocvars: Integer;
    linedefined: Integer;
    lastlinedefined: Integer;
    gclist: PGCObject;
    nups: lu_byte;
    numparams: lu_byte;
    is_vararg: lu_byte;
    maxstacksize: lu_byte;
  end;

  TUpVal = record
    next: PGCObject;
    tt: lu_byte;
    marked: lu_byte;
    v: PTValue;
    case Integer of
      0: (value: TValue);                { closed upvalue }
      1: (prev: PUpVal; lnext: PUpVal);  { open upvalue: double linked list }
  end;

  TCClosure = record
    next: PGCObject;
    tt: lu_byte;
    marked: lu_byte;
    isC: lu_byte;
    nupvalues: lu_byte;
    gclist: PGCObject;
    env: PTable;
    f: lua_CFunction;
    upvalue: array[0..0] of TValue;
  end;

  TLClosure = record
    next: PGCObject;
    tt: lu_byte;
    marked: lu_byte;
    isC: lu_byte;
    nupvalues: lu_byte;
    gclist: PGCObject;
    env: PTable;
    p: PProto;
    upvals: array[0..0] of PUpVal;
  end;

  TClosure = record
    case Integer of
      0: (c: TCClosure);
      1: (l: TLClosure);
  end;

  TTKey = record
    value: TValueUnion;
    tt: Integer;
    next: PNode;
  end;

  TNode = record
    i_val: TValue;
    i_key: TTKey;
  end;

  TTable = record
    next: PGCObject;
    tt: lu_byte;
    marked: lu_byte;
    flags: lu_byte;
    lsizenode: lu_byte;
    metatable: PTable;
    arr: PTValue;
    node: PNode;
    lastfree: PNode;
    gclist: PGCObject;
    sizearray: Integer;
  end;

{ ======================================================================
  ltm.h
  ====================================================================== }
  TMS = Integer;

{ ======================================================================
  lzio.h
  ====================================================================== }
  PMbuffer = ^TMbuffer;
  TMbuffer = record
    buffer: PAnsiChar;
    n: size_t;
    buffsize: size_t;
  end;

  PZIO = ^TZIO;
  TZIO = record
    n: size_t;
    p: PAnsiChar;
    reader: lua_Reader;
    data: Pointer;
    L: Plua_State;
  end;

{ ======================================================================
  lstate.h
  ====================================================================== }
  Tstringtable = record
    hash: PPGCObject;
    nuse: lu_int32;
    size: Integer;
  end;

  TCallInfo = record
    base: StkId;
    func: StkId;
    top: StkId;
    savedpc: PInstruction;
    nresults: Integer;
    tailcalls: Integer;
  end;

  global_State = record
    strt: Tstringtable;
    frealloc: lua_Alloc;
    ud: Pointer;
    currentwhite: lu_byte;
    gcstate: lu_byte;
    sweepstrgc: Integer;
    rootgc: PGCObject;
    sweepgc: PPGCObject;
    gray: PGCObject;
    grayagain: PGCObject;
    weak: PGCObject;
    tmudata: PGCObject;
    buff: TMbuffer;
    GCthreshold: lu_mem;
    totalbytes: lu_mem;
    estimate: lu_mem;
    gcdept: lu_mem;
    gcpause: Integer;
    gcstepmul: Integer;
    panic: lua_CFunction;
    l_registry: TValue;
    mainthread: Plua_State;
    uvhead: TUpVal;
    mt: array[0..NUM_TAGS - 1] of PTable;
    tmname: array[0..TM_N - 1] of PTString;
  end;

  lua_longjmp = record
    previous: Plua_longjmp;
    status: Integer;
  end;

  lua_State = record
    next: PGCObject;
    tt: lu_byte;
    marked: lu_byte;
    status: lu_byte;
    top: StkId;
    base: StkId;
    l_G: Pglobal_State;
    ci: PCallInfo;
    savedpc: PInstruction;
    stack_last: StkId;
    stack: StkId;
    end_ci: PCallInfo;
    base_ci: PCallInfo;
    stacksize: Integer;
    size_ci: Integer;
    nCcalls: Word;
    baseCcalls: Word;
    hookmask: lu_byte;
    allowhook: lu_byte;
    basehookcount: Integer;
    hookcount: Integer;
    hook: lua_Hook;
    l_gt: TValue;
    env: TValue;
    openupval: PGCObject;
    gclist: PGCObject;
    errorJmp: Plua_longjmp;
    errfunc: ptrdiff_t;
  end;

{ ======================================================================
  lopcodes.h
  ====================================================================== }
  OpCode = Integer;

{ ======================================================================
  lgc.h
  ====================================================================== }
  PFuncState = ^TFuncState;
  PLexState = ^TLexState;
  PBlockCnt = ^TBlockCnt;

  PSemInfo = ^TSemInfo;
  TSemInfo = record
    case Integer of
      0: (r: lua_Number);
      1: (ts: PTString);
  end;

  TToken = record
    token: Integer;
    seminfo: TSemInfo;
  end;

  TLexState = record
    current: Integer;
    linenumber: Integer;
    lastline: Integer;
    t: TToken;
    lookahead: TToken;
    fs: PFuncState;
    L: Plua_State;
    z: PZIO;
    buff: PMbuffer;
    source: PTString;
    decpoint: AnsiChar;
  end;

{ ======================================================================
  lparser.h / lcode.h
  ====================================================================== }
  expkind = Integer;
  BinOpr = Integer;
  UnOpr = Integer;

  Pexpdesc = ^Texpdesc;
  Texpdesc = record
    k: expkind;
    case Integer of
      0: (info, aux: Integer; t, f: Integer);
      1: (nval: lua_Number);
  end;

  Tupvaldesc = record
    k: lu_byte;
    info: lu_byte;
  end;

  TBlockCnt = record
    previous: PBlockCnt;
    breaklist: Integer;
    nactvar: lu_byte;
    upval: lu_byte;
    isbreakable: lu_byte;
  end;

  TFuncState = record
    f: PProto;
    h: PTable;
    prev: PFuncState;
    ls: PLexState;
    L: Plua_State;
    bl: PBlockCnt;
    pc: Integer;
    lasttarget: Integer;
    jpc: Integer;
    freereg: Integer;
    nk: Integer;
    np: Integer;
    nlocvars: SmallInt;
    nactvar: lu_byte;
    upvalues: array[0..LUAI_MAXUPVALUES - 1] of Tupvaldesc;
    actvar: array[0..LUAI_MAXVARS - 1] of Word;
  end;

{ ======================================================================
  Sizes of variable-length objects (C: sizeof(union ...) is 8-aligned)
  ====================================================================== }
const
  TSTRING_SIZE = (SizeOf(TTString) + 7) and not 7;
  UDATA_SIZE   = (SizeOf(TUdata) + 7) and not 7;

{ ======================================================================
  Macros as inline functions
  ====================================================================== }

{ lobject.h }
function ttype(o: PTValue): Integer; inline;
function ttisnil(o: PTValue): Boolean; inline;
function ttisnumber(o: PTValue): Boolean; inline;
function ttisstring(o: PTValue): Boolean; inline;
function ttistable(o: PTValue): Boolean; inline;
function ttisfunction(o: PTValue): Boolean; inline;
function ttisboolean(o: PTValue): Boolean; inline;
function ttisuserdata(o: PTValue): Boolean; inline;
function ttisthread(o: PTValue): Boolean; inline;
function ttislightuserdata(o: PTValue): Boolean; inline;
function iscollectable(o: PTValue): Boolean; inline;
function gcvalue(o: PTValue): PGCObject; inline;
function pvalue(o: PTValue): Pointer; inline;
function nvalue(o: PTValue): lua_Number; inline;
function rawtsvalue(o: PTValue): PTString; inline;
function tsvalue(o: PTValue): PTString; inline;
function rawuvalue(o: PTValue): PUdata; inline;
function uvalue(o: PTValue): PUdata; inline;
function clvalue(o: PTValue): PClosure; inline;
function hvalue(o: PTValue): PTable; inline;
function bvalue(o: PTValue): Integer; inline;
function thvalue(o: PTValue): Plua_State; inline;
function l_isfalse(o: PTValue): Boolean; inline;
function getstr(ts: PTString): PAnsiChar; inline;
function svalue(o: PTValue): PAnsiChar; inline;

procedure setnilvalue(obj: PTValue); inline;
procedure setnvalue(obj: PTValue; x: lua_Number); inline;
procedure setpvalue(obj: PTValue; x: Pointer); inline;
procedure setbvalue(obj: PTValue; x: Integer); inline;
procedure setsvalue(L: Plua_State; obj: PTValue; x: PTString); inline;
procedure setuvalue(L: Plua_State; obj: PTValue; x: PUdata); inline;
procedure setthvalue(L: Plua_State; obj: PTValue; x: Plua_State); inline;
procedure setclvalue(L: Plua_State; obj: PTValue; x: PClosure); inline;
procedure sethvalue(L: Plua_State; obj: PTValue; x: PTable); inline;
procedure setptvalue(L: Plua_State; obj: PTValue; x: PProto); inline;
procedure setobj(L: Plua_State; obj1, obj2: PTValue); inline;

function iscfunction(o: PTValue): Boolean; inline;
function isLfunction(o: PTValue): Boolean; inline;

function lmod(s: Cardinal; size: Integer): Integer; inline;
function twoto(x: Integer): Integer; inline;
function sizenode(t: PTable): Integer; inline;

{ ltable.h }
function gnode(t: PTable; i: Integer): PNode; inline;
function gkey(n: PNode): PTValue; inline;
function gval(n: PNode): PTValue; inline;
function key2tval(n: PNode): PTValue; inline;

{ lstate.h }
function G(L: Plua_State): Pglobal_State; inline;
function gt(L: Plua_State): PTValue; inline;
function registry(L: Plua_State): PTValue; inline;
function curr_func(L: Plua_State): PClosure; inline;
function ci_func(ci: PCallInfo): PClosure; inline;
function f_isLua(ci: PCallInfo): Boolean; inline;
function isLua(ci: PCallInfo): Boolean; inline;
function obj2gco(v: Pointer): PGCObject; inline;
function gco2th(o: PGCObject): Plua_State; inline;
function gco2ts(o: PGCObject): PTString; inline;
function gco2u(o: PGCObject): PUdata; inline;
function gco2cl(o: PGCObject): PClosure; inline;
function gco2h(o: PGCObject): PTable; inline;
function gco2p(o: PGCObject): PProto; inline;
function gco2uv(o: PGCObject): PUpVal; inline;

{ lgc.h }
function iswhite(x: PGCObject): Boolean; inline;
function isblack(x: PGCObject): Boolean; inline;
function isgray(x: PGCObject): Boolean; inline;
function otherwhite(g: Pglobal_State): lu_byte; inline;
function isdead(g: Pglobal_State; v: PGCObject): Boolean; inline;
procedure changewhite(x: PGCObject); inline;
procedure gray2black(x: PGCObject); inline;
function valiswhite(x: PTValue): Boolean; inline;
function luaC_white(g: Pglobal_State): lu_byte; inline;

{ lopcodes.h }
function GET_OPCODE(i: Instruction): OpCode; inline;
procedure SET_OPCODE(var i: Instruction; o: OpCode); inline;
function GETARG_A(i: Instruction): Integer; inline;
procedure SETARG_A(var i: Instruction; u: Integer); inline;
function GETARG_B(i: Instruction): Integer; inline;
procedure SETARG_B(var i: Instruction; b: Integer); inline;
function GETARG_C(i: Instruction): Integer; inline;
procedure SETARG_C(var i: Instruction; b: Integer); inline;
function GETARG_Bx(i: Instruction): Integer; inline;
procedure SETARG_Bx(var i: Instruction; b: Integer); inline;
function GETARG_sBx(i: Instruction): Integer; inline;
procedure SETARG_sBx(var i: Instruction; b: Integer); inline;
function CREATE_ABC(o, a, b, c: Integer): Instruction; inline;
function CREATE_ABx(o, a: Integer; bc: Cardinal): Instruction; inline;
function ISK(x: Integer): Boolean; inline;
function INDEXK(r: Integer): Integer; inline;
function RKASK(x: Integer): Integer; inline;

{ lzio.h }
procedure luaZ_initbuffer(buff: PMbuffer); inline;
procedure luaZ_resetbuffer(buff: PMbuffer); inline;

{ stack pointer arithmetic helpers }
function savestack(L: Plua_State; p: StkId): ptrdiff_t; inline;
function restorestack(L: Plua_State; n: ptrdiff_t): StkId; inline;
function saveci(L: Plua_State; p: PCallInfo): ptrdiff_t; inline;
function restoreci(L: Plua_State; n: ptrdiff_t): PCallInfo; inline;
function StkDiff(a, b: StkId): Integer; inline;       { a - b in elements }

implementation

function ttype(o: PTValue): Integer; begin Result := o^.tt; end;
function ttisnil(o: PTValue): Boolean; begin Result := o^.tt = LUA_TNIL; end;
function ttisnumber(o: PTValue): Boolean; begin Result := o^.tt = LUA_TNUMBER; end;
function ttisstring(o: PTValue): Boolean; begin Result := o^.tt = LUA_TSTRING; end;
function ttistable(o: PTValue): Boolean; begin Result := o^.tt = LUA_TTABLE; end;
function ttisfunction(o: PTValue): Boolean; begin Result := o^.tt = LUA_TFUNCTION; end;
function ttisboolean(o: PTValue): Boolean; begin Result := o^.tt = LUA_TBOOLEAN; end;
function ttisuserdata(o: PTValue): Boolean; begin Result := o^.tt = LUA_TUSERDATA; end;
function ttisthread(o: PTValue): Boolean; begin Result := o^.tt = LUA_TTHREAD; end;
function ttislightuserdata(o: PTValue): Boolean; begin Result := o^.tt = LUA_TLIGHTUSERDATA; end;
function iscollectable(o: PTValue): Boolean; begin Result := o^.tt >= LUA_TSTRING; end;
function gcvalue(o: PTValue): PGCObject; begin Result := o^.value.gc; end;
function pvalue(o: PTValue): Pointer; begin Result := o^.value.p; end;
function nvalue(o: PTValue): lua_Number; begin Result := o^.value.n; end;
function rawtsvalue(o: PTValue): PTString; begin Result := PTString(o^.value.gc); end;
function tsvalue(o: PTValue): PTString; begin Result := PTString(o^.value.gc); end;
function rawuvalue(o: PTValue): PUdata; begin Result := PUdata(o^.value.gc); end;
function uvalue(o: PTValue): PUdata; begin Result := PUdata(o^.value.gc); end;
function clvalue(o: PTValue): PClosure; begin Result := PClosure(o^.value.gc); end;
function hvalue(o: PTValue): PTable; begin Result := PTable(o^.value.gc); end;
function bvalue(o: PTValue): Integer; begin Result := o^.value.b; end;
function thvalue(o: PTValue): Plua_State; begin Result := Plua_State(o^.value.gc); end;

function l_isfalse(o: PTValue): Boolean;
begin
  Result := (o^.tt = LUA_TNIL) or ((o^.tt = LUA_TBOOLEAN) and (o^.value.b = 0));
end;

function getstr(ts: PTString): PAnsiChar; begin Result := PAnsiChar(ts) + TSTRING_SIZE; end;
function svalue(o: PTValue): PAnsiChar; begin Result := PAnsiChar(o^.value.gc) + TSTRING_SIZE; end;

procedure setnilvalue(obj: PTValue); begin obj^.tt := LUA_TNIL; end;
procedure setnvalue(obj: PTValue; x: lua_Number); begin obj^.value.n := x; obj^.tt := LUA_TNUMBER; end;
procedure setpvalue(obj: PTValue; x: Pointer); begin obj^.value.p := x; obj^.tt := LUA_TLIGHTUSERDATA; end;
procedure setbvalue(obj: PTValue; x: Integer); begin obj^.value.b := x; obj^.tt := LUA_TBOOLEAN; end;
procedure setsvalue(L: Plua_State; obj: PTValue; x: PTString); begin obj^.value.gc := PGCObject(x); obj^.tt := LUA_TSTRING; end;
procedure setuvalue(L: Plua_State; obj: PTValue; x: PUdata); begin obj^.value.gc := PGCObject(x); obj^.tt := LUA_TUSERDATA; end;
procedure setthvalue(L: Plua_State; obj: PTValue; x: Plua_State); begin obj^.value.gc := PGCObject(x); obj^.tt := LUA_TTHREAD; end;
procedure setclvalue(L: Plua_State; obj: PTValue; x: PClosure); begin obj^.value.gc := PGCObject(x); obj^.tt := LUA_TFUNCTION; end;
procedure sethvalue(L: Plua_State; obj: PTValue; x: PTable); begin obj^.value.gc := PGCObject(x); obj^.tt := LUA_TTABLE; end;
procedure setptvalue(L: Plua_State; obj: PTValue; x: PProto); begin obj^.value.gc := PGCObject(x); obj^.tt := LUA_TPROTO; end;
procedure setobj(L: Plua_State; obj1, obj2: PTValue); begin obj1^.value := obj2^.value; obj1^.tt := obj2^.tt; end;

function iscfunction(o: PTValue): Boolean;
begin
  Result := (o^.tt = LUA_TFUNCTION) and (PClosure(o^.value.gc)^.c.isC <> 0);
end;

function isLfunction(o: PTValue): Boolean;
begin
  Result := (o^.tt = LUA_TFUNCTION) and (PClosure(o^.value.gc)^.c.isC = 0);
end;

function lmod(s: Cardinal; size: Integer): Integer; begin Result := Integer(s and Cardinal(size - 1)); end;
function twoto(x: Integer): Integer; begin Result := 1 shl x; end;
function sizenode(t: PTable): Integer; begin Result := 1 shl t^.lsizenode; end;

function gnode(t: PTable; i: Integer): PNode; begin Result := @t^.node[i]; end;
function gkey(n: PNode): PTValue; begin Result := PTValue(@n^.i_key); end;
function gval(n: PNode): PTValue; begin Result := @n^.i_val; end;
function key2tval(n: PNode): PTValue; begin Result := PTValue(@n^.i_key); end;

function G(L: Plua_State): Pglobal_State; begin Result := L^.l_G; end;
function gt(L: Plua_State): PTValue; begin Result := @L^.l_gt; end;
function registry(L: Plua_State): PTValue; begin Result := @L^.l_G^.l_registry; end;
function curr_func(L: Plua_State): PClosure; begin Result := PClosure(L^.ci^.func^.value.gc); end;
function ci_func(ci: PCallInfo): PClosure; begin Result := PClosure(ci^.func^.value.gc); end;
function f_isLua(ci: PCallInfo): Boolean; begin Result := PClosure(ci^.func^.value.gc)^.c.isC = 0; end;
function isLua(ci: PCallInfo): Boolean;
begin
  Result := (ci^.func^.tt = LUA_TFUNCTION) and (PClosure(ci^.func^.value.gc)^.c.isC = 0);
end;
function obj2gco(v: Pointer): PGCObject; begin Result := PGCObject(v); end;
function gco2th(o: PGCObject): Plua_State; begin Result := Plua_State(o); end;
function gco2ts(o: PGCObject): PTString; begin Result := PTString(o); end;
function gco2u(o: PGCObject): PUdata; begin Result := PUdata(o); end;
function gco2cl(o: PGCObject): PClosure; begin Result := PClosure(o); end;
function gco2h(o: PGCObject): PTable; begin Result := PTable(o); end;
function gco2p(o: PGCObject): PProto; begin Result := PProto(o); end;
function gco2uv(o: PGCObject): PUpVal; begin Result := PUpVal(o); end;

function iswhite(x: PGCObject): Boolean; begin Result := (x^.marked and WHITEBITS) <> 0; end;
function isblack(x: PGCObject): Boolean; begin Result := (x^.marked and (1 shl BLACKBIT)) <> 0; end;
function isgray(x: PGCObject): Boolean;
begin
  Result := ((x^.marked and (1 shl BLACKBIT)) = 0) and ((x^.marked and WHITEBITS) = 0);
end;
function otherwhite(g: Pglobal_State): lu_byte; begin Result := g^.currentwhite xor WHITEBITS; end;
function isdead(g: Pglobal_State; v: PGCObject): Boolean;
begin
  Result := (v^.marked and (g^.currentwhite xor WHITEBITS) and WHITEBITS) <> 0;
end;
procedure changewhite(x: PGCObject); begin x^.marked := x^.marked xor WHITEBITS; end;
procedure gray2black(x: PGCObject); begin x^.marked := x^.marked or (1 shl BLACKBIT); end;
function valiswhite(x: PTValue): Boolean;
begin
  Result := (x^.tt >= LUA_TSTRING) and ((x^.value.gc^.marked and WHITEBITS) <> 0);
end;
function luaC_white(g: Pglobal_State): lu_byte; begin Result := g^.currentwhite and WHITEBITS; end;

function GET_OPCODE(i: Instruction): OpCode; begin Result := Integer(i and MASK_OP); end;
procedure SET_OPCODE(var i: Instruction; o: OpCode);
begin
  i := (i and Instruction($FFFFFFFF xor (MASK_OP shl POS_OP))) or ((Instruction(o) shl POS_OP) and (MASK_OP shl POS_OP));
end;
function GETARG_A(i: Instruction): Integer; begin Result := Integer((i shr POS_A) and MASK_A); end;
procedure SETARG_A(var i: Instruction; u: Integer);
begin
  i := (i and Instruction($FFFFFFFF xor (MASK_A shl POS_A))) or ((Instruction(u) shl POS_A) and (MASK_A shl POS_A));
end;
function GETARG_B(i: Instruction): Integer; begin Result := Integer((i shr POS_B) and MASK_B); end;
procedure SETARG_B(var i: Instruction; b: Integer);
begin
  i := (i and Instruction($FFFFFFFF xor (MASK_B shl POS_B))) or ((Instruction(b) shl POS_B) and (MASK_B shl POS_B));
end;
function GETARG_C(i: Instruction): Integer; begin Result := Integer((i shr POS_C) and MASK_C); end;
procedure SETARG_C(var i: Instruction; b: Integer);
begin
  i := (i and Instruction($FFFFFFFF xor (MASK_C shl POS_C))) or ((Instruction(b) shl POS_C) and (MASK_C shl POS_C));
end;
function GETARG_Bx(i: Instruction): Integer; begin Result := Integer((i shr POS_Bx) and MASK_Bx); end;
procedure SETARG_Bx(var i: Instruction; b: Integer);
begin
  i := (i and Instruction($FFFFFFFF xor (MASK_Bx shl POS_Bx))) or ((Instruction(b) shl POS_Bx) and (MASK_Bx shl POS_Bx));
end;
function GETARG_sBx(i: Instruction): Integer; begin Result := GETARG_Bx(i) - MAXARG_sBx; end;
procedure SETARG_sBx(var i: Instruction; b: Integer); begin SETARG_Bx(i, b + MAXARG_sBx); end;
function CREATE_ABC(o, a, b, c: Integer): Instruction;
begin
  Result := (Instruction(o) shl POS_OP) or (Instruction(a) shl POS_A) or
            (Instruction(b) shl POS_B) or (Instruction(c) shl POS_C);
end;
function CREATE_ABx(o, a: Integer; bc: Cardinal): Instruction;
begin
  Result := (Instruction(o) shl POS_OP) or (Instruction(a) shl POS_A) or (Instruction(bc) shl POS_Bx);
end;
function ISK(x: Integer): Boolean; begin Result := (x and BITRK) <> 0; end;
function INDEXK(r: Integer): Integer; begin Result := r and not BITRK; end;
function RKASK(x: Integer): Integer; begin Result := x or BITRK; end;

procedure luaZ_initbuffer(buff: PMbuffer); begin buff^.buffer := nil; buff^.buffsize := 0; end;
procedure luaZ_resetbuffer(buff: PMbuffer); begin buff^.n := 0; end;

function savestack(L: Plua_State; p: StkId): ptrdiff_t;
begin
  Result := PAnsiChar(p) - PAnsiChar(L^.stack);
end;
function restorestack(L: Plua_State; n: ptrdiff_t): StkId;
begin
  Result := StkId(PAnsiChar(L^.stack) + n);
end;
function saveci(L: Plua_State; p: PCallInfo): ptrdiff_t;
begin
  Result := PAnsiChar(p) - PAnsiChar(L^.base_ci);
end;
function restoreci(L: Plua_State; n: ptrdiff_t): PCallInfo;
begin
  Result := PCallInfo(PAnsiChar(L^.base_ci) + n);
end;
function StkDiff(a, b: StkId): Integer;
begin
  Result := Integer((PAnsiChar(a) - PAnsiChar(b)) div SizeOf(TValue));
end;

end.
