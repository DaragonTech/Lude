{
  Lua 5.1.4 - Pascal port of ldo.c
  Stack and Call structure of Lua

  Error recovery: the C version uses setjmp/longjmp (or C++ exceptions when
  compiled as C++).  This port uses a Pascal exception (ELuaThrow), which is
  exactly what the C++ build of Lua does.
}
unit LuaDo;

{$I lua.inc}

interface

uses
  LuaTypes;

const
  PCRLUA   = 0;  { initiated a call to a Lua function }
  PCRC     = 1;  { did a call to a C function }
  PCRYIELD = 2;  { C funtion yielded }

type
  Pfunc = procedure(L: Plua_State; ud: Pointer);

  ELuaThrow = class(TObject)
  end;

procedure luaD_checkstack(L: Plua_State; n: Integer); inline;
procedure incr_top(L: Plua_State); inline;
function luaD_protectedparser(L: Plua_State; z: PZIO; name: PAnsiChar): Integer;
procedure luaD_callhook(L: Plua_State; event: Integer; line: Integer);
function luaD_precall(L: Plua_State; func: StkId; nresults: Integer): Integer;
procedure luaD_call(L: Plua_State; func: StkId; nResults: Integer);
function luaD_pcall(L: Plua_State; func: Pfunc; u: Pointer; old_top: ptrdiff_t; ef: ptrdiff_t): Integer;
function luaD_poscall(L: Plua_State; firstResult: StkId): Integer;
procedure luaD_reallocCI(L: Plua_State; newsize: Integer);
procedure luaD_reallocstack(L: Plua_State; newsize: Integer);
procedure luaD_growstack(L: Plua_State; n: Integer);
procedure luaD_throw(L: Plua_State; errcode: Integer);
function luaD_rawrunprotected(L: Plua_State; f: Pfunc; ud: Pointer): Integer;
procedure luaD_seterrorobj(L: Plua_State; errcode: Integer; oldtop: StkId);

function lua_resume(L: Plua_State; nargs: Integer): Integer; cdecl;
function lua_yield(L: Plua_State; nresults: Integer): Integer; cdecl;

implementation

uses
  LuaMem, LuaString, LuaFunc, LuaGC, LuaTM, LuaTable, LuaDebug, LuaVM,
  LuaParser, LuaUndump, LuaZIO, LuaStdio;

procedure luaD_checkstack(L: Plua_State; n: Integer);
begin
  if (PAnsiChar(L^.stack_last) - PAnsiChar(L^.top)) <= n * SizeOf(TValue) then
    luaD_growstack(L, n);
end;

procedure incr_top(L: Plua_State);
begin
  luaD_checkstack(L, 1);
  Inc(L^.top);
end;

{ ====================================================================== Error-recovery functions }

procedure luaD_seterrorobj(L: Plua_State; errcode: Integer; oldtop: StkId);
begin
  case errcode of
    LUA_ERRMEM:
      setsvalue(L, oldtop, luaS_newliteral(L, MEMERRMSG));
    LUA_ERRERR:
      setsvalue(L, oldtop, luaS_newliteral(L, 'error in error handling'));
    LUA_ERRSYNTAX, LUA_ERRRUN:
      setobj(L, oldtop, L^.top - 1);  { error message on current top }
  end;
  L^.top := oldtop + 1;
end;

procedure restore_stack_limit(L: Plua_State);
var inuse: Integer;
begin
  if L^.size_ci > LUAI_MAXCALLS then
  begin  { there was an overflow? }
    inuse := Integer((PAnsiChar(L^.ci) - PAnsiChar(L^.base_ci)) div SizeOf(TCallInfo));
    if inuse + 1 < LUAI_MAXCALLS then  { can `undo' overflow? }
      luaD_reallocCI(L, LUAI_MAXCALLS);
  end;
end;

procedure resetstack(L: Plua_State; status: Integer);
begin
  L^.ci := L^.base_ci;
  L^.base := L^.ci^.base;
  luaF_close(L, L^.base);  { close eventual pending closures }
  luaD_seterrorobj(L, status, L^.base);
  L^.nCcalls := L^.baseCcalls;
  L^.allowhook := 1;
  restore_stack_limit(L);
  L^.errfunc := 0;
  L^.errorJmp := nil;
end;

procedure luaD_throw(L: Plua_State; errcode: Integer);
begin
  if L^.errorJmp <> nil then
  begin
    L^.errorJmp^.status := errcode;
    raise ELuaThrow.Create;
  end
  else
  begin
    L^.status := lu_byte(errcode);
    if Assigned(L^.l_G^.panic) then
    begin
      resetstack(L, errcode);
      L^.l_G^.panic(L);
    end;
    c_exit(1);  { EXIT_FAILURE }
  end;
end;

function luaD_rawrunprotected(L: Plua_State; f: Pfunc; ud: Pointer): Integer;
var lj: lua_longjmp;
begin
  lj.status := 0;
  lj.previous := L^.errorJmp;  { chain new error handler }
  L^.errorJmp := @lj;
  try
    f(L, ud);
  except
    on ELuaThrow do
      if lj.status = 0 then lj.status := -1;
  end;
  L^.errorJmp := lj.previous;  { restore old error handler }
  Result := lj.status;
end;

{ ====================================================================== }

procedure correctstack(L: Plua_State; oldstack: PTValue);
var ci: PCallInfo; up: PGCObject; delta: ptrdiff_t;
begin
  delta := PAnsiChar(L^.stack) - PAnsiChar(oldstack);
  L^.top := StkId(PAnsiChar(L^.top) + delta);
  up := L^.openupval;
  while up <> nil do
  begin
    gco2uv(up)^.v := PTValue(PAnsiChar(gco2uv(up)^.v) + delta);
    up := up^.next;
  end;
  ci := L^.base_ci;
  while PAnsiChar(ci) <= PAnsiChar(L^.ci) do
  begin
    ci^.top := StkId(PAnsiChar(ci^.top) + delta);
    ci^.base := StkId(PAnsiChar(ci^.base) + delta);
    ci^.func := StkId(PAnsiChar(ci^.func) + delta);
    Inc(ci);
  end;
  L^.base := StkId(PAnsiChar(L^.base) + delta);
end;

procedure luaD_reallocstack(L: Plua_State; newsize: Integer);
var oldstack: PTValue; realsize: Integer;
begin
  oldstack := L^.stack;
  realsize := newsize + 1 + EXTRA_STACK;
  L^.stack := luaM_reallocv(L, L^.stack, L^.stacksize, realsize, SizeOf(TValue));
  L^.stacksize := realsize;
  L^.stack_last := L^.stack + newsize;
  correctstack(L, oldstack);
end;

procedure luaD_reallocCI(L: Plua_State; newsize: Integer);
var oldci: PCallInfo; delta: ptrdiff_t;
begin
  oldci := L^.base_ci;
  L^.base_ci := luaM_reallocv(L, L^.base_ci, L^.size_ci, newsize, SizeOf(TCallInfo));
  L^.size_ci := newsize;
  delta := PAnsiChar(L^.ci) - PAnsiChar(oldci);
  L^.ci := PCallInfo(PAnsiChar(L^.base_ci) + delta);
  L^.end_ci := L^.base_ci + L^.size_ci - 1;
end;

procedure luaD_growstack(L: Plua_State; n: Integer);
begin
  if n <= L^.stacksize then  { double size is enough? }
    luaD_reallocstack(L, 2 * L^.stacksize)
  else
    luaD_reallocstack(L, L^.stacksize + n);
end;

function growCI(L: Plua_State): PCallInfo;
begin
  if L^.size_ci > LUAI_MAXCALLS then  { overflow while handling overflow? }
    luaD_throw(L, LUA_ERRERR)
  else
  begin
    luaD_reallocCI(L, 2 * L^.size_ci);
    if L^.size_ci > LUAI_MAXCALLS then
      luaG_runerror(L, 'stack overflow', []);
  end;
  Inc(L^.ci);
  Result := L^.ci;
end;

procedure luaD_callhook(L: Plua_State; event: Integer; line: Integer);
var hook: lua_Hook; top, ci_top: ptrdiff_t; ar: lua_Debug;
begin
  hook := L^.hook;
  if Assigned(hook) and (L^.allowhook <> 0) then
  begin
    top := savestack(L, L^.top);
    ci_top := savestack(L, L^.ci^.top);
    ar.event := event;
    ar.currentline := line;
    if event = LUA_HOOKTAILRET then
      ar.i_ci := 0  { tail call; no debug information about it }
    else
      ar.i_ci := Integer((PAnsiChar(L^.ci) - PAnsiChar(L^.base_ci)) div SizeOf(TCallInfo));
    luaD_checkstack(L, LUA_MINSTACK);  { ensure minimum stack size }
    L^.ci^.top := L^.top + LUA_MINSTACK;
    L^.allowhook := 0;  { cannot call hooks inside a hook }
    hook(L, @ar);
    L^.allowhook := 1;
    L^.ci^.top := restorestack(L, ci_top);
    L^.top := restorestack(L, top);
  end;
end;

function adjust_varargs(L: Plua_State; p: PProto; actual: Integer): StkId;
var i, nfixargs, nvar: Integer; htab: PTable; base, fixed: StkId;
begin
  nfixargs := p^.numparams;
  htab := nil;
  while actual < nfixargs do
  begin
    setnilvalue(L^.top);
    Inc(L^.top);
    Inc(actual);
  end;
  { LUA_COMPAT_VARARG }
  if (p^.is_vararg and VARARG_NEEDSARG) <> 0 then
  begin  { compat. with old-style vararg? }
    nvar := actual - nfixargs;  { number of extra arguments }
    luaC_checkGC(L);
    htab := luaH_new(L, nvar, 1);  { create `arg' table }
    for i := 0 to nvar - 1 do  { put extra arguments into `arg' table }
      setobj(L, luaH_setnum(L, htab, i + 1), L^.top - nvar + i);
    { store counter in field `n' }
    setnvalue(luaH_setstr(L, htab, luaS_newliteral(L, 'n')), nvar);
  end;
  { move fixed parameters to final position }
  fixed := L^.top - actual;  { first fixed argument }
  base := L^.top;  { final position of first argument }
  for i := 0 to nfixargs - 1 do
  begin
    setobj(L, L^.top, fixed + i);
    Inc(L^.top);
    setnilvalue(fixed + i);
  end;
  { add `arg' parameter }
  if htab <> nil then
  begin
    sethvalue(L, L^.top, htab);
    Inc(L^.top);
  end;
  Result := base;
end;

function tryfuncTM(L: Plua_State; func: StkId): StkId;
var tm: PTValue; p: StkId; funcr: ptrdiff_t;
begin
  tm := luaT_gettmbyobj(L, func, TM_CALL);
  funcr := savestack(L, func);
  if not ttisfunction(tm) then
    luaG_typeerror(L, func, 'call');
  { Open a hole inside the stack at `func' }
  p := L^.top;
  while PAnsiChar(p) > PAnsiChar(func) do
  begin
    setobj(L, p, p - 1);
    Dec(p);
  end;
  incr_top(L);
  func := restorestack(L, funcr);  { previous call may change stack }
  setobj(L, func, tm);  { tag method is the new function to be called }
  Result := func;
end;

function inc_ci(L: Plua_State): PCallInfo; inline;
begin
  if L^.ci = L^.end_ci then
    Result := growCI(L)
  else
  begin
    Inc(L^.ci);
    Result := L^.ci;
  end;
end;

function luaD_precall(L: Plua_State; func: StkId; nresults: Integer): Integer;
var cl: PLClosure; funcr: ptrdiff_t; ci: PCallInfo; st, base: StkId; p: PProto;
    nargs, n: Integer;
begin
  if not ttisfunction(func) then  { `func' is not a function? }
    func := tryfuncTM(L, func);  { check the `function' tag method }
  funcr := savestack(L, func);
  cl := @clvalue(func)^.l;
  L^.ci^.savedpc := L^.savedpc;
  if cl^.isC = 0 then
  begin  { Lua function? prepare its call }
    p := cl^.p;
    luaD_checkstack(L, p^.maxstacksize);
    func := restorestack(L, funcr);
    if p^.is_vararg = 0 then
    begin  { no varargs? }
      base := func + 1;
      if PAnsiChar(L^.top) > PAnsiChar(base + p^.numparams) then
        L^.top := base + p^.numparams;
    end
    else
    begin  { vararg function }
      nargs := StkDiff(L^.top, func) - 1;
      base := adjust_varargs(L, p, nargs);
      func := restorestack(L, funcr);  { previous call may change the stack }
    end;
    ci := inc_ci(L);  { now `enter' new function }
    ci^.func := func;
    L^.base := base;
    ci^.base := base;
    ci^.top := L^.base + p^.maxstacksize;
    L^.savedpc := p^.code;  { starting point }
    ci^.tailcalls := 0;
    ci^.nresults := nresults;
    st := L^.top;
    while PAnsiChar(st) < PAnsiChar(ci^.top) do
    begin
      setnilvalue(st);
      Inc(st);
    end;
    L^.top := ci^.top;
    if (L^.hookmask and LUA_MASKCALL) <> 0 then
    begin
      Inc(L^.savedpc);  { hooks assume 'pc' is already incremented }
      luaD_callhook(L, LUA_HOOKCALL, -1);
      Dec(L^.savedpc);  { correct 'pc' }
    end;
    Result := PCRLUA;
  end
  else
  begin  { if is a C function, call it }
    luaD_checkstack(L, LUA_MINSTACK);  { ensure minimum stack size }
    ci := inc_ci(L);  { now `enter' new function }
    ci^.func := restorestack(L, funcr);
    L^.base := ci^.func + 1;
    ci^.base := L^.base;
    ci^.top := L^.top + LUA_MINSTACK;
    ci^.nresults := nresults;
    if (L^.hookmask and LUA_MASKCALL) <> 0 then
      luaD_callhook(L, LUA_HOOKCALL, -1);
    n := curr_func(L)^.c.f(L);  { do the actual call }
    if n < 0 then  { yielding? }
      Result := PCRYIELD
    else
    begin
      luaD_poscall(L, L^.top - n);
      Result := PCRC;
    end;
  end;
end;

function callrethooks(L: Plua_State; firstResult: StkId): StkId;
var fr: ptrdiff_t;
begin
  fr := savestack(L, firstResult);  { next call may change stack }
  luaD_callhook(L, LUA_HOOKRET, -1);
  if f_isLua(L^.ci) then
  begin  { Lua function? }
    while ((L^.hookmask and LUA_MASKRET) <> 0) and (L^.ci^.tailcalls > 0) do
    begin  { call hook for eventual tail calls }
      Dec(L^.ci^.tailcalls);
      luaD_callhook(L, LUA_HOOKTAILRET, -1);
    end;
    { C: `L->ci->tailcalls--' leaves the counter at -1 when it was 0 }
    if (L^.hookmask and LUA_MASKRET) <> 0 then Dec(L^.ci^.tailcalls);
  end;
  Result := restorestack(L, fr);
end;

function luaD_poscall(L: Plua_State; firstResult: StkId): Integer;
var res: StkId; wanted, i: Integer; ci: PCallInfo;
begin
  if (L^.hookmask and LUA_MASKRET) <> 0 then
    firstResult := callrethooks(L, firstResult);
  ci := L^.ci;
  Dec(L^.ci);
  res := ci^.func;  { res == final position of 1st result }
  wanted := ci^.nresults;
  L^.base := (ci - 1)^.base;  { restore base }
  L^.savedpc := (ci - 1)^.savedpc;  { restore savedpc }
  { move results to correct place }
  i := wanted;
  while (i <> 0) and (PAnsiChar(firstResult) < PAnsiChar(L^.top)) do
  begin
    setobj(L, res, firstResult);
    Inc(res);
    Inc(firstResult);
    Dec(i);
  end;
  while i > 0 do
  begin
    Dec(i);
    setnilvalue(res);
    Inc(res);
  end;
  L^.top := res;
  Result := wanted - LUA_MULTRET;  { 0 iff wanted == LUA_MULTRET }
end;

{ Call a function (C or Lua). The function to be called is at *func.
  The arguments are on the stack, right after the function.
  When returns, all the results are on the stack, starting at the original
  function position. }
procedure luaD_call(L: Plua_State; func: StkId; nResults: Integer);
begin
  Inc(L^.nCcalls);
  if L^.nCcalls >= LUAI_MAXCCALLS then
  begin
    if L^.nCcalls = LUAI_MAXCCALLS then
      luaG_runerror(L, 'C stack overflow', [])
    else if L^.nCcalls >= (LUAI_MAXCCALLS + (LUAI_MAXCCALLS shr 3)) then
      luaD_throw(L, LUA_ERRERR);  { error while handing stack error }
  end;
  if luaD_precall(L, func, nResults) = PCRLUA then  { is a Lua function? }
    luaV_execute(L, 1);  { call it }
  Dec(L^.nCcalls);
  luaC_checkGC(L);
end;

procedure resume(L: Plua_State; ud: Pointer);
var firstArg: StkId; ci: PCallInfo;
begin
  firstArg := StkId(ud);
  ci := L^.ci;
  if L^.status = 0 then
  begin  { start coroutine? }
    if luaD_precall(L, firstArg - 1, LUA_MULTRET) <> PCRLUA then
      Exit;
  end
  else
  begin  { resuming from previous yield }
    L^.status := 0;
    if not f_isLua(ci) then
    begin  { `common' yield? }
      { finish interrupted execution of `OP_CALL' }
      if luaD_poscall(L, firstArg) <> 0 then  { complete it... }
        L^.top := L^.ci^.top;  { and correct top if not multiple results }
    end
    else  { yielded inside a hook: just continue its execution }
      L^.base := L^.ci^.base;
  end;
  luaV_execute(L, Integer((PAnsiChar(L^.ci) - PAnsiChar(L^.base_ci)) div SizeOf(TCallInfo)));
end;

function resume_error(L: Plua_State; msg: PAnsiChar): Integer;
begin
  L^.top := L^.ci^.base;
  setsvalue(L, L^.top, luaS_new(L, msg));
  incr_top(L);
  Result := LUA_ERRRUN;
end;

function lua_resume(L: Plua_State; nargs: Integer): Integer; cdecl;
var status: Integer;
begin
  if (L^.status <> LUA_YIELD_) and ((L^.status <> 0) or (L^.ci <> L^.base_ci)) then
    Exit(resume_error(L, 'cannot resume non-suspended coroutine'));
  if L^.nCcalls >= LUAI_MAXCCALLS then
    Exit(resume_error(L, 'C stack overflow'));
  Inc(L^.nCcalls);
  L^.baseCcalls := L^.nCcalls;
  status := luaD_rawrunprotected(L, resume, L^.top - nargs);
  if status <> 0 then
  begin  { error? }
    L^.status := lu_byte(status);  { mark thread as `dead' }
    luaD_seterrorobj(L, status, L^.top);
    L^.ci^.top := L^.top;
  end
  else
    status := L^.status;
  Dec(L^.nCcalls);
  Result := status;
end;

function lua_yield(L: Plua_State; nresults: Integer): Integer; cdecl;
begin
  if L^.nCcalls > L^.baseCcalls then
    luaG_runerror(L, 'attempt to yield across metamethod/C-call boundary', []);
  L^.base := L^.top - nresults;  { protect stack slots below }
  L^.status := LUA_YIELD_;
  Result := -1;
end;

function luaD_pcall(L: Plua_State; func: Pfunc; u: Pointer; old_top: ptrdiff_t; ef: ptrdiff_t): Integer;
var status: Integer; oldnCcalls: Word; old_ci: ptrdiff_t; old_allowhooks: lu_byte;
    old_errfunc: ptrdiff_t; oldtop: StkId;
begin
  oldnCcalls := L^.nCcalls;
  old_ci := saveci(L, L^.ci);
  old_allowhooks := L^.allowhook;
  old_errfunc := L^.errfunc;
  L^.errfunc := ef;
  status := luaD_rawrunprotected(L, func, u);
  if status <> 0 then
  begin  { an error occurred? }
    oldtop := restorestack(L, old_top);
    luaF_close(L, oldtop);  { close eventual pending closures }
    luaD_seterrorobj(L, status, oldtop);
    L^.nCcalls := oldnCcalls;
    L^.ci := restoreci(L, old_ci);
    L^.base := L^.ci^.base;
    L^.savedpc := L^.ci^.savedpc;
    L^.allowhook := old_allowhooks;
    restore_stack_limit(L);
  end;
  L^.errfunc := old_errfunc;
  Result := status;
end;

{ Execute a protected parser. }
type
  PSParser = ^TSParser;
  TSParser = record  { data to `f_parser' }
    z: PZIO;
    buff: TMbuffer;  { buffer to be used by the scanner }
    name: PAnsiChar;
  end;

procedure f_parser(L: Plua_State; ud: Pointer);
var i, c: Integer; tf: PProto; cl: PClosure; p: PSParser;
begin
  p := PSParser(ud);
  c := luaZ_lookahead(p^.z);
  luaC_checkGC(L);
  if c = Ord(LUA_SIGNATURE_CHAR) then
    tf := luaU_undump(L, p^.z, @p^.buff, p^.name)
  else
    tf := luaY_parser(L, p^.z, @p^.buff, p^.name);
  cl := luaF_newLclosure(L, tf^.nups, hvalue(gt(L)));
  cl^.l.p := tf;
  for i := 0 to tf^.nups - 1 do  { initialize eventual upvalues }
    PPUpVal(@cl^.l.upvals)[i] := luaF_newupval(L);
  setclvalue(L, L^.top, cl);
  incr_top(L);
end;

function luaD_protectedparser(L: Plua_State; z: PZIO; name: PAnsiChar): Integer;
var p: TSParser; status: Integer;
begin
  p.z := z;
  p.name := name;
  luaZ_initbuffer(@p.buff);
  status := luaD_pcall(L, f_parser, @p, savestack(L, L^.top), L^.errfunc);
  luaZ_freebuffer(L, @p.buff);
  Result := status;
end;

end.
