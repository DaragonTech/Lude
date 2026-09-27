{
  Lua 5.1.4 - Pascal port of lcode.c
  Code generator for Lua
}
unit LuaCode;

{$I lua.inc}

interface

uses
  LuaTypes;

function luaK_codeABx(fs: PFuncState; o: OpCode; A: Integer; Bx: Cardinal): Integer;
function luaK_codeABC(fs: PFuncState; o: OpCode; A, B, C: Integer): Integer;
function luaK_codeAsBx(fs: PFuncState; o: OpCode; A, sBx: Integer): Integer; inline;
procedure luaK_fixline(fs: PFuncState; line: Integer);
procedure luaK_nil(fs: PFuncState; from, n: Integer);
procedure luaK_reserveregs(fs: PFuncState; n: Integer);
procedure luaK_checkstack(fs: PFuncState; n: Integer);
function luaK_stringK(fs: PFuncState; s: PTString): Integer;
function luaK_numberK(fs: PFuncState; r: lua_Number): Integer;
procedure luaK_dischargevars(fs: PFuncState; e: Pexpdesc);
function luaK_exp2anyreg(fs: PFuncState; e: Pexpdesc): Integer;
procedure luaK_exp2nextreg(fs: PFuncState; e: Pexpdesc);
procedure luaK_exp2val(fs: PFuncState; e: Pexpdesc);
function luaK_exp2RK(fs: PFuncState; e: Pexpdesc): Integer;
procedure luaK_self(fs: PFuncState; e, key: Pexpdesc);
procedure luaK_indexed(fs: PFuncState; t, k: Pexpdesc);
procedure luaK_goiftrue(fs: PFuncState; e: Pexpdesc);
procedure luaK_storevar(fs: PFuncState; var_, ex: Pexpdesc);
procedure luaK_setreturns(fs: PFuncState; e: Pexpdesc; nresults: Integer);
procedure luaK_setmultret(fs: PFuncState; e: Pexpdesc); inline;
procedure luaK_setoneret(fs: PFuncState; e: Pexpdesc);
function luaK_jump(fs: PFuncState): Integer;
procedure luaK_ret(fs: PFuncState; first, nret: Integer);
procedure luaK_patchlist(fs: PFuncState; list, target: Integer);
procedure luaK_patchtohere(fs: PFuncState; list: Integer);
procedure luaK_concat(fs: PFuncState; var l1: Integer; l2: Integer);
function luaK_getlabel(fs: PFuncState): Integer;
procedure luaK_prefix(fs: PFuncState; op: UnOpr; e: Pexpdesc);
procedure luaK_infix(fs: PFuncState; op: BinOpr; v: Pexpdesc);
procedure luaK_posfix(fs: PFuncState; op: BinOpr; e1, e2: Pexpdesc);
procedure luaK_setlist(fs: PFuncState; base, nelems, tostore: Integer);

implementation

uses
  LuaCRT, LuaObject, LuaOpcodes, LuaMem, LuaTable, LuaGC, LuaLex, LuaParser;

function hasjumps(e: Pexpdesc): Boolean; inline;
begin
  Result := e^.t <> e^.f;
end;

function getcode(fs: PFuncState; e: Pexpdesc): PInstruction; inline;
begin
  Result := @fs^.f^.code[e^.info];
end;

function isnumeral(e: Pexpdesc): Boolean;
begin
  Result := (e^.k = VKNUM) and (e^.t = NO_JUMP) and (e^.f = NO_JUMP);
end;

function luaK_codeAsBx(fs: PFuncState; o: OpCode; A, sBx: Integer): Integer;
begin
  Result := luaK_codeABx(fs, o, A, Cardinal(sBx + MAXARG_sBx));
end;

procedure luaK_setmultret(fs: PFuncState; e: Pexpdesc);
begin
  luaK_setreturns(fs, e, LUA_MULTRET);
end;

procedure luaK_nil(fs: PFuncState; from, n: Integer);
var previous: PInstruction; pfrom, pto: Integer;
begin
  if fs^.pc > fs^.lasttarget then
  begin  { no jumps to current position? }
    if fs^.pc = 0 then
    begin  { function start? }
      if from >= fs^.nactvar then
        Exit;  { positions are already clean }
    end
    else
    begin
      previous := @fs^.f^.code[fs^.pc - 1];
      if GET_OPCODE(previous^) = OP_LOADNIL then
      begin
        pfrom := GETARG_A(previous^);
        pto := GETARG_B(previous^);
        if (pfrom <= from) and (from <= pto + 1) then
        begin  { can connect both? }
          if from + n - 1 > pto then
            SETARG_B(previous^, from + n - 1);
          Exit;
        end;
      end;
    end;
  end;
  luaK_codeABC(fs, OP_LOADNIL, from, from + n - 1, 0);  { else no optimization }
end;

function luaK_jump(fs: PFuncState): Integer;
var jpc, j: Integer;
begin
  jpc := fs^.jpc;  { save list of jumps to here }
  fs^.jpc := NO_JUMP;
  j := luaK_codeAsBx(fs, OP_JMP, 0, NO_JUMP);
  luaK_concat(fs, j, jpc);  { keep them on hold }
  Result := j;
end;

procedure luaK_ret(fs: PFuncState; first, nret: Integer);
begin
  luaK_codeABC(fs, OP_RETURN, first, nret + 1, 0);
end;

function condjump(fs: PFuncState; op: OpCode; A, B, C: Integer): Integer;
begin
  luaK_codeABC(fs, op, A, B, C);
  Result := luaK_jump(fs);
end;

procedure fixjump(fs: PFuncState; pc, dest: Integer);
var jmp: PInstruction; offset: Integer;
begin
  jmp := @fs^.f^.code[pc];
  offset := dest - (pc + 1);
  if Abs(offset) > MAXARG_sBx then
    luaX_syntaxerror(fs^.ls, 'control structure too long');
  SETARG_sBx(jmp^, offset);
end;

{ returns current `pc' and marks it as a jump target (to avoid wrong
  optimizations with consecutive instructions not in the same basic block). }
function luaK_getlabel(fs: PFuncState): Integer;
begin
  fs^.lasttarget := fs^.pc;
  Result := fs^.pc;
end;

function getjump(fs: PFuncState; pc: Integer): Integer;
var offset: Integer;
begin
  offset := GETARG_sBx(fs^.f^.code[pc]);
  if offset = NO_JUMP then  { point to itself represents end of list }
    Result := NO_JUMP  { end of list }
  else
    Result := (pc + 1) + offset;  { turn offset into absolute position }
end;

function getjumpcontrol(fs: PFuncState; pc: Integer): PInstruction;
var pi: PInstruction;
begin
  pi := @fs^.f^.code[pc];
  if (pc >= 1) and testTMode(GET_OPCODE((pi - 1)^)) then
    Result := pi - 1
  else
    Result := pi;
end;

{ check whether list has any jump that do not produce a value
  (or produce an inverted value) }
function need_value(fs: PFuncState; list: Integer): Boolean;
var i: Instruction;
begin
  while list <> NO_JUMP do
  begin
    i := getjumpcontrol(fs, list)^;
    if GET_OPCODE(i) <> OP_TESTSET then Exit(True);
    list := getjump(fs, list);
  end;
  Result := False;  { not found }
end;

function patchtestreg(fs: PFuncState; node, reg: Integer): Boolean;
var i: PInstruction;
begin
  i := getjumpcontrol(fs, node);
  if GET_OPCODE(i^) <> OP_TESTSET then
    Exit(False);  { cannot patch other instructions }
  if (reg <> NO_REG) and (reg <> GETARG_B(i^)) then
    SETARG_A(i^, reg)
  else  { no register to put value or register already has the value }
    i^ := CREATE_ABC(OP_TEST, GETARG_B(i^), 0, GETARG_C(i^));
  Result := True;
end;

procedure removevalues(fs: PFuncState; list: Integer);
begin
  while list <> NO_JUMP do
  begin
    patchtestreg(fs, list, NO_REG);
    list := getjump(fs, list);
  end;
end;

procedure patchlistaux(fs: PFuncState; list, vtarget, reg, dtarget: Integer);
var next: Integer;
begin
  while list <> NO_JUMP do
  begin
    next := getjump(fs, list);
    if patchtestreg(fs, list, reg) then
      fixjump(fs, list, vtarget)
    else
      fixjump(fs, list, dtarget);  { jump to default target }
    list := next;
  end;
end;

procedure dischargejpc(fs: PFuncState);
begin
  patchlistaux(fs, fs^.jpc, fs^.pc, NO_REG, fs^.pc);
  fs^.jpc := NO_JUMP;
end;

procedure luaK_patchlist(fs: PFuncState; list, target: Integer);
begin
  if target = fs^.pc then
    luaK_patchtohere(fs, list)
  else
    patchlistaux(fs, list, target, NO_REG, target);
end;

procedure luaK_patchtohere(fs: PFuncState; list: Integer);
begin
  luaK_getlabel(fs);
  luaK_concat(fs, fs^.jpc, list);
end;

procedure luaK_concat(fs: PFuncState; var l1: Integer; l2: Integer);
var list, next: Integer;
begin
  if l2 = NO_JUMP then Exit
  else if l1 = NO_JUMP then
    l1 := l2
  else
  begin
    list := l1;
    while True do
    begin
      next := getjump(fs, list);
      if next = NO_JUMP then Break;
      list := next;  { find last element }
    end;
    fixjump(fs, list, l2);
  end;
end;

procedure luaK_checkstack(fs: PFuncState; n: Integer);
var newstack: Integer;
begin
  newstack := fs^.freereg + n;
  if newstack > fs^.f^.maxstacksize then
  begin
    if newstack >= MAXSTACK then
      luaX_syntaxerror(fs^.ls, 'function or expression too complex');
    fs^.f^.maxstacksize := lu_byte(newstack);
  end;
end;

procedure luaK_reserveregs(fs: PFuncState; n: Integer);
begin
  luaK_checkstack(fs, n);
  Inc(fs^.freereg, n);
end;

procedure freereg(fs: PFuncState; reg: Integer);
begin
  if (not ISK(reg)) and (reg >= fs^.nactvar) then
    Dec(fs^.freereg);
end;

procedure freeexp(fs: PFuncState; e: Pexpdesc);
begin
  if e^.k = VNONRELOC then
    freereg(fs, e^.info);
end;

function addk(fs: PFuncState; k, v: PTValue): Integer;
var L: Plua_State; idx: PTValue; f: PProto; oldsize: Integer;
begin
  L := fs^.L;
  idx := luaH_set(L, fs^.h, k);
  f := fs^.f;
  oldsize := f^.sizek;
  if ttisnumber(idx) then
    Result := Trunc(idx^.value.n)
  else
  begin  { constant not found; create a new entry }
    setnvalue(idx, fs^.nk);
    if fs^.nk + 1 > f^.sizek then
      f^.k := luaM_growaux_(L, f^.k, f^.sizek, SizeOf(TValue), MAXARG_Bx, 'constant table overflow');
    while oldsize < f^.sizek do
    begin
      setnilvalue(@f^.k[oldsize]);
      Inc(oldsize);
    end;
    setobj(L, @f^.k[fs^.nk], v);
    luaC_barrier(L, f, v);
    Result := fs^.nk;
    Inc(fs^.nk);
  end;
end;

function luaK_stringK(fs: PFuncState; s: PTString): Integer;
var o: TValue;
begin
  setsvalue(fs^.L, @o, s);
  Result := addk(fs, @o, @o);
end;

function luaK_numberK(fs: PFuncState; r: lua_Number): Integer;
var o: TValue;
begin
  setnvalue(@o, r);
  Result := addk(fs, @o, @o);
end;

function boolK(fs: PFuncState; b: Integer): Integer;
var o: TValue;
begin
  setbvalue(@o, b);
  Result := addk(fs, @o, @o);
end;

function nilK(fs: PFuncState): Integer;
var k, v: TValue;
begin
  setnilvalue(@v);
  { cannot use nil as key; instead use table itself to represent nil }
  sethvalue(fs^.L, @k, fs^.h);
  Result := addk(fs, @k, @v);
end;

procedure luaK_setreturns(fs: PFuncState; e: Pexpdesc; nresults: Integer);
begin
  if e^.k = VCALL then
  begin  { expression is an open function call? }
    SETARG_C(getcode(fs, e)^, nresults + 1);
  end
  else if e^.k = VVARARG then
  begin
    SETARG_B(getcode(fs, e)^, nresults + 1);
    SETARG_A(getcode(fs, e)^, fs^.freereg);
    luaK_reserveregs(fs, 1);
  end;
end;

procedure luaK_setoneret(fs: PFuncState; e: Pexpdesc);
begin
  if e^.k = VCALL then
  begin  { expression is an open function call? }
    e^.k := VNONRELOC;
    e^.info := GETARG_A(getcode(fs, e)^);
  end
  else if e^.k = VVARARG then
  begin
    SETARG_B(getcode(fs, e)^, 2);
    e^.k := VRELOCABLE;  { can relocate its simple result }
  end;
end;

procedure luaK_dischargevars(fs: PFuncState; e: Pexpdesc);
begin
  case e^.k of
    VLOCAL:
      e^.k := VNONRELOC;
    VUPVAL:
      begin
        e^.info := luaK_codeABC(fs, OP_GETUPVAL, 0, e^.info, 0);
        e^.k := VRELOCABLE;
      end;
    VGLOBAL:
      begin
        e^.info := luaK_codeABx(fs, OP_GETGLOBAL, 0, e^.info);
        e^.k := VRELOCABLE;
      end;
    VINDEXED:
      begin
        freereg(fs, e^.aux);
        freereg(fs, e^.info);
        e^.info := luaK_codeABC(fs, OP_GETTABLE, 0, e^.info, e^.aux);
        e^.k := VRELOCABLE;
      end;
    VVARARG, VCALL:
      luaK_setoneret(fs, e);
  end;
end;

function code_label(fs: PFuncState; A, b, jump: Integer): Integer;
begin
  luaK_getlabel(fs);  { those instructions may be jump targets }
  Result := luaK_codeABC(fs, OP_LOADBOOL, A, b, jump);
end;

procedure discharge2reg(fs: PFuncState; e: Pexpdesc; reg: Integer);
var pc: PInstruction;
begin
  luaK_dischargevars(fs, e);
  case e^.k of
    VNIL:
      luaK_nil(fs, reg, 1);
    VFALSE, VTRUE:
      luaK_codeABC(fs, OP_LOADBOOL, reg, Ord(e^.k = VTRUE), 0);
    VK:
      luaK_codeABx(fs, OP_LOADK, reg, e^.info);
    VKNUM:
      luaK_codeABx(fs, OP_LOADK, reg, luaK_numberK(fs, e^.nval));
    VRELOCABLE:
      begin
        pc := getcode(fs, e);
        SETARG_A(pc^, reg);
      end;
    VNONRELOC:
      begin
        if reg <> e^.info then
          luaK_codeABC(fs, OP_MOVE, reg, e^.info, 0);
      end;
  else
    Exit;  { nothing to do... }
  end;
  e^.info := reg;
  e^.k := VNONRELOC;
end;

procedure discharge2anyreg(fs: PFuncState; e: Pexpdesc);
begin
  if e^.k <> VNONRELOC then
  begin
    luaK_reserveregs(fs, 1);
    discharge2reg(fs, e, fs^.freereg - 1);
  end;
end;

procedure exp2reg(fs: PFuncState; e: Pexpdesc; reg: Integer);
var final, p_f, p_t, fj: Integer;
begin
  discharge2reg(fs, e, reg);
  if e^.k = VJMP then
    luaK_concat(fs, e^.t, e^.info);  { put this jump in `t' list }
  if hasjumps(e) then
  begin
    p_f := NO_JUMP;  { position of an eventual LOAD false }
    p_t := NO_JUMP;  { position of an eventual LOAD true }
    if need_value(fs, e^.t) or need_value(fs, e^.f) then
    begin
      if e^.k = VJMP then fj := NO_JUMP else fj := luaK_jump(fs);
      p_f := code_label(fs, reg, 0, 1);
      p_t := code_label(fs, reg, 1, 0);
      luaK_patchtohere(fs, fj);
    end;
    final := luaK_getlabel(fs);
    patchlistaux(fs, e^.f, final, reg, p_f);
    patchlistaux(fs, e^.t, final, reg, p_t);
  end;
  e^.f := NO_JUMP;
  e^.t := NO_JUMP;
  e^.info := reg;
  e^.k := VNONRELOC;
end;

procedure luaK_exp2nextreg(fs: PFuncState; e: Pexpdesc);
begin
  luaK_dischargevars(fs, e);
  freeexp(fs, e);
  luaK_reserveregs(fs, 1);
  exp2reg(fs, e, fs^.freereg - 1);
end;

function luaK_exp2anyreg(fs: PFuncState; e: Pexpdesc): Integer;
begin
  luaK_dischargevars(fs, e);
  if e^.k = VNONRELOC then
  begin
    if not hasjumps(e) then Exit(e^.info);  { exp is already in a register }
    if e^.info >= fs^.nactvar then
    begin  { reg. is not a local? }
      exp2reg(fs, e, e^.info);  { put value on it }
      Exit(e^.info);
    end;
  end;
  luaK_exp2nextreg(fs, e);  { default }
  Result := e^.info;
end;

procedure luaK_exp2val(fs: PFuncState; e: Pexpdesc);
begin
  if hasjumps(e) then
    luaK_exp2anyreg(fs, e)
  else
    luaK_dischargevars(fs, e);
end;

function luaK_exp2RK(fs: PFuncState; e: Pexpdesc): Integer;
begin
  luaK_exp2val(fs, e);
  case e^.k of
    VKNUM, VTRUE, VFALSE, VNIL:
      begin
        if fs^.nk <= MAXINDEXRK then
        begin  { constant fit in RK operand? }
          if e^.k = VNIL then e^.info := nilK(fs)
          else if e^.k = VKNUM then e^.info := luaK_numberK(fs, e^.nval)
          else e^.info := boolK(fs, Ord(e^.k = VTRUE));
          e^.k := VK;
          Exit(RKASK(e^.info));
        end;
      end;
    VK:
      begin
        if e^.info <= MAXINDEXRK then  { constant fit in argC? }
          Exit(RKASK(e^.info));
      end;
  end;
  { not a constant in the right range: put it in a register }
  Result := luaK_exp2anyreg(fs, e);
end;

procedure luaK_storevar(fs: PFuncState; var_, ex: Pexpdesc);
var e: Integer;
begin
  case var_^.k of
    VLOCAL:
      begin
        freeexp(fs, ex);
        exp2reg(fs, ex, var_^.info);
        Exit;
      end;
    VUPVAL:
      begin
        e := luaK_exp2anyreg(fs, ex);
        luaK_codeABC(fs, OP_SETUPVAL, e, var_^.info, 0);
      end;
    VGLOBAL:
      begin
        e := luaK_exp2anyreg(fs, ex);
        luaK_codeABx(fs, OP_SETGLOBAL, e, var_^.info);
      end;
    VINDEXED:
      begin
        e := luaK_exp2RK(fs, ex);
        luaK_codeABC(fs, OP_SETTABLE, var_^.info, var_^.aux, e);
      end;
  end;
  freeexp(fs, ex);
end;

procedure luaK_self(fs: PFuncState; e, key: Pexpdesc);
var func: Integer;
begin
  luaK_exp2anyreg(fs, e);
  freeexp(fs, e);
  func := fs^.freereg;
  luaK_reserveregs(fs, 2);
  luaK_codeABC(fs, OP_SELF, func, e^.info, luaK_exp2RK(fs, key));
  freeexp(fs, key);
  e^.info := func;
  e^.k := VNONRELOC;
end;

procedure invertjump(fs: PFuncState; e: Pexpdesc);
var pc: PInstruction;
begin
  pc := getjumpcontrol(fs, e^.info);
  SETARG_A(pc^, Ord(GETARG_A(pc^) = 0));
end;

function jumponcond(fs: PFuncState; e: Pexpdesc; cond: Integer): Integer;
var ie: Instruction;
begin
  if e^.k = VRELOCABLE then
  begin
    ie := getcode(fs, e)^;
    if GET_OPCODE(ie) = OP_NOT then
    begin
      Dec(fs^.pc);  { remove previous OP_NOT }
      Exit(condjump(fs, OP_TEST, GETARG_B(ie), 0, Ord(cond = 0)));
    end;
    { else go through }
  end;
  discharge2anyreg(fs, e);
  freeexp(fs, e);
  Result := condjump(fs, OP_TESTSET, NO_REG, e^.info, cond);
end;

procedure luaK_goiftrue(fs: PFuncState; e: Pexpdesc);
var pc: Integer;
begin
  luaK_dischargevars(fs, e);
  case e^.k of
    VK, VKNUM, VTRUE:
      pc := NO_JUMP;  { always true; do nothing }
    VFALSE:
      pc := luaK_jump(fs);  { always jump }
    VJMP:
      begin
        invertjump(fs, e);
        pc := e^.info;
      end;
  else
    pc := jumponcond(fs, e, 0);
  end;
  luaK_concat(fs, e^.f, pc);  { insert last jump in `f' list }
  luaK_patchtohere(fs, e^.t);
  e^.t := NO_JUMP;
end;

procedure luaK_goiffalse(fs: PFuncState; e: Pexpdesc);
var pc: Integer;
begin
  luaK_dischargevars(fs, e);
  case e^.k of
    VNIL, VFALSE:
      pc := NO_JUMP;  { always false; do nothing }
    VTRUE:
      pc := luaK_jump(fs);  { always jump }
    VJMP:
      pc := e^.info;
  else
    pc := jumponcond(fs, e, 1);
  end;
  luaK_concat(fs, e^.t, pc);  { insert last jump in `t' list }
  luaK_patchtohere(fs, e^.f);
  e^.f := NO_JUMP;
end;

procedure codenot(fs: PFuncState; e: Pexpdesc);
var temp: Integer;
begin
  luaK_dischargevars(fs, e);
  case e^.k of
    VNIL, VFALSE:
      e^.k := VTRUE;
    VK, VKNUM, VTRUE:
      e^.k := VFALSE;
    VJMP:
      invertjump(fs, e);
    VRELOCABLE, VNONRELOC:
      begin
        discharge2anyreg(fs, e);
        freeexp(fs, e);
        e^.info := luaK_codeABC(fs, OP_NOT, 0, e^.info, 0);
        e^.k := VRELOCABLE;
      end;
  end;
  { interchange true and false lists }
  temp := e^.f; e^.f := e^.t; e^.t := temp;
  removevalues(fs, e^.f);
  removevalues(fs, e^.t);
end;

procedure luaK_indexed(fs: PFuncState; t, k: Pexpdesc);
begin
  t^.aux := luaK_exp2RK(fs, k);
  t^.k := VINDEXED;
end;

function constfolding(op: OpCode; e1, e2: Pexpdesc): Boolean;
var v1, v2, r: lua_Number;
begin
  if (not isnumeral(e1)) or (not isnumeral(e2)) then Exit(False);
  v1 := e1^.nval;
  v2 := e2^.nval;
  case op of
    OP_ADD: r := v1 + v2;
    OP_SUB: r := v1 - v2;
    OP_MUL: r := v1 * v2;
    OP_DIV:
      begin
        if luai_numeq(v2, 0) then Exit(False);  { do not attempt to divide by 0 }
        r := v1 / v2;
      end;
    OP_MOD:
      begin
        if luai_numeq(v2, 0) then Exit(False);  { do not attempt to divide by 0 }
        r := v1 - c_floor(v1 / v2) * v2;
      end;
    OP_POW: r := c_pow(v1, v2);
    OP_UNM: r := luai_numunm(v1);
    OP_LEN: Exit(False);  { no constant folding for 'len' }
  else
    r := 0;
  end;
  if luai_numisnan(r) then Exit(False);  { do not attempt to produce NaN }
  e1^.nval := r;
  Result := True;
end;

procedure codearith(fs: PFuncState; op: OpCode; e1, e2: Pexpdesc);
var o1, o2: Integer;
begin
  if constfolding(op, e1, e2) then
    Exit
  else
  begin
    if (op <> OP_UNM) and (op <> OP_LEN) then o2 := luaK_exp2RK(fs, e2) else o2 := 0;
    o1 := luaK_exp2RK(fs, e1);
    if o1 > o2 then
    begin
      freeexp(fs, e1);
      freeexp(fs, e2);
    end
    else
    begin
      freeexp(fs, e2);
      freeexp(fs, e1);
    end;
    e1^.info := luaK_codeABC(fs, op, 0, o1, o2);
    e1^.k := VRELOCABLE;
  end;
end;

procedure codecomp(fs: PFuncState; op: OpCode; cond: Integer; e1, e2: Pexpdesc);
var o1, o2, temp: Integer;
begin
  o1 := luaK_exp2RK(fs, e1);
  o2 := luaK_exp2RK(fs, e2);
  freeexp(fs, e2);
  freeexp(fs, e1);
  if (cond = 0) and (op <> OP_EQ) then
  begin
    { exchange args to replace by `<' or `<=' }
    temp := o1; o1 := o2; o2 := temp;  { o1 <==> o2 }
    cond := 1;
  end;
  e1^.info := condjump(fs, op, cond, o1, o2);
  e1^.k := VJMP;
end;

procedure luaK_prefix(fs: PFuncState; op: UnOpr; e: Pexpdesc);
var e2: Texpdesc;
begin
  FillChar(e2, SizeOf(e2), 0);
  e2.k := VKNUM;
  e2.nval := 0;
  e2.t := NO_JUMP;
  e2.f := NO_JUMP;
  case op of
    OPR_MINUS:
      begin
        if not isnumeral(e) then
          luaK_exp2anyreg(fs, e);  { cannot operate on non-numeric constants }
        codearith(fs, OP_UNM, e, @e2);
      end;
    OPR_NOT:
      codenot(fs, e);
    OPR_LEN:
      begin
        luaK_exp2anyreg(fs, e);  { cannot operate on constants }
        codearith(fs, OP_LEN, e, @e2);
      end;
  end;
end;

procedure luaK_infix(fs: PFuncState; op: BinOpr; v: Pexpdesc);
begin
  case op of
    OPR_AND:
      luaK_goiftrue(fs, v);
    OPR_OR:
      luaK_goiffalse(fs, v);
    OPR_CONCAT:
      luaK_exp2nextreg(fs, v);  { operand must be on the `stack' }
    OPR_ADD, OPR_SUB, OPR_MUL, OPR_DIV, OPR_MOD, OPR_POW:
      begin
        if not isnumeral(v) then luaK_exp2RK(fs, v);
      end;
  else
    luaK_exp2RK(fs, v);
  end;
end;

procedure luaK_posfix(fs: PFuncState; op: BinOpr; e1, e2: Pexpdesc);
begin
  case op of
    OPR_AND:
      begin
        luaK_dischargevars(fs, e2);
        luaK_concat(fs, e2^.f, e1^.f);
        e1^ := e2^;
      end;
    OPR_OR:
      begin
        luaK_dischargevars(fs, e2);
        luaK_concat(fs, e2^.t, e1^.t);
        e1^ := e2^;
      end;
    OPR_CONCAT:
      begin
        luaK_exp2val(fs, e2);
        if (e2^.k = VRELOCABLE) and (GET_OPCODE(getcode(fs, e2)^) = OP_CONCAT) then
        begin
          freeexp(fs, e1);
          SETARG_B(getcode(fs, e2)^, e1^.info);
          e1^.k := VRELOCABLE;
          e1^.info := e2^.info;
        end
        else
        begin
          luaK_exp2nextreg(fs, e2);  { operand must be on the 'stack' }
          codearith(fs, OP_CONCAT, e1, e2);
        end;
      end;
    OPR_ADD: codearith(fs, OP_ADD, e1, e2);
    OPR_SUB: codearith(fs, OP_SUB, e1, e2);
    OPR_MUL: codearith(fs, OP_MUL, e1, e2);
    OPR_DIV: codearith(fs, OP_DIV, e1, e2);
    OPR_MOD: codearith(fs, OP_MOD, e1, e2);
    OPR_POW: codearith(fs, OP_POW, e1, e2);
    OPR_EQ: codecomp(fs, OP_EQ, 1, e1, e2);
    OPR_NE: codecomp(fs, OP_EQ, 0, e1, e2);
    OPR_LT: codecomp(fs, OP_LT, 1, e1, e2);
    OPR_LE: codecomp(fs, OP_LE, 1, e1, e2);
    OPR_GT: codecomp(fs, OP_LT, 0, e1, e2);
    OPR_GE: codecomp(fs, OP_LE, 0, e1, e2);
  end;
end;

procedure luaK_fixline(fs: PFuncState; line: Integer);
begin
  fs^.f^.lineinfo[fs^.pc - 1] := line;
end;

function luaK_code(fs: PFuncState; i: Instruction; line: Integer): Integer;
var f: PProto;
begin
  f := fs^.f;
  dischargejpc(fs);  { `pc' will change }
  { put new instruction in code array }
  if fs^.pc + 1 > f^.sizecode then
    f^.code := luaM_growaux_(fs^.L, f^.code, f^.sizecode, SizeOf(Instruction), MAX_INT, 'code size overflow');
  f^.code[fs^.pc] := i;
  { save corresponding line information }
  if fs^.pc + 1 > f^.sizelineinfo then
    f^.lineinfo := luaM_growaux_(fs^.L, f^.lineinfo, f^.sizelineinfo, SizeOf(Integer), MAX_INT, 'code size overflow');
  f^.lineinfo[fs^.pc] := line;
  Result := fs^.pc;
  Inc(fs^.pc);
end;

function luaK_codeABC(fs: PFuncState; o: OpCode; A, B, C: Integer): Integer;
begin
  Result := luaK_code(fs, CREATE_ABC(o, A, B, C), fs^.ls^.lastline);
end;

function luaK_codeABx(fs: PFuncState; o: OpCode; A: Integer; Bx: Cardinal): Integer;
begin
  Result := luaK_code(fs, CREATE_ABx(o, A, Bx), fs^.ls^.lastline);
end;

procedure luaK_setlist(fs: PFuncState; base, nelems, tostore: Integer);
var c, b: Integer;
begin
  c := (nelems - 1) div LFIELDS_PER_FLUSH + 1;
  if tostore = LUA_MULTRET then b := 0 else b := tostore;
  if c <= MAXARG_C then
    luaK_codeABC(fs, OP_SETLIST, base, b, c)
  else
  begin
    luaK_codeABC(fs, OP_SETLIST, base, b, 0);
    luaK_code(fs, Instruction(c), fs^.ls^.lastline);
  end;
  fs^.freereg := base + 1;  { free registers with list values }
end;

end.
