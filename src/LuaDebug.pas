{
  Lua 5.1.4 - Pascal port of ldebug.c
  Debug Interface
}
unit LuaDebug;

{$I lua.inc}

interface

uses
  LuaTypes;

function pcRel(pc: PInstruction; p: PProto): Integer; inline;
function getline_(f: PProto; pc: Integer): Integer; inline;
procedure luaG_typeerror(L: Plua_State; o: PTValue; op: PAnsiChar);
procedure luaG_concaterror(L: Plua_State; p1, p2: StkId);
procedure luaG_aritherror(L: Plua_State; p1, p2: PTValue);
function luaG_ordererror(L: Plua_State; p1, p2: PTValue): Integer;
procedure luaG_runerror(L: Plua_State; fmt: PAnsiChar; const args: array of const);
procedure luaG_errormsg(L: Plua_State);
function luaG_checkcode(pt: PProto): Integer;
function luaG_checkopenop(i: Instruction): Integer;

function lua_sethook(L: Plua_State; func: lua_Hook; mask: Integer; count: Integer): Integer; cdecl;
function lua_gethook(L: Plua_State): lua_Hook; cdecl;
function lua_gethookmask(L: Plua_State): Integer; cdecl;
function lua_gethookcount(L: Plua_State): Integer; cdecl;
function lua_getstack(L: Plua_State; level: Integer; ar: Plua_Debug): Integer; cdecl;
function lua_getinfo(L: Plua_State; what: PAnsiChar; ar: Plua_Debug): Integer; cdecl;
function lua_getlocal(L: Plua_State; ar: Plua_Debug; n: Integer): PAnsiChar; cdecl;
function lua_setlocal(L: Plua_State; ar: Plua_Debug; n: Integer): PAnsiChar; cdecl;

implementation

uses
  LuaCRT, LuaObject, LuaOpcodes, LuaTM, LuaFunc, LuaTable, LuaDo, LuaVM, LuaAPI;

function pcRel(pc: PInstruction; p: PProto): Integer;
begin
  Result := Integer((PAnsiChar(pc) - PAnsiChar(p^.code)) div SizeOf(Instruction)) - 1;
end;

function getline_(f: PProto; pc: Integer): Integer;
begin
  if f^.lineinfo <> nil then Result := f^.lineinfo[pc] else Result := 0;
end;

function ciIndex(L: Plua_State; ci: PCallInfo): Integer; inline;
begin
  Result := Integer((PAnsiChar(ci) - PAnsiChar(L^.base_ci)) div SizeOf(TCallInfo));
end;

function getfuncname(L: Plua_State; ci: PCallInfo; var name: PAnsiChar): PAnsiChar; forward;

function currentpc(L: Plua_State; ci: PCallInfo): Integer;
begin
  if not isLua(ci) then Exit(-1);  { function is not a Lua function? }
  if ci = L^.ci then
    ci^.savedpc := L^.savedpc;
  Result := pcRel(ci^.savedpc, ci_func(ci)^.l.p);
end;

function currentline(L: Plua_State; ci: PCallInfo): Integer;
var pc: Integer;
begin
  pc := currentpc(L, ci);
  if pc < 0 then
    Result := -1  { only active lua functions have current-line information }
  else
    Result := getline_(ci_func(ci)^.l.p, pc);
end;

{ this function can be called asynchronous (e.g. during a signal) }
function lua_sethook(L: Plua_State; func: lua_Hook; mask: Integer; count: Integer): Integer; cdecl;
begin
  if (not Assigned(func)) or (mask = 0) then
  begin  { turn off hooks? }
    mask := 0;
    func := nil;
  end;
  L^.hook := func;
  L^.basehookcount := count;
  L^.hookcount := L^.basehookcount;
  L^.hookmask := lu_byte(mask);
  Result := 1;
end;

function lua_gethook(L: Plua_State): lua_Hook; cdecl;
begin
  Result := L^.hook;
end;

function lua_gethookmask(L: Plua_State): Integer; cdecl;
begin
  Result := L^.hookmask;
end;

function lua_gethookcount(L: Plua_State): Integer; cdecl;
begin
  Result := L^.basehookcount;
end;

function lua_getstack(L: Plua_State; level: Integer; ar: Plua_Debug): Integer; cdecl;
var status: Integer; ci: PCallInfo;
begin
  ci := L^.ci;
  while (level > 0) and (PAnsiChar(ci) > PAnsiChar(L^.base_ci)) do
  begin
    Dec(level);
    if f_isLua(ci) then  { Lua function? }
      Dec(level, ci^.tailcalls);  { skip lost tail calls }
    Dec(ci);
  end;
  if (level = 0) and (PAnsiChar(ci) > PAnsiChar(L^.base_ci)) then
  begin  { level found? }
    status := 1;
    ar^.i_ci := ciIndex(L, ci);
  end
  else if level < 0 then
  begin  { level is of a lost tail call? }
    status := 1;
    ar^.i_ci := 0;
  end
  else
    status := 0;  { no such level }
  Result := status;
end;

function getluaproto(ci: PCallInfo): PProto;
begin
  if isLua(ci) then Result := ci_func(ci)^.l.p else Result := nil;
end;

function findlocal(L: Plua_State; ci: PCallInfo; n: Integer): PAnsiChar;
var name: PAnsiChar; fp: PProto; limit: StkId;
begin
  fp := getluaproto(ci);
  name := nil;
  if fp <> nil then name := luaF_getlocalname(fp, n, currentpc(L, ci));
  if name <> nil then
    Result := name  { is a local variable in a Lua function }
  else
  begin
    if ci = L^.ci then limit := L^.top else limit := (ci + 1)^.func;
    if (StkDiff(limit, ci^.base) >= n) and (n > 0) then  { is 'n' inside 'ci' stack? }
      Result := '(*temporary)'
    else
      Result := nil;
  end;
end;

function lua_getlocal(L: Plua_State; ar: Plua_Debug; n: Integer): PAnsiChar; cdecl;
var ci: PCallInfo; name: PAnsiChar;
begin
  ci := L^.base_ci + ar^.i_ci;
  name := findlocal(L, ci, n);
  if name <> nil then
    luaA_pushobject(L, ci^.base + (n - 1));
  Result := name;
end;

function lua_setlocal(L: Plua_State; ar: Plua_Debug; n: Integer): PAnsiChar; cdecl;
var ci: PCallInfo; name: PAnsiChar;
begin
  ci := L^.base_ci + ar^.i_ci;
  name := findlocal(L, ci, n);
  if name <> nil then
    setobj(L, ci^.base + (n - 1), L^.top - 1);
  Dec(L^.top);  { pop value }
  Result := name;
end;

procedure funcinfo(ar: Plua_Debug; cl: PClosure);
begin
  if cl^.c.isC <> 0 then
  begin
    ar^.source := '=[C]';
    ar^.linedefined := -1;
    ar^.lastlinedefined := -1;
    ar^.what := 'C';
  end
  else
  begin
    ar^.source := getstr(cl^.l.p^.source);
    ar^.linedefined := cl^.l.p^.linedefined;
    ar^.lastlinedefined := cl^.l.p^.lastlinedefined;
    if ar^.linedefined = 0 then ar^.what := 'main' else ar^.what := 'Lua';
  end;
  luaO_chunkid(@ar^.short_src[0], ar^.source, LUA_IDSIZE);
end;

procedure info_tailcall(ar: Plua_Debug);
begin
  ar^.name := '';
  ar^.namewhat := '';
  ar^.what := 'tail';
  ar^.currentline := -1;
  ar^.linedefined := -1;
  ar^.lastlinedefined := -1;
  ar^.source := '=(tail call)';
  luaO_chunkid(@ar^.short_src[0], ar^.source, LUA_IDSIZE);
  ar^.nups := 0;
end;

procedure collectvalidlines(L: Plua_State; f: PClosure);
var t: PTable; lineinfo: PInteger; i: Integer;
begin
  if (f = nil) or (f^.c.isC <> 0) then
    setnilvalue(L^.top)
  else
  begin
    t := luaH_new(L, 0, 0);
    lineinfo := f^.l.p^.lineinfo;
    for i := 0 to f^.l.p^.sizelineinfo - 1 do
      setbvalue(luaH_setnum(L, t, lineinfo[i]), 1);
    sethvalue(L, L^.top, t);
  end;
  incr_top(L);
end;

function auxgetinfo(L: Plua_State; what: PAnsiChar; ar: Plua_Debug; f: PClosure; ci: PCallInfo): Integer;
var status: Integer;
begin
  status := 1;
  if f = nil then
  begin
    info_tailcall(ar);
    Exit(status);
  end;
  while what^ <> #0 do
  begin
    case what^ of
      'S': funcinfo(ar, f);
      'l':
        if ci <> nil then ar^.currentline := currentline(L, ci)
        else ar^.currentline := -1;
      'u': ar^.nups := f^.c.nupvalues;
      'n':
        begin
          if ci <> nil then ar^.namewhat := getfuncname(L, ci, ar^.name)
          else ar^.namewhat := nil;
          if ar^.namewhat = nil then
          begin
            ar^.namewhat := '';  { not found }
            ar^.name := nil;
          end;
        end;
      'L', 'f':  { handled by lua_getinfo }
        ;
    else
      status := 0;  { invalid option }
    end;
    Inc(what);
  end;
  Result := status;
end;

function lua_getinfo(L: Plua_State; what: PAnsiChar; ar: Plua_Debug): Integer; cdecl;
var status: Integer; f: PClosure; ci: PCallInfo; func: StkId;
begin
  f := nil;
  ci := nil;
  if what^ = '>' then
  begin
    func := L^.top - 1;
    Inc(what);  { skip the '>' }
    f := clvalue(func);
    Dec(L^.top);  { pop function }
  end
  else if ar^.i_ci <> 0 then
  begin  { no tail call? }
    ci := L^.base_ci + ar^.i_ci;
    f := clvalue(ci^.func);
  end;
  status := auxgetinfo(L, what, ar, f, ci);
  if c_strchr(what, Ord('f')) <> nil then
  begin
    if f = nil then setnilvalue(L^.top)
    else setclvalue(L, L^.top, f);
    incr_top(L);
  end;
  if c_strchr(what, Ord('L')) <> nil then
    collectvalidlines(L, f);
  Result := status;
end;

{ ======================================================
  Symbolic Execution and code checker
  ====================================================== }

function precheck(pt: PProto): Boolean;
begin
  Result := False;
  if not (pt^.maxstacksize <= MAXSTACK) then Exit;
  if not (pt^.numparams + (pt^.is_vararg and VARARG_HASARG) <= pt^.maxstacksize) then Exit;
  if not (((pt^.is_vararg and VARARG_NEEDSARG) = 0) or ((pt^.is_vararg and VARARG_HASARG) <> 0)) then Exit;
  if not (pt^.sizeupvalues <= pt^.nups) then Exit;
  if not ((pt^.sizelineinfo = pt^.sizecode) or (pt^.sizelineinfo = 0)) then Exit;
  if not ((pt^.sizecode > 0) and (GET_OPCODE(pt^.code[pt^.sizecode - 1]) = OP_RETURN)) then Exit;
  Result := True;
end;

function luaG_checkopenop(i: Instruction): Integer;
begin
  case GET_OPCODE(i) of
    OP_CALL, OP_TAILCALL, OP_RETURN, OP_SETLIST:
      begin
        if not (GETARG_B(i) = 0) then Exit(0);
        Result := 1;
      end;
  else
    Result := 0;  { invalid instruction after an open call }
  end;
end;

function checkopenop(pt: PProto; pc: Integer): Boolean; inline;
begin
  Result := luaG_checkopenop(pt^.code[pc + 1]) <> 0;
end;

function checkArgMode(pt: PProto; r: Integer; mode: Integer): Boolean;
begin
  Result := False;
  case mode of
    OpArgN: if not (r = 0) then Exit;
    OpArgU: ;
    OpArgR: if not (r < pt^.maxstacksize) then Exit;
    OpArgK:
      if ISK(r) then
      begin
        if not (INDEXK(r) < pt^.sizek) then Exit;
      end
      else if not (r < pt^.maxstacksize) then Exit;
  end;
  Result := True;
end;

function symbexec(pt: PProto; lastpc: Integer; reg: Integer): Instruction;
var pc, last, a, b, c, dest, j, nup: Integer; i, d: Instruction; op, op1: OpCode;
begin
  Result := 0;
  last := pt^.sizecode - 1;  { points to final return (a `neutral' instruction) }
  if not precheck(pt) then Exit;
  pc := 0;
  while pc < lastpc do
  begin
    i := pt^.code[pc];
    op := GET_OPCODE(i);
    a := GETARG_A(i);
    b := 0;
    c := 0;
    if not (op < NUM_OPCODES) then Exit;
    if not (a < pt^.maxstacksize) then Exit;
    case getOpMode(op) of
      iABC:
        begin
          b := GETARG_B(i);
          c := GETARG_C(i);
          if not checkArgMode(pt, b, getBMode(op)) then Exit;
          if not checkArgMode(pt, c, getCMode(op)) then Exit;
        end;
      iABx:
        begin
          b := GETARG_Bx(i);
          if getBMode(op) = OpArgK then
            if not (b < pt^.sizek) then Exit;
        end;
      iAsBx:
        begin
          b := GETARG_sBx(i);
          if getBMode(op) = OpArgR then
          begin
            dest := pc + 1 + b;
            if not ((0 <= dest) and (dest < pt^.sizecode)) then Exit;
            if dest > 0 then
            begin
              { check that it does not jump to a setlist count; this
                is tricky, because the count from a previous setlist may
                have the same value of an invalid setlist; so, we must
                go all the way back to the first of them (if any) }
              j := 0;
              while j < dest do
              begin
                d := pt^.code[dest - 1 - j];
                if not ((GET_OPCODE(d) = OP_SETLIST) and (GETARG_C(d) = 0)) then Break;
                Inc(j);
              end;
              { if 'j' is even, previous value is not a setlist (even if
                it looks like one) }
              if not ((j and 1) = 0) then Exit;
            end;
          end;
        end;
    end;
    if testAMode(op) then
    begin
      if a = reg then last := pc;  { change register `a' }
    end;
    if testTMode(op) then
    begin
      if not (pc + 2 < pt^.sizecode) then Exit;  { check skip }
      if not (GET_OPCODE(pt^.code[pc + 1]) = OP_JMP) then Exit;
    end;
    case op of
      OP_LOADBOOL:
        begin
          if c = 1 then
          begin  { does it jump? }
            if not (pc + 2 < pt^.sizecode) then Exit;  { check its jump }
            if not ((GET_OPCODE(pt^.code[pc + 1]) <> OP_SETLIST) or
                    (GETARG_C(pt^.code[pc + 1]) <> 0)) then Exit;
          end;
        end;
      OP_LOADNIL:
        begin
          if (a <= reg) and (reg <= b) then
            last := pc;  { set registers from `a' to `b' }
        end;
      OP_GETUPVAL, OP_SETUPVAL:
        begin
          if not (b < pt^.nups) then Exit;
        end;
      OP_GETGLOBAL, OP_SETGLOBAL:
        begin
          if not ttisstring(@pt^.k[b]) then Exit;
        end;
      OP_SELF:
        begin
          if not (a + 1 < pt^.maxstacksize) then Exit;
          if reg = a + 1 then last := pc;
        end;
      OP_CONCAT:
        begin
          if not (b < c) then Exit;  { at least two operands }
        end;
      OP_TFORLOOP:
        begin
          if not (c >= 1) then Exit;  { at least one result (control variable) }
          if not (a + 2 + c < pt^.maxstacksize) then Exit;  { space for results }
          if reg >= a + 2 then last := pc;  { affect all regs above its base }
        end;
      OP_FORLOOP, OP_FORPREP, OP_JMP:
        begin
          if op <> OP_JMP then
            if not (a + 3 < pt^.maxstacksize) then Exit;
          { go through }
          dest := pc + 1 + b;
          { not full check and jump is forward and do not skip `lastpc'? }
          if (reg <> NO_REG) and (pc < dest) and (dest <= lastpc) then
            Inc(pc, b);  { do the jump }
        end;
      OP_CALL, OP_TAILCALL:
        begin
          if b <> 0 then
          begin
            if not (a + b - 1 < pt^.maxstacksize) then Exit;
          end;
          Dec(c);  { c = num. returns }
          if c = LUA_MULTRET then
          begin
            if not checkopenop(pt, pc) then Exit;
          end
          else if c <> 0 then
            if not (a + c - 1 < pt^.maxstacksize) then Exit;
          if reg >= a then last := pc;  { affect all registers above base }
        end;
      OP_RETURN:
        begin
          Dec(b);  { b = num. returns }
          if b > 0 then
            if not (a + b - 1 < pt^.maxstacksize) then Exit;
        end;
      OP_SETLIST:
        begin
          if b > 0 then
            if not (a + b < pt^.maxstacksize) then Exit;
          if c = 0 then
          begin
            Inc(pc);
            if not (pc < pt^.sizecode - 1) then Exit;
          end;
        end;
      OP_CLOSURE:
        begin
          if not (b < pt^.sizep) then Exit;
          nup := pt^.p[b]^.nups;
          if not (pc + nup < pt^.sizecode) then Exit;
          for j := 1 to nup do
          begin
            op1 := GET_OPCODE(pt^.code[pc + j]);
            if not ((op1 = OP_GETUPVAL) or (op1 = OP_MOVE)) then Exit;
          end;
          if reg <> NO_REG then  { tracing? }
            Inc(pc, nup);  { do not 'execute' these pseudo-instructions }
        end;
      OP_VARARG:
        begin
          if not (((pt^.is_vararg and VARARG_ISVARARG) <> 0) and
                  ((pt^.is_vararg and VARARG_NEEDSARG) = 0)) then Exit;
          Dec(b);
          if b = LUA_MULTRET then
            if not checkopenop(pt, pc) then Exit;
          if not (a + b - 1 < pt^.maxstacksize) then Exit;
        end;
    end;
    Inc(pc);
  end;
  Result := pt^.code[last];
end;

function luaG_checkcode(pt: PProto): Integer;
begin
  Result := Ord(symbexec(pt, pt^.sizecode, NO_REG) <> 0);
end;

function kname(p: PProto; c: Integer): PAnsiChar;
begin
  if ISK(c) and ttisstring(@p^.k[INDEXK(c)]) then
    Result := svalue(@p^.k[INDEXK(c)])
  else
    Result := '?';
end;

function getobjname(L: Plua_State; ci: PCallInfo; stackpos: Integer; var name: PAnsiChar): PAnsiChar;
var p: PProto; pc, g, a, b, k, u: Integer; i: Instruction;
begin
  if isLua(ci) then
  begin  { a Lua function? }
    p := ci_func(ci)^.l.p;
    pc := currentpc(L, ci);
    name := luaF_getlocalname(p, stackpos + 1, pc);
    if name <> nil then  { is a local? }
      Exit('local');
    i := symbexec(p, pc, stackpos);  { try symbolic execution }
    case GET_OPCODE(i) of
      OP_GETGLOBAL:
        begin
          g := GETARG_Bx(i);  { global index }
          name := svalue(@p^.k[g]);
          Exit('global');
        end;
      OP_MOVE:
        begin
          a := GETARG_A(i);
          b := GETARG_B(i);  { move from `b' to `a' }
          if b < a then
            Exit(getobjname(L, ci, b, name));  { get name for `b' }
        end;
      OP_GETTABLE:
        begin
          k := GETARG_C(i);  { key index }
          name := kname(p, k);
          Exit('field');
        end;
      OP_GETUPVAL:
        begin
          u := GETARG_B(i);  { upvalue index }
          if p^.upvalues <> nil then name := getstr(p^.upvalues[u]) else name := '?';
          Exit('upvalue');
        end;
      OP_SELF:
        begin
          k := GETARG_C(i);  { key index }
          name := kname(p, k);
          Exit('method');
        end;
    end;
  end;
  Result := nil;  { no useful name found }
end;

function getfuncname(L: Plua_State; ci: PCallInfo; var name: PAnsiChar): PAnsiChar;
var i: Instruction;
begin
  if (isLua(ci) and (ci^.tailcalls > 0)) or not isLua(ci - 1) then
    Exit(nil);  { calling function is not Lua (or is unknown) }
  Dec(ci);  { calling function }
  i := ci_func(ci)^.l.p^.code[currentpc(L, ci)];
  if (GET_OPCODE(i) = OP_CALL) or (GET_OPCODE(i) = OP_TAILCALL) or
     (GET_OPCODE(i) = OP_TFORLOOP) then
    Result := getobjname(L, ci, GETARG_A(i), name)
  else
    Result := nil;  { no useful name can be found }
end;

{ only ANSI way to check whether a pointer points to an array }
function isinstack(ci: PCallInfo; o: PTValue): Boolean;
var p: StkId;
begin
  p := ci^.base;
  while PAnsiChar(p) < PAnsiChar(ci^.top) do
  begin
    if o = p then Exit(True);
    Inc(p);
  end;
  Result := False;
end;

procedure luaG_typeerror(L: Plua_State; o: PTValue; op: PAnsiChar);
var name, t, kind: PAnsiChar;
begin
  name := nil;
  t := luaT_typenames[o^.tt];
  if isinstack(L^.ci, o) then
    kind := getobjname(L, L^.ci, StkDiff(o, L^.base), name)
  else
    kind := nil;
  if kind <> nil then
    luaG_runerror(L, 'attempt to %s %s ''%s'' (a %s value)', [op, kind, name, t])
  else
    luaG_runerror(L, 'attempt to %s a %s value', [op, t]);
end;

procedure luaG_concaterror(L: Plua_State; p1, p2: StkId);
begin
  if ttisstring(p1) or ttisnumber(p1) then p1 := p2;
  luaG_typeerror(L, p1, 'concatenate');
end;

procedure luaG_aritherror(L: Plua_State; p1, p2: PTValue);
var temp: TValue;
begin
  if luaV_tonumber(p1, @temp) = nil then
    p2 := p1;  { first operand is wrong }
  luaG_typeerror(L, p2, 'perform arithmetic on');
end;

function luaG_ordererror(L: Plua_State; p1, p2: PTValue): Integer;
var t1, t2: PAnsiChar;
begin
  t1 := luaT_typenames[p1^.tt];
  t2 := luaT_typenames[p2^.tt];
  if t1[2] = t2[2] then
    luaG_runerror(L, 'attempt to compare two %s values', [t1])
  else
    luaG_runerror(L, 'attempt to compare %s with %s', [t1, t2]);
  Result := 0;
end;

procedure addinfo(L: Plua_State; msg: PAnsiChar);
var ci: PCallInfo; buff: array[0..LUA_IDSIZE - 1] of AnsiChar; line: Integer;
begin
  ci := L^.ci;
  if isLua(ci) then
  begin  { is Lua code? }
    line := currentline(L, ci);
    luaO_chunkid(@buff[0], getstr(getluaproto(ci)^.source), LUA_IDSIZE);
    luaO_pushfstring(L, '%s:%d: %s', [PAnsiChar(@buff[0]), line, msg]);
  end;
end;

procedure luaG_errormsg(L: Plua_State);
var errfunc: StkId;
begin
  if L^.errfunc <> 0 then
  begin  { is there an error handling function? }
    errfunc := restorestack(L, L^.errfunc);
    if not ttisfunction(errfunc) then luaD_throw(L, LUA_ERRERR);
    setobj(L, L^.top, L^.top - 1);  { move argument }
    setobj(L, L^.top - 1, errfunc);  { push function }
    incr_top(L);
    luaD_call(L, L^.top - 2, 1);  { call it }
  end;
  luaD_throw(L, LUA_ERRRUN);
end;

procedure luaG_runerror(L: Plua_State; fmt: PAnsiChar; const args: array of const);
begin
  addinfo(L, luaO_pushfstring(L, fmt, args));
  luaG_errormsg(L);
end;

end.
