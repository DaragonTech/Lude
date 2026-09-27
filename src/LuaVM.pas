{
  Lua 5.1.4 - Pascal port of lvm.c
  Lua virtual machine
}
unit LuaVM;

{$I lua.inc}

interface

uses
  LuaTypes;

function luaV_lessthan(L: Plua_State; lo, ro: PTValue): Integer;
function luaV_equalval(L: Plua_State; t1, t2: PTValue): Integer;
function luaV_tonumber(obj: PTValue; n: PTValue): PTValue;
function luaV_tostring(L: Plua_State; obj: StkId): Integer;
procedure luaV_gettable(L: Plua_State; t: PTValue; key: PTValue; val: StkId);
procedure luaV_settable(L: Plua_State; t: PTValue; key: PTValue; val: StkId);
procedure luaV_execute(L: Plua_State; nexeccalls: Integer);
procedure luaV_concat(L: Plua_State; total, last: Integer);

function tostring(L: Plua_State; o: StkId): Boolean; inline;
function tonumber(var o: PTValue; n: PTValue): Boolean; inline;
function equalobj(L: Plua_State; o1, o2: PTValue): Boolean; inline;

implementation

uses
  LuaCRT, LuaObject, LuaOpcodes, LuaString, LuaTable, LuaTM, LuaFunc, LuaGC,
  LuaDo, LuaDebug, LuaZIO;

const
  MAXTAGLOOP = 100;  { limit for table tag-method chains (to avoid loops) }

function tostring(L: Plua_State; o: StkId): Boolean;
begin
  Result := (o^.tt = LUA_TSTRING) or (luaV_tostring(L, o) <> 0);
end;

function tonumber(var o: PTValue; n: PTValue): Boolean;
begin
  if o^.tt = LUA_TNUMBER then Exit(True);
  o := luaV_tonumber(o, n);
  Result := o <> nil;
end;

function equalobj(L: Plua_State; o1, o2: PTValue): Boolean;
begin
  Result := (o1^.tt = o2^.tt) and (luaV_equalval(L, o1, o2) <> 0);
end;

function luaV_tonumber(obj: PTValue; n: PTValue): PTValue;
var num: lua_Number;
begin
  if obj^.tt = LUA_TNUMBER then Exit(obj);
  if (obj^.tt = LUA_TSTRING) and (luaO_str2d(svalue(obj), num) <> 0) then
  begin
    setnvalue(n, num);
    Result := n;
  end
  else
    Result := nil;
end;

function luaV_tostring(L: Plua_State; obj: StkId): Integer;
var s: array[0..LUAI_MAXNUMBER2STR - 1] of AnsiChar; n: lua_Number;
begin
  if obj^.tt <> LUA_TNUMBER then
    Result := 0
  else
  begin
    n := obj^.value.n;
    lua_number2str(@s[0], n);
    setsvalue(L, obj, luaS_new(L, @s[0]));
    Result := 1;
  end;
end;

procedure traceexec(L: Plua_State; pc: PInstruction);
var mask: lu_byte; oldpc: PInstruction; p: PProto; npc, newline: Integer;
begin
  mask := L^.hookmask;
  oldpc := L^.savedpc;
  L^.savedpc := pc;
  if ((mask and LUA_MASKCOUNT) <> 0) and (L^.hookcount = 0) then
  begin
    L^.hookcount := L^.basehookcount;
    luaD_callhook(L, LUA_HOOKCOUNT, -1);
  end;
  if (mask and LUA_MASKLINE) <> 0 then
  begin
    p := ci_func(L^.ci)^.l.p;
    npc := pcRel(pc, p);
    newline := getline_(p, npc);
    { call linehook when enter a new function, when jump back (loop),
      or when enter a new line }
    if (npc = 0) or (PAnsiChar(pc) <= PAnsiChar(oldpc)) or
       (newline <> getline_(p, pcRel(oldpc, p))) then
      luaD_callhook(L, LUA_HOOKLINE, newline);
  end;
end;

procedure callTMres(L: Plua_State; res: StkId; f, p1, p2: PTValue);
var result_: ptrdiff_t;
begin
  result_ := savestack(L, res);
  setobj(L, L^.top, f);  { push function }
  setobj(L, L^.top + 1, p1);  { 1st argument }
  setobj(L, L^.top + 2, p2);  { 2nd argument }
  luaD_checkstack(L, 3);
  Inc(L^.top, 3);
  luaD_call(L, L^.top - 3, 1);
  res := restorestack(L, result_);
  Dec(L^.top);
  setobj(L, res, L^.top);
end;

procedure callTM(L: Plua_State; f, p1, p2, p3: PTValue);
begin
  setobj(L, L^.top, f);  { push function }
  setobj(L, L^.top + 1, p1);  { 1st argument }
  setobj(L, L^.top + 2, p2);  { 2nd argument }
  setobj(L, L^.top + 3, p3);  { 3th argument }
  luaD_checkstack(L, 4);
  Inc(L^.top, 4);
  luaD_call(L, L^.top - 4, 0);
end;

procedure luaV_gettable(L: Plua_State; t: PTValue; key: PTValue; val: StkId);
var loop: Integer; tm, res: PTValue; h: PTable;
begin
  for loop := 0 to MAXTAGLOOP - 1 do
  begin
    if t^.tt = LUA_TTABLE then
    begin  { `t' is a table? }
      h := hvalue(t);
      res := luaH_get(h, key);  { do a primitive get }
      if not ttisnil(res) then
      begin
        setobj(L, val, res);
        Exit;
      end;
      tm := fasttm(L, h^.metatable, TM_INDEX);
      if tm = nil then  { or no TM? }
      begin
        setobj(L, val, res);
        Exit;
      end;
      { else will try the tag method }
    end
    else
    begin
      tm := luaT_gettmbyobj(L, t, TM_INDEX);
      if ttisnil(tm) then
        luaG_typeerror(L, t, 'index');
    end;
    if ttisfunction(tm) then
    begin
      callTMres(L, val, tm, t, key);
      Exit;
    end;
    t := tm;  { else repeat with `tm' }
  end;
  luaG_runerror(L, 'loop in gettable', []);
end;

procedure luaV_settable(L: Plua_State; t: PTValue; key: PTValue; val: StkId);
var loop: Integer; tm, oldval: PTValue; h: PTable;
begin
  for loop := 0 to MAXTAGLOOP - 1 do
  begin
    if t^.tt = LUA_TTABLE then
    begin  { `t' is a table? }
      h := hvalue(t);
      oldval := luaH_set(L, h, key);  { do a primitive set }
      tm := nil;
      if ttisnil(oldval) then tm := fasttm(L, h^.metatable, TM_NEWINDEX);
      if (not ttisnil(oldval)) or (tm = nil) then
      begin  { result is no nil? or no TM? }
        setobj(L, oldval, val);
        luaC_barriert(L, h, val);
        Exit;
      end;
      { else will try the tag method }
    end
    else
    begin
      tm := luaT_gettmbyobj(L, t, TM_NEWINDEX);
      if ttisnil(tm) then
        luaG_typeerror(L, t, 'index');
    end;
    if ttisfunction(tm) then
    begin
      callTM(L, tm, t, key, val);
      Exit;
    end;
    t := tm;  { else repeat with `tm' }
  end;
  luaG_runerror(L, 'loop in settable', []);
end;

function call_binTM(L: Plua_State; p1, p2: PTValue; res: StkId; event: TMS): Boolean;
var tm: PTValue;
begin
  tm := luaT_gettmbyobj(L, p1, event);  { try first operand }
  if ttisnil(tm) then
    tm := luaT_gettmbyobj(L, p2, event);  { try second operand }
  if ttisnil(tm) then Exit(False);
  callTMres(L, res, tm, p1, p2);
  Result := True;
end;

function get_compTM(L: Plua_State; mt1, mt2: PTable; event: TMS): PTValue;
var tm1, tm2: PTValue;
begin
  tm1 := fasttm(L, mt1, event);
  if tm1 = nil then Exit(nil);  { no metamethod }
  if mt1 = mt2 then Exit(tm1);  { same metatables => same metamethods }
  tm2 := fasttm(L, mt2, event);
  if tm2 = nil then Exit(nil);  { no metamethod }
  if luaO_rawequalObj(tm1, tm2) <> 0 then  { same metamethods? }
    Exit(tm1);
  Result := nil;
end;

function call_orderTM(L: Plua_State; p1, p2: PTValue; event: TMS): Integer;
var tm1, tm2: PTValue;
begin
  tm1 := luaT_gettmbyobj(L, p1, event);
  if ttisnil(tm1) then Exit(-1);  { no metamethod? }
  tm2 := luaT_gettmbyobj(L, p2, event);
  if luaO_rawequalObj(tm1, tm2) = 0 then  { different metamethods? }
    Exit(-1);
  callTMres(L, L^.top, tm1, p1, p2);
  Result := Ord(not l_isfalse(L^.top));
end;

function l_strcmp(ls, rs: PTString): Integer;
var l, r: PAnsiChar; ll, lr, len: size_t; temp: Integer;
begin
  l := getstr(ls);
  ll := ls^.len;
  r := getstr(rs);
  lr := rs^.len;
  while True do
  begin
    temp := c_strcoll(l, r);
    if temp <> 0 then Exit(temp)
    else
    begin  { strings are equal up to a `\0' }
      len := c_strlen(l);  { index of first `\0' in both strings }
      if len = lr then  { r is finished? }
      begin
        if len = ll then Exit(0) else Exit(1);
      end
      else if len = ll then  { l is finished? }
        Exit(-1);  { l is smaller than r (because r is not finished) }
      { both strings longer than `len'; go on comparing (after the `\0') }
      Inc(len);
      Inc(l, len); Dec(ll, len); Inc(r, len); Dec(lr, len);
    end;
  end;
end;

function luaV_lessthan(L: Plua_State; lo, ro: PTValue): Integer;
var res: Integer;
begin
  if lo^.tt <> ro^.tt then
    Result := luaG_ordererror(L, lo, ro)
  else if lo^.tt = LUA_TNUMBER then
    Result := Ord(luai_numlt(lo^.value.n, ro^.value.n))
  else if lo^.tt = LUA_TSTRING then
    Result := Ord(l_strcmp(rawtsvalue(lo), rawtsvalue(ro)) < 0)
  else
  begin
    res := call_orderTM(L, lo, ro, TM_LT);
    if res <> -1 then Exit(res);
    Result := luaG_ordererror(L, lo, ro);
  end;
end;

function lessequal(L: Plua_State; lo, ro: PTValue): Integer;
var res: Integer;
begin
  if lo^.tt <> ro^.tt then
    Result := luaG_ordererror(L, lo, ro)
  else if lo^.tt = LUA_TNUMBER then
    Result := Ord(luai_numle(lo^.value.n, ro^.value.n))
  else if lo^.tt = LUA_TSTRING then
    Result := Ord(l_strcmp(rawtsvalue(lo), rawtsvalue(ro)) <= 0)
  else
  begin
    res := call_orderTM(L, lo, ro, TM_LE);  { first try `le' }
    if res <> -1 then Exit(res);
    res := call_orderTM(L, ro, lo, TM_LT);  { else try `lt' }
    if res <> -1 then Exit(Ord(res = 0));
    Result := luaG_ordererror(L, lo, ro);
  end;
end;

function luaV_equalval(L: Plua_State; t1, t2: PTValue): Integer;
var tm: PTValue;
begin
  case t1^.tt of
    LUA_TNIL: Exit(1);
    LUA_TNUMBER: Exit(Ord(luai_numeq(t1^.value.n, t2^.value.n)));
    LUA_TBOOLEAN: Exit(Ord(t1^.value.b = t2^.value.b));  { true must be 1 !! }
    LUA_TLIGHTUSERDATA: Exit(Ord(t1^.value.p = t2^.value.p));
    LUA_TUSERDATA:
      begin
        if uvalue(t1) = uvalue(t2) then Exit(1);
        tm := get_compTM(L, uvalue(t1)^.metatable, uvalue(t2)^.metatable, TM_EQ);
      end;
    LUA_TTABLE:
      begin
        if hvalue(t1) = hvalue(t2) then Exit(1);
        tm := get_compTM(L, hvalue(t1)^.metatable, hvalue(t2)^.metatable, TM_EQ);
      end;
  else
    Exit(Ord(t1^.value.gc = t2^.value.gc));
  end;
  if tm = nil then Exit(0);  { no TM? }
  callTMres(L, L^.top, tm, t1, t2);  { call TM }
  Result := Ord(not l_isfalse(L^.top));
end;

procedure luaV_concat(L: Plua_State; total, last: Integer);
var top: StkId; n, i: Integer; tl, sl: size_t; buffer: PAnsiChar;
begin
  repeat
    top := L^.base + last + 1;
    n := 2;  { number of elements handled in this pass (at least 2) }
    if not (ttisstring(top - 2) or ttisnumber(top - 2)) or not tostring(L, top - 1) then
    begin
      if not call_binTM(L, top - 2, top - 1, top - 2, TM_CONCAT) then
        luaG_concaterror(L, top - 2, top - 1);
    end
    else if tsvalue(top - 1)^.len = 0 then  { second op is empty? }
      tostring(L, top - 2)  { result is first op (as string) }
    else
    begin
      { at least two string values; get as many as possible }
      tl := tsvalue(top - 1)^.len;
      { collect total length }
      n := 1;
      while (n < total) and tostring(L, top - n - 1) do
      begin
        sl := tsvalue(top - n - 1)^.len;
        if sl >= MAX_SIZET - tl then luaG_runerror(L, 'string length overflow', []);
        Inc(tl, sl);
        Inc(n);
      end;
      buffer := luaZ_openspace(L, @L^.l_G^.buff, tl);
      tl := 0;
      for i := n downto 1 do
      begin  { concat all strings }
        sl := tsvalue(top - i)^.len;
        Move(svalue(top - i)^, (buffer + tl)^, sl);
        Inc(tl, sl);
      end;
      setsvalue(L, top - n, luaS_newlstr(L, buffer, tl));
    end;
    Dec(total, n - 1);  { got `n' strings to create 1 new }
    Dec(last, n - 1);
  until total <= 1;  { repeat until only 1 result left }
end;

function luai_nummod(a, b: lua_Number): lua_Number; inline;
begin
  Result := a - c_floor(a / b) * b;
end;

procedure Arith(L: Plua_State; ra: StkId; rb, rc: PTValue; op: TMS);
var tempb, tempc: TValue; b, c: PTValue; nb, nc: lua_Number;
begin
  b := luaV_tonumber(rb, @tempb);
  c := nil;
  if b <> nil then c := luaV_tonumber(rc, @tempc);
  if (b <> nil) and (c <> nil) then
  begin
    nb := b^.value.n;
    nc := c^.value.n;
    case op of
      TM_ADD: setnvalue(ra, nb + nc);
      TM_SUB: setnvalue(ra, nb - nc);
      TM_MUL: setnvalue(ra, nb * nc);
      TM_DIV: setnvalue(ra, nb / nc);
      TM_MOD: setnvalue(ra, luai_nummod(nb, nc));
      TM_POW: setnvalue(ra, c_pow(nb, nc));
      TM_UNM: setnvalue(ra, luai_numunm(nb));
    end;
  end
  else if not call_binTM(L, rb, rc, ra, op) then
    luaG_aritherror(L, rb, rc);
end;

procedure luaV_execute(L: Plua_State; nexeccalls: Integer);
label
  reentry;
var
  cl: PLClosure;
  base: StkId;
  k: PTValue;
  pc: PInstruction;
  i: Instruction;
  ra, rb, rc, cb, func, pfunc, val: StkId;
  g: TValue;
  b, c, n, j, aux, nresults, last, nup: Integer;
  nb, nc, step, idx, limit: lua_Number;
  uv: PUpVal;
  h: PTable;
  ci: PCallInfo;
  p: PProto;
  ncl: PClosure;
  init, plimit, pstep: PTValue;
begin
reentry:  { entry point }
  pc := L^.savedpc;
  cl := @clvalue(L^.ci^.func)^.l;
  base := L^.base;
  k := cl^.p^.k;
  { main loop of interpreter }
  while True do
  begin
    i := pc^;
    Inc(pc);
    if ((L^.hookmask and (LUA_MASKLINE or LUA_MASKCOUNT)) <> 0) then
    begin
      Dec(L^.hookcount);
      if (L^.hookcount = 0) or ((L^.hookmask and LUA_MASKLINE) <> 0) then
      begin
        traceexec(L, pc);
        if L^.status = LUA_YIELD_ then
        begin  { did hook yield? }
          L^.savedpc := pc - 1;
          Exit;
        end;
        base := L^.base;
      end;
    end;
    { warning!! several calls may realloc the stack and invalidate `ra' }
    ra := base + GETARG_A(i);
    case GET_OPCODE(i) of
      OP_MOVE:
        begin
          setobj(L, ra, base + GETARG_B(i));
          Continue;
        end;
      OP_LOADK:
        begin
          setobj(L, ra, k + GETARG_Bx(i));
          Continue;
        end;
      OP_LOADBOOL:
        begin
          setbvalue(ra, GETARG_B(i));
          if GETARG_C(i) <> 0 then Inc(pc);  { skip next instruction (if C) }
          Continue;
        end;
      OP_LOADNIL:
        begin
          rb := base + GETARG_B(i);
          repeat
            setnilvalue(rb);
            Dec(rb);
          until PAnsiChar(rb) < PAnsiChar(ra);
          Continue;
        end;
      OP_GETUPVAL:
        begin
          b := GETARG_B(i);
          setobj(L, ra, PPUpVal(@cl^.upvals)[b]^.v);
          Continue;
        end;
      OP_GETGLOBAL:
        begin
          rb := k + GETARG_Bx(i);
          sethvalue(L, @g, cl^.env);
          L^.savedpc := pc;
          luaV_gettable(L, @g, rb, ra);
          base := L^.base;
          Continue;
        end;
      OP_GETTABLE:
        begin
          c := GETARG_C(i);
          if ISK(c) then rc := k + INDEXK(c) else rc := base + c;
          L^.savedpc := pc;
          luaV_gettable(L, base + GETARG_B(i), rc, ra);
          base := L^.base;
          Continue;
        end;
      OP_SETGLOBAL:
        begin
          sethvalue(L, @g, cl^.env);
          L^.savedpc := pc;
          luaV_settable(L, @g, k + GETARG_Bx(i), ra);
          base := L^.base;
          Continue;
        end;
      OP_SETUPVAL:
        begin
          uv := PPUpVal(@cl^.upvals)[GETARG_B(i)];
          setobj(L, uv^.v, ra);
          luaC_barrier(L, uv, ra);
          Continue;
        end;
      OP_SETTABLE:
        begin
          b := GETARG_B(i);
          if ISK(b) then rb := k + INDEXK(b) else rb := base + b;
          c := GETARG_C(i);
          if ISK(c) then rc := k + INDEXK(c) else rc := base + c;
          L^.savedpc := pc;
          luaV_settable(L, ra, rb, rc);
          base := L^.base;
          Continue;
        end;
      OP_NEWTABLE:
        begin
          b := GETARG_B(i);
          c := GETARG_C(i);
          sethvalue(L, ra, luaH_new(L, luaO_fb2int(b), luaO_fb2int(c)));
          L^.savedpc := pc;
          luaC_checkGC(L);
          base := L^.base;
          Continue;
        end;
      OP_SELF:
        begin
          rb := base + GETARG_B(i);
          setobj(L, ra + 1, rb);
          c := GETARG_C(i);
          if ISK(c) then rc := k + INDEXK(c) else rc := base + c;
          L^.savedpc := pc;
          luaV_gettable(L, rb, rc, ra);
          base := L^.base;
          Continue;
        end;
      OP_ADD, OP_SUB, OP_MUL, OP_DIV, OP_MOD, OP_POW:
        begin
          b := GETARG_B(i);
          if ISK(b) then rb := k + INDEXK(b) else rb := base + b;
          c := GETARG_C(i);
          if ISK(c) then rc := k + INDEXK(c) else rc := base + c;
          if (rb^.tt = LUA_TNUMBER) and (rc^.tt = LUA_TNUMBER) then
          begin
            nb := rb^.value.n;
            nc := rc^.value.n;
            case GET_OPCODE(i) of
              OP_ADD: setnvalue(ra, nb + nc);
              OP_SUB: setnvalue(ra, nb - nc);
              OP_MUL: setnvalue(ra, nb * nc);
              OP_DIV: setnvalue(ra, nb / nc);
              OP_MOD: setnvalue(ra, luai_nummod(nb, nc));
            else
              setnvalue(ra, c_pow(nb, nc));
            end;
          end
          else
          begin
            L^.savedpc := pc;
            Arith(L, ra, rb, rc, GET_OPCODE(i) - OP_ADD + TM_ADD);
            base := L^.base;
          end;
          Continue;
        end;
      OP_UNM:
        begin
          rb := base + GETARG_B(i);
          if rb^.tt = LUA_TNUMBER then
          begin
            nb := rb^.value.n;
            setnvalue(ra, luai_numunm(nb));
          end
          else
          begin
            L^.savedpc := pc;
            Arith(L, ra, rb, rb, TM_UNM);
            base := L^.base;
          end;
          Continue;
        end;
      OP_NOT:
        begin
          setbvalue(ra, Ord(l_isfalse(base + GETARG_B(i))));  { next assignment may change this value }
          Continue;
        end;
      OP_LEN:
        begin
          rb := base + GETARG_B(i);
          case rb^.tt of
            LUA_TTABLE:
              setnvalue(ra, luaH_getn(hvalue(rb)));
            LUA_TSTRING:
              setnvalue(ra, tsvalue(rb)^.len);
          else
            begin  { try metamethod }
              L^.savedpc := pc;
              if not call_binTM(L, rb, luaO_nilobject, ra, TM_LEN) then
                luaG_typeerror(L, rb, 'get length of');
              base := L^.base;
            end;
          end;
          Continue;
        end;
      OP_CONCAT:
        begin
          b := GETARG_B(i);
          c := GETARG_C(i);
          L^.savedpc := pc;
          luaV_concat(L, c - b + 1, c);
          luaC_checkGC(L);
          base := L^.base;
          setobj(L, base + GETARG_A(i), base + b);
          Continue;
        end;
      OP_JMP:
        begin
          Inc(pc, GETARG_sBx(i));
          Continue;
        end;
      OP_EQ:
        begin
          b := GETARG_B(i);
          if ISK(b) then rb := k + INDEXK(b) else rb := base + b;
          c := GETARG_C(i);
          if ISK(c) then rc := k + INDEXK(c) else rc := base + c;
          L^.savedpc := pc;
          if Ord(equalobj(L, rb, rc)) = GETARG_A(i) then
            Inc(pc, GETARG_sBx(pc^));
          base := L^.base;
          Inc(pc);
          Continue;
        end;
      OP_LT:
        begin
          b := GETARG_B(i);
          if ISK(b) then rb := k + INDEXK(b) else rb := base + b;
          c := GETARG_C(i);
          if ISK(c) then rc := k + INDEXK(c) else rc := base + c;
          L^.savedpc := pc;
          if luaV_lessthan(L, rb, rc) = GETARG_A(i) then
            Inc(pc, GETARG_sBx(pc^));
          base := L^.base;
          Inc(pc);
          Continue;
        end;
      OP_LE:
        begin
          b := GETARG_B(i);
          if ISK(b) then rb := k + INDEXK(b) else rb := base + b;
          c := GETARG_C(i);
          if ISK(c) then rc := k + INDEXK(c) else rc := base + c;
          L^.savedpc := pc;
          if lessequal(L, rb, rc) = GETARG_A(i) then
            Inc(pc, GETARG_sBx(pc^));
          base := L^.base;
          Inc(pc);
          Continue;
        end;
      OP_TEST:
        begin
          if Ord(l_isfalse(ra)) <> GETARG_C(i) then
            Inc(pc, GETARG_sBx(pc^));
          Inc(pc);
          Continue;
        end;
      OP_TESTSET:
        begin
          rb := base + GETARG_B(i);
          if Ord(l_isfalse(rb)) <> GETARG_C(i) then
          begin
            setobj(L, ra, rb);
            Inc(pc, GETARG_sBx(pc^));
          end;
          Inc(pc);
          Continue;
        end;
      OP_CALL:
        begin
          b := GETARG_B(i);
          nresults := GETARG_C(i) - 1;
          if b <> 0 then L^.top := ra + b;  { else previous instruction set top }
          L^.savedpc := pc;
          case luaD_precall(L, ra, nresults) of
            PCRLUA:
              begin
                Inc(nexeccalls);
                goto reentry;  { restart luaV_execute over new Lua function }
              end;
            PCRC:
              begin
                { it was a C function (`precall' called it); adjust results }
                if nresults >= 0 then L^.top := L^.ci^.top;
                base := L^.base;
                Continue;
              end;
          else
            Exit;  { yield }
          end;
        end;
      OP_TAILCALL:
        begin
          b := GETARG_B(i);
          if b <> 0 then L^.top := ra + b;  { else previous instruction set top }
          L^.savedpc := pc;
          case luaD_precall(L, ra, LUA_MULTRET) of
            PCRLUA:
              begin
                { tail call: put new frame in place of previous one }
                ci := L^.ci - 1;  { previous frame }
                func := ci^.func;
                pfunc := (ci + 1)^.func;  { previous function index }
                if L^.openupval <> nil then luaF_close(L, ci^.base);
                ci^.base := ci^.func + StkDiff((ci + 1)^.base, pfunc);
                L^.base := ci^.base;
                aux := 0;
                while PAnsiChar(pfunc + aux) < PAnsiChar(L^.top) do  { move frame down }
                begin
                  setobj(L, func + aux, pfunc + aux);
                  Inc(aux);
                end;
                L^.top := func + aux;
                ci^.top := L^.top;
                ci^.savedpc := L^.savedpc;
                Inc(ci^.tailcalls);  { one more call lost }
                Dec(L^.ci);  { remove new frame }
                goto reentry;
              end;
            PCRC:
              begin  { it was a C function (`precall' called it) }
                base := L^.base;
                Continue;
              end;
          else
            Exit;  { yield }
          end;
        end;
      OP_RETURN:
        begin
          b := GETARG_B(i);
          if b <> 0 then L^.top := ra + b - 1;
          if L^.openupval <> nil then luaF_close(L, base);
          L^.savedpc := pc;
          b := luaD_poscall(L, ra);
          Dec(nexeccalls);
          if nexeccalls = 0 then  { was previous function running `here'? }
            Exit  { no: return }
          else
          begin  { yes: continue its execution }
            if b <> 0 then L^.top := L^.ci^.top;
            goto reentry;
          end;
        end;
      OP_FORLOOP:
        begin
          step := (ra + 2)^.value.n;
          idx := ra^.value.n + step;  { increment index }
          limit := (ra + 1)^.value.n;
          if luai_numlt(0, step) then
          begin
            if not luai_numle(idx, limit) then Continue;
          end
          else if not luai_numle(limit, idx) then Continue;
          Inc(pc, GETARG_sBx(i));  { jump back }
          setnvalue(ra, idx);  { update internal index... }
          setnvalue(ra + 3, idx);  { ...and external index }
          Continue;
        end;
      OP_FORPREP:
        begin
          init := ra;
          plimit := ra + 1;
          pstep := ra + 2;
          L^.savedpc := pc;  { next steps may throw errors }
          if not tonumber(init, ra) then
            luaG_runerror(L, '''for'' initial value must be a number', [])
          else if not tonumber(plimit, ra + 1) then
            luaG_runerror(L, '''for'' limit must be a number', [])
          else if not tonumber(pstep, ra + 2) then
            luaG_runerror(L, '''for'' step must be a number', []);
          setnvalue(ra, ra^.value.n - pstep^.value.n);
          Inc(pc, GETARG_sBx(i));
          Continue;
        end;
      OP_TFORLOOP:
        begin
          cb := ra + 3;  { call base }
          setobj(L, cb + 2, ra + 2);
          setobj(L, cb + 1, ra + 1);
          setobj(L, cb, ra);
          L^.top := cb + 3;  { func. + 2 args (state and index) }
          L^.savedpc := pc;
          luaD_call(L, cb, GETARG_C(i));
          base := L^.base;
          L^.top := L^.ci^.top;
          cb := base + GETARG_A(i) + 3;  { previous call may change the stack }
          if not ttisnil(cb) then
          begin  { continue loop? }
            setobj(L, cb - 1, cb);  { save control variable }
            Inc(pc, GETARG_sBx(pc^));  { jump back }
          end;
          Inc(pc);
          Continue;
        end;
      OP_SETLIST:
        begin
          n := GETARG_B(i);
          c := GETARG_C(i);
          if n = 0 then
          begin
            n := StkDiff(L^.top, ra) - 1;
            L^.top := L^.ci^.top;
          end;
          if c = 0 then
          begin
            c := Integer(pc^);
            Inc(pc);
          end;
          if not ttistable(ra) then Continue;  { runtime_check }
          h := hvalue(ra);
          last := ((c - 1) * LFIELDS_PER_FLUSH) + n;
          if last > h^.sizearray then  { needs more space? }
            luaH_resizearray(L, h, last);  { pre-alloc it at once }
          while n > 0 do
          begin
            val := ra + n;
            setobj(L, luaH_setnum(L, h, last), val);
            Dec(last);
            luaC_barriert(L, h, val);
            Dec(n);
          end;
          Continue;
        end;
      OP_CLOSE:
        begin
          luaF_close(L, ra);
          Continue;
        end;
      OP_CLOSURE:
        begin
          p := cl^.p^.p[GETARG_Bx(i)];
          nup := p^.nups;
          ncl := luaF_newLclosure(L, nup, cl^.env);
          ncl^.l.p := p;
          for j := 0 to nup - 1 do
          begin
            if GET_OPCODE(pc^) = OP_GETUPVAL then
              PPUpVal(@ncl^.l.upvals)[j] := PPUpVal(@cl^.upvals)[GETARG_B(pc^)]
            else
              PPUpVal(@ncl^.l.upvals)[j] := luaF_findupval(L, base + GETARG_B(pc^));
            Inc(pc);
          end;
          setclvalue(L, ra, ncl);
          L^.savedpc := pc;
          luaC_checkGC(L);
          base := L^.base;
          Continue;
        end;
      OP_VARARG:
        begin
          b := GETARG_B(i) - 1;
          ci := L^.ci;
          n := StkDiff(ci^.base, ci^.func) - cl^.p^.numparams - 1;
          if b = LUA_MULTRET then
          begin
            L^.savedpc := pc;
            luaD_checkstack(L, n);
            base := L^.base;
            ra := base + GETARG_A(i);  { previous call may change the stack }
            b := n;
            L^.top := ra + n;
          end;
          for j := 0 to b - 1 do
          begin
            if j < n then
              setobj(L, ra + j, ci^.base - n + j)
            else
              setnilvalue(ra + j);
          end;
          Continue;
        end;
    end;
  end;
end;

end.
