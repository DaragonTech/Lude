{
  Lua 5.1.4 - Pascal port of lgc.c
  Garbage Collector
}
unit LuaGC;

{$I lua.inc}

interface

uses
  LuaTypes;

function luaC_separateudata(L: Plua_State; all: Integer): size_t;
procedure luaC_callGCTM(L: Plua_State);
procedure luaC_freeall(L: Plua_State);
procedure luaC_step(L: Plua_State);
procedure luaC_fullgc(L: Plua_State);
procedure luaC_link(L: Plua_State; o: PGCObject; tt: lu_byte);
procedure luaC_linkupval(L: Plua_State; uv: PUpVal);
procedure luaC_barrierf(L: Plua_State; o, v: PGCObject);
procedure luaC_barrierback(L: Plua_State; t: PTable);

procedure luaC_checkGC(L: Plua_State); inline;
procedure luaC_barrier(L: Plua_State; p: Pointer; v: PTValue); inline;
procedure luaC_barriert(L: Plua_State; t: PTable; v: PTValue); inline;
procedure luaC_objbarrier(L: Plua_State; p, o: Pointer); inline;
procedure luaC_objbarriert(L: Plua_State; t: PTable; o: Pointer); inline;

implementation

uses
  LuaCRT, LuaMem, LuaString, LuaFunc, LuaTable, LuaTM, LuaState, LuaDo, LuaZIO;

const
  GCSTEPSIZE = 1024;
  GCSWEEPMAX = 40;
  GCSWEEPCOST = 10;
  GCFINALIZECOST = 100;

  maskmarks = lu_byte(not ((1 shl BLACKBIT) or WHITEBITS));
  KEYWEAK = 1 shl KEYWEAKBIT;
  VALUEWEAK = 1 shl VALUEWEAKBIT;

procedure luaC_checkGC(L: Plua_State);
begin
  if L^.l_G^.totalbytes >= L^.l_G^.GCthreshold then
    luaC_step(L);
end;

procedure luaC_barrier(L: Plua_State; p: Pointer; v: PTValue);
begin
  if valiswhite(v) and isblack(obj2gco(p)) then
    luaC_barrierf(L, obj2gco(p), gcvalue(v));
end;

procedure luaC_barriert(L: Plua_State; t: PTable; v: PTValue);
begin
  if valiswhite(v) and isblack(obj2gco(t)) then
    luaC_barrierback(L, t);
end;

procedure luaC_objbarrier(L: Plua_State; p, o: Pointer);
begin
  if iswhite(obj2gco(o)) and isblack(obj2gco(p)) then
    luaC_barrierf(L, obj2gco(p), obj2gco(o));
end;

procedure luaC_objbarriert(L: Plua_State; t: PTable; o: Pointer);
begin
  if iswhite(obj2gco(o)) and isblack(obj2gco(t)) then
    luaC_barrierback(L, t);
end;

procedure makewhite(g: Pglobal_State; x: PGCObject); inline;
begin
  x^.marked := lu_byte((x^.marked and maskmarks) or luaC_white(g));
end;

procedure white2gray(x: PGCObject); inline;
begin
  x^.marked := x^.marked and lu_byte(not WHITEBITS);
end;

procedure black2gray(x: PGCObject); inline;
begin
  x^.marked := x^.marked and lu_byte(not (1 shl BLACKBIT));
end;

procedure stringmark(s: PTString); inline;
begin
  s^.marked := s^.marked and lu_byte(not WHITEBITS);
end;

function isfinalized(u: PUdata): Boolean; inline;
begin
  Result := (u^.marked and (1 shl FINALIZEDBIT)) <> 0;
end;

procedure markfinalized(u: PUdata); inline;
begin
  u^.marked := u^.marked or (1 shl FINALIZEDBIT);
end;

procedure setthreshold(g: Pglobal_State); inline;
begin
  g^.GCthreshold := (g^.estimate div 100) * lu_mem(g^.gcpause);
end;

procedure reallymarkobject(g: Pglobal_State; o: PGCObject); forward;

procedure markvalue(g: Pglobal_State; o: PTValue); inline;
begin
  if (o^.tt >= LUA_TSTRING) and iswhite(o^.value.gc) then
    reallymarkobject(g, o^.value.gc);
end;

procedure markobject(g: Pglobal_State; t: Pointer); inline;
begin
  if iswhite(obj2gco(t)) then
    reallymarkobject(g, obj2gco(t));
end;

procedure removeentry(n: PNode);
begin
  if iscollectable(gkey(n)) then
    gkey(n)^.tt := LUA_TDEADKEY;  { dead key; remove it }
end;

procedure reallymarkobject(g: Pglobal_State; o: PGCObject);
var mt: PTable; uv: PUpVal;
begin
  white2gray(o);
  case o^.tt of
    LUA_TSTRING:
      Exit;
    LUA_TUSERDATA:
      begin
        mt := gco2u(o)^.metatable;
        gray2black(o);  { udata are never gray }
        if mt <> nil then markobject(g, mt);
        markobject(g, gco2u(o)^.env);
        Exit;
      end;
    LUA_TUPVAL:
      begin
        uv := gco2uv(o);
        markvalue(g, uv^.v);
        if uv^.v = @uv^.value then  { closed? }
          gray2black(o);  { open upvalues are never black }
        Exit;
      end;
    LUA_TFUNCTION:
      begin
        gco2cl(o)^.c.gclist := g^.gray;
        g^.gray := o;
      end;
    LUA_TTABLE:
      begin
        gco2h(o)^.gclist := g^.gray;
        g^.gray := o;
      end;
    LUA_TTHREAD:
      begin
        gco2th(o)^.gclist := g^.gray;
        g^.gray := o;
      end;
    LUA_TPROTO:
      begin
        gco2p(o)^.gclist := g^.gray;
        g^.gray := o;
      end;
  end;
end;

procedure marktmu(g: Pglobal_State);
var u: PGCObject;
begin
  u := g^.tmudata;
  if u <> nil then
  begin
    repeat
      u := u^.next;
      makewhite(g, u);  { may be marked, if left from previous GC }
      reallymarkobject(g, u);
    until u = g^.tmudata;
  end;
end;

{ move `dead' udata that need finalization to list `tmudata' }
function luaC_separateudata(L: Plua_State; all: Integer): size_t;
var g: Pglobal_State; deadmem: size_t; p: PPGCObject; curr: PGCObject;
begin
  g := L^.l_G;
  deadmem := 0;
  p := @g^.mainthread^.next;
  while True do
  begin
    curr := p^;
    if curr = nil then Break;
    if (not (iswhite(curr) or (all <> 0))) or isfinalized(gco2u(curr)) then
      p := @curr^.next  { don't bother with them }
    else if fasttm(L, gco2u(curr)^.metatable, TM_GC) = nil then
    begin
      markfinalized(gco2u(curr));  { don't need finalization }
      p := @curr^.next;
    end
    else
    begin  { must call its gc method }
      Inc(deadmem, sizeudata(gco2u(curr)));
      markfinalized(gco2u(curr));
      p^ := curr^.next;
      { link `curr' at the end of `tmudata' list }
      if g^.tmudata = nil then  { list is empty? }
      begin
        curr^.next := curr;  { creates a circular list }
        g^.tmudata := curr;
      end
      else
      begin
        curr^.next := g^.tmudata^.next;
        g^.tmudata^.next := curr;
        g^.tmudata := curr;
      end;
    end;
  end;
  Result := deadmem;
end;

function traversetable(g: Pglobal_State; h: PTable): Integer;
var i: Integer; weakkey, weakvalue: Integer; mode: PTValue; n: PNode;
begin
  weakkey := 0;
  weakvalue := 0;
  if h^.metatable <> nil then
    markobject(g, h^.metatable);
  mode := gfasttm(g, h^.metatable, TM_MODE);
  if (mode <> nil) and ttisstring(mode) then
  begin  { is there a weak mode? }
    weakkey := Ord(c_strchr(svalue(mode), Ord('k')) <> nil);
    weakvalue := Ord(c_strchr(svalue(mode), Ord('v')) <> nil);
    if (weakkey <> 0) or (weakvalue <> 0) then
    begin  { is really weak? }
      h^.marked := h^.marked and lu_byte(not (KEYWEAK or VALUEWEAK));  { clear bits }
      h^.marked := h^.marked or lu_byte((weakkey shl KEYWEAKBIT) or (weakvalue shl VALUEWEAKBIT));
      h^.gclist := g^.weak;  { must be cleared after GC, ... }
      g^.weak := obj2gco(h);  { ... so put in the appropriate list }
    end;
  end;
  if (weakkey <> 0) and (weakvalue <> 0) then Exit(1);
  if weakvalue = 0 then
  begin
    i := h^.sizearray;
    while i > 0 do
    begin
      Dec(i);
      markvalue(g, @h^.arr[i]);
    end;
  end;
  i := sizenode(h);
  while i > 0 do
  begin
    Dec(i);
    n := gnode(h, i);
    if ttisnil(gval(n)) then
      removeentry(n)  { remove empty entries }
    else
    begin
      if weakkey = 0 then markvalue(g, gkey(n));
      if weakvalue = 0 then markvalue(g, gval(n));
    end;
  end;
  Result := Ord((weakkey <> 0) or (weakvalue <> 0));
end;

{ All marks are conditional because a GC may happen while the
  prototype is still being created }
procedure traverseproto(g: Pglobal_State; f: PProto);
var i: Integer;
begin
  if f^.source <> nil then stringmark(f^.source);
  for i := 0 to f^.sizek - 1 do  { mark literals }
    markvalue(g, @f^.k[i]);
  for i := 0 to f^.sizeupvalues - 1 do
  begin  { mark upvalue names }
    if f^.upvalues[i] <> nil then
      stringmark(f^.upvalues[i]);
  end;
  for i := 0 to f^.sizep - 1 do
  begin  { mark nested protos }
    if f^.p[i] <> nil then
      markobject(g, f^.p[i]);
  end;
  for i := 0 to f^.sizelocvars - 1 do
  begin  { mark local-variable names }
    if f^.locvars[i].varname <> nil then
      stringmark(f^.locvars[i].varname);
  end;
end;

procedure traverseclosure(g: Pglobal_State; cl: PClosure);
var i: Integer;
begin
  markobject(g, cl^.c.env);
  if cl^.c.isC <> 0 then
  begin
    for i := 0 to cl^.c.nupvalues - 1 do  { mark its upvalues }
      markvalue(g, @PTValue(@cl^.c.upvalue)[i]);
  end
  else
  begin
    markobject(g, cl^.l.p);
    for i := 0 to cl^.l.nupvalues - 1 do  { mark its upvalues }
      markobject(g, PPUpVal(@cl^.l.upvals)[i]);
  end;
end;

procedure checkstacksizes(L: Plua_State; max: StkId);
var ci_used, s_used: Integer;
begin
  ci_used := Integer((PAnsiChar(L^.ci) - PAnsiChar(L^.base_ci)) div SizeOf(TCallInfo));  { number of `ci' in use }
  s_used := StkDiff(max, L^.stack);  { part of stack in use }
  if L^.size_ci > LUAI_MAXCALLS then  { handling overflow? }
    Exit;  { do not touch the stacks }
  if (4 * ci_used < L^.size_ci) and (2 * BASIC_CI_SIZE < L^.size_ci) then
    luaD_reallocCI(L, L^.size_ci div 2);  { still big enough... }
  if (4 * s_used < L^.stacksize) and
     (2 * (BASIC_STACK_SIZE + EXTRA_STACK) < L^.stacksize) then
    luaD_reallocstack(L, L^.stacksize div 2);  { still big enough... }
end;

procedure traversestack(g: Pglobal_State; l: Plua_State);
var o, lim: StkId; ci: PCallInfo;
begin
  markvalue(g, gt(l));
  lim := l^.top;
  ci := l^.base_ci;
  while PAnsiChar(ci) <= PAnsiChar(l^.ci) do
  begin
    if PAnsiChar(lim) < PAnsiChar(ci^.top) then lim := ci^.top;
    Inc(ci);
  end;
  o := l^.stack;
  while PAnsiChar(o) < PAnsiChar(l^.top) do
  begin
    markvalue(g, o);
    Inc(o);
  end;
  while PAnsiChar(o) <= PAnsiChar(lim) do
  begin
    setnilvalue(o);
    Inc(o);
  end;
  checkstacksizes(l, lim);
end;

{ traverse one gray object, turning it to black.
  Returns `quantity' traversed. }
function propagatemark(g: Pglobal_State): l_mem;
var o: PGCObject; h: PTable; cl: PClosure; th: Plua_State; p: PProto;
begin
  o := g^.gray;
  gray2black(o);
  case o^.tt of
    LUA_TTABLE:
      begin
        h := gco2h(o);
        g^.gray := h^.gclist;
        if traversetable(g, h) <> 0 then  { table is weak? }
          black2gray(o);  { keep it gray }
        Result := SizeOf(TTable) + SizeOf(TValue) * h^.sizearray +
                  SizeOf(TNode) * sizenode(h);
      end;
    LUA_TFUNCTION:
      begin
        cl := gco2cl(o);
        g^.gray := cl^.c.gclist;
        traverseclosure(g, cl);
        if cl^.c.isC <> 0 then Result := sizeCclosure(cl^.c.nupvalues)
        else Result := sizeLclosure(cl^.l.nupvalues);
      end;
    LUA_TTHREAD:
      begin
        th := gco2th(o);
        g^.gray := th^.gclist;
        th^.gclist := g^.grayagain;
        g^.grayagain := o;
        black2gray(o);
        traversestack(g, th);
        Result := SizeOf(lua_State) + SizeOf(TValue) * th^.stacksize +
                  SizeOf(TCallInfo) * th^.size_ci;
      end;
    LUA_TPROTO:
      begin
        p := gco2p(o);
        g^.gray := p^.gclist;
        traverseproto(g, p);
        Result := SizeOf(TProto) + SizeOf(Instruction) * p^.sizecode +
                  SizeOf(PProto) * p^.sizep +
                  SizeOf(TValue) * p^.sizek +
                  SizeOf(Integer) * p^.sizelineinfo +
                  SizeOf(TLocVar) * p^.sizelocvars +
                  SizeOf(PTString) * p^.sizeupvalues;
      end;
  else
    Result := 0;
  end;
end;

function propagateall(g: Pglobal_State): size_t;
var m: size_t;
begin
  m := 0;
  while g^.gray <> nil do Inc(m, propagatemark(g));
  Result := m;
end;

{ The next function tells whether a key or value can be cleared from
  a weak table. Non-collectable objects are never removed from weak
  tables. Strings behave as `values', so are never removed too. for
  other objects: if really collected, cannot keep them; for userdata
  being finalized, keep them in keys, but not in values }
function iscleared(o: PTValue; iskey: Boolean): Boolean;
begin
  if not iscollectable(o) then Exit(False);
  if ttisstring(o) then
  begin
    stringmark(rawtsvalue(o));  { strings are `values', so are never weak }
    Exit(False);
  end;
  Result := iswhite(gcvalue(o)) or
    (ttisuserdata(o) and ((not iskey) and isfinalized(uvalue(o))));
end;

{ clear collected entries from weaktables }
procedure cleartable(l: PGCObject);
var h: PTable; i: Integer; o: PTValue; n: PNode;
begin
  while l <> nil do
  begin
    h := gco2h(l);
    i := h^.sizearray;
    if (h^.marked and (1 shl VALUEWEAKBIT)) <> 0 then
    begin
      while i > 0 do
      begin
        Dec(i);
        o := @h^.arr[i];
        if iscleared(o, False) then  { value was collected? }
          setnilvalue(o);  { remove value }
      end;
    end;
    i := sizenode(h);
    while i > 0 do
    begin
      Dec(i);
      n := gnode(h, i);
      if (not ttisnil(gval(n))) and  { non-empty entry? }
         (iscleared(key2tval(n), True) or iscleared(gval(n), False)) then
      begin
        setnilvalue(gval(n));  { remove value ... }
        removeentry(n);  { remove entry from table }
      end;
    end;
    l := h^.gclist;
  end;
end;

procedure freeobj(L: Plua_State; o: PGCObject);
begin
  case o^.tt of
    LUA_TPROTO: luaF_freeproto(L, gco2p(o));
    LUA_TFUNCTION: luaF_freeclosure(L, gco2cl(o));
    LUA_TUPVAL: luaF_freeupval(L, gco2uv(o));
    LUA_TTABLE: luaH_free(L, gco2h(o));
    LUA_TTHREAD: luaE_freethread(L, gco2th(o));
    LUA_TSTRING:
      begin
        Dec(L^.l_G^.strt.nuse);
        luaM_freemem(L, o, sizestring(gco2ts(o)));
      end;
    LUA_TUSERDATA:
      luaM_freemem(L, o, sizeudata(gco2u(o)));
  end;
end;

function sweeplist(L: Plua_State; p: PPGCObject; count: lu_mem): PPGCObject; forward;

procedure sweepwholelist(L: Plua_State; p: PPGCObject); inline;
begin
  sweeplist(L, p, MAX_LUMEM);
end;

function sweeplist(L: Plua_State; p: PPGCObject; count: lu_mem): PPGCObject;
var curr: PGCObject; g: Pglobal_State; deadmask: Integer;
begin
  g := L^.l_G;
  deadmask := otherwhite(g);
  while True do
  begin
    curr := p^;
    if curr = nil then Break;
    if count = 0 then Break;
    Dec(count);
    if curr^.tt = LUA_TTHREAD then  { sweep open upvalues of each thread }
      sweepwholelist(L, @gco2th(curr)^.openupval);
    if ((curr^.marked xor WHITEBITS) and deadmask) <> 0 then
    begin  { not dead? }
      makewhite(g, curr);  { make it white (for next cycle) }
      p := @curr^.next;
    end
    else
    begin  { must erase `curr' }
      p^ := curr^.next;
      if curr = g^.rootgc then  { is the first element of the list? }
        g^.rootgc := curr^.next;  { adjust first }
      freeobj(L, curr);
    end;
  end;
  Result := p;
end;

procedure checkSizes(L: Plua_State);
var g: Pglobal_State; newsize: size_t;
begin
  g := L^.l_G;
  { check size of string hash }
  if (g^.strt.nuse < lu_int32(g^.strt.size div 4)) and
     (g^.strt.size > MINSTRTABSIZE * 2) then
    luaS_resize(L, g^.strt.size div 2);  { table is too big }
  { check size of buffer }
  if g^.buff.buffsize > LUA_MINBUFFER * 2 then
  begin  { buffer too big? }
    newsize := g^.buff.buffsize div 2;
    luaZ_resizebuffer(L, @g^.buff, newsize);
  end;
end;

procedure GCTM(L: Plua_State);
var g: Pglobal_State; o: PGCObject; udata: PUdata; tm: PTValue; oldah: lu_byte; oldt: lu_mem;
begin
  g := L^.l_G;
  o := g^.tmudata^.next;  { get first element }
  udata := gco2u(o);
  { remove udata from `tmudata' }
  if o = g^.tmudata then  { last element? }
    g^.tmudata := nil
  else
    g^.tmudata^.next := udata^.next;
  udata^.next := g^.mainthread^.next;  { return it to `root' list }
  g^.mainthread^.next := o;
  makewhite(g, o);
  tm := fasttm(L, udata^.metatable, TM_GC);
  if tm <> nil then
  begin
    oldah := L^.allowhook;
    oldt := g^.GCthreshold;
    L^.allowhook := 0;  { stop debug hooks during GC tag method }
    g^.GCthreshold := 2 * g^.totalbytes;  { avoid GC steps }
    setobj(L, L^.top, tm);
    setuvalue(L, L^.top + 1, udata);
    Inc(L^.top, 2);
    luaD_call(L, L^.top - 2, 0);
    L^.allowhook := oldah;  { restore hooks }
    g^.GCthreshold := oldt;  { restore threshold }
  end;
end;

{ Call all GC tag methods }
procedure luaC_callGCTM(L: Plua_State);
begin
  while L^.l_G^.tmudata <> nil do
    GCTM(L);
end;

procedure luaC_freeall(L: Plua_State);
var g: Pglobal_State; i: Integer;
begin
  g := L^.l_G;
  g^.currentwhite := WHITEBITS or (1 shl SFIXEDBIT);  { mask to collect all elements }
  sweepwholelist(L, @g^.rootgc);
  for i := 0 to g^.strt.size - 1 do  { free all string lists }
    sweepwholelist(L, @g^.strt.hash[i]);
end;

procedure markmt(g: Pglobal_State);
var i: Integer;
begin
  for i := 0 to NUM_TAGS - 1 do
    if g^.mt[i] <> nil then markobject(g, g^.mt[i]);
end;

{ mark root set }
procedure markroot(L: Plua_State);
var g: Pglobal_State;
begin
  g := L^.l_G;
  g^.gray := nil;
  g^.grayagain := nil;
  g^.weak := nil;
  markobject(g, g^.mainthread);
  { make global table be traversed before main stack }
  markvalue(g, gt(g^.mainthread));
  markvalue(g, registry(L));
  markmt(g);
  g^.gcstate := GCSpropagate;
end;

procedure remarkupvals(g: Pglobal_State);
var uv: PUpVal;
begin
  uv := g^.uvhead.lnext;
  while uv <> @g^.uvhead do
  begin
    if isgray(obj2gco(uv)) then
      markvalue(g, uv^.v);
    uv := uv^.lnext;
  end;
end;

procedure atomic(L: Plua_State);
var g: Pglobal_State; udsize: size_t;
begin
  g := L^.l_G;
  { remark occasional upvalues of (maybe) dead threads }
  remarkupvals(g);
  { traverse objects cautch by write barrier and by 'remarkupvals' }
  propagateall(g);
  { remark weak tables }
  g^.gray := g^.weak;
  g^.weak := nil;
  markobject(g, L);  { mark running thread }
  markmt(g);  { mark basic metatables (again) }
  propagateall(g);
  { remark gray again }
  g^.gray := g^.grayagain;
  g^.grayagain := nil;
  propagateall(g);
  udsize := luaC_separateudata(L, 0);  { separate userdata to be finalized }
  marktmu(g);  { mark `preserved' userdata }
  Inc(udsize, propagateall(g));  { remark, to propagate `preserveness' }
  cleartable(g^.weak);  { remove collected objects from weak tables }
  { flip current white }
  g^.currentwhite := lu_byte(otherwhite(g));
  g^.sweepstrgc := 0;
  g^.sweepgc := @g^.rootgc;
  g^.gcstate := GCSsweepstring;
  g^.estimate := g^.totalbytes - udsize;  { first estimate }
end;

function singlestep(L: Plua_State): l_mem;
var g: Pglobal_State; old: lu_mem;
begin
  g := L^.l_G;
  case g^.gcstate of
    GCSpause:
      begin
        markroot(L);  { start a new collection }
        Result := 0;
      end;
    GCSpropagate:
      begin
        if g^.gray <> nil then
          Result := propagatemark(g)
        else
        begin  { no more `gray' objects }
          atomic(L);  { finish mark phase }
          Result := 0;
        end;
      end;
    GCSsweepstring:
      begin
        old := g^.totalbytes;
        sweepwholelist(L, @g^.strt.hash[g^.sweepstrgc]);
        Inc(g^.sweepstrgc);
        if g^.sweepstrgc >= g^.strt.size then  { nothing more to sweep? }
          g^.gcstate := GCSsweep;  { end sweep-string phase }
        g^.estimate := g^.estimate - (old - g^.totalbytes);
        Result := GCSWEEPCOST;
      end;
    GCSsweep:
      begin
        old := g^.totalbytes;
        g^.sweepgc := sweeplist(L, g^.sweepgc, GCSWEEPMAX);
        if g^.sweepgc^ = nil then
        begin  { nothing more to sweep? }
          checkSizes(L);
          g^.gcstate := GCSfinalize;  { end sweep phase }
        end;
        g^.estimate := g^.estimate - (old - g^.totalbytes);
        Result := GCSWEEPMAX * GCSWEEPCOST;
      end;
    GCSfinalize:
      begin
        if g^.tmudata <> nil then
        begin
          GCTM(L);
          if g^.estimate > GCFINALIZECOST then
            g^.estimate := g^.estimate - GCFINALIZECOST;
          Result := GCFINALIZECOST;
        end
        else
        begin
          g^.gcstate := GCSpause;  { end collection }
          g^.gcdept := 0;
          Result := 0;
        end;
      end;
  else
    Result := 0;
  end;
end;

procedure luaC_step(L: Plua_State);
var g: Pglobal_State; lim: l_mem;
begin
  g := L^.l_G;
  lim := l_mem(Cardinal(Cardinal(GCSTEPSIZE div 100) * Cardinal(g^.gcstepmul)));
  if lim = 0 then
    lim := l_mem((MAX_LUMEM - 1) div 2);  { no limit }
  g^.gcdept := g^.gcdept + (g^.totalbytes - g^.GCthreshold);
  repeat
    lim := lim - singlestep(L);
    if g^.gcstate = GCSpause then
      Break;
  until lim <= 0;
  if g^.gcstate <> GCSpause then
  begin
    if g^.gcdept < GCSTEPSIZE then
      g^.GCthreshold := g^.totalbytes + GCSTEPSIZE  { - lim/g->gcstepmul;}
    else
    begin
      g^.gcdept := g^.gcdept - GCSTEPSIZE;
      g^.GCthreshold := g^.totalbytes;
    end;
  end
  else
    setthreshold(g);
end;

procedure luaC_fullgc(L: Plua_State);
var g: Pglobal_State;
begin
  g := L^.l_G;
  if g^.gcstate <= GCSpropagate then
  begin
    { reset sweep marks to sweep all elements (returning them to white) }
    g^.sweepstrgc := 0;
    g^.sweepgc := @g^.rootgc;
    { reset other collector lists }
    g^.gray := nil;
    g^.grayagain := nil;
    g^.weak := nil;
    g^.gcstate := GCSsweepstring;
  end;
  { finish any pending sweep phase }
  while g^.gcstate <> GCSfinalize do
    singlestep(L);
  markroot(L);
  while g^.gcstate <> GCSpause do
    singlestep(L);
  setthreshold(g);
end;

procedure luaC_barrierf(L: Plua_State; o, v: PGCObject);
var g: Pglobal_State;
begin
  g := L^.l_G;
  { must keep invariant? }
  if g^.gcstate = GCSpropagate then
    reallymarkobject(g, v)  { restore invariant }
  else  { don't mind }
    makewhite(g, o);  { mark as white just to avoid other barriers }
end;

procedure luaC_barrierback(L: Plua_State; t: PTable);
var g: Pglobal_State; o: PGCObject;
begin
  g := L^.l_G;
  o := obj2gco(t);
  black2gray(o);  { make table gray (again) }
  t^.gclist := g^.grayagain;
  g^.grayagain := o;
end;

procedure luaC_link(L: Plua_State; o: PGCObject; tt: lu_byte);
var g: Pglobal_State;
begin
  g := L^.l_G;
  o^.next := g^.rootgc;
  g^.rootgc := o;
  o^.marked := luaC_white(g);
  o^.tt := tt;
end;

procedure luaC_linkupval(L: Plua_State; uv: PUpVal);
var g: Pglobal_State; o: PGCObject;
begin
  g := L^.l_G;
  o := obj2gco(uv);
  o^.next := g^.rootgc;  { link upvalue into `rootgc' list }
  g^.rootgc := o;
  if isgray(o) then
  begin
    if g^.gcstate = GCSpropagate then
    begin
      gray2black(o);  { closed upvalues need barrier }
      luaC_barrier(L, uv, uv^.v);
    end
    else
    begin  { sweep phase: sweep it (turning it into white) }
      makewhite(g, o);
    end;
  end;
end;

end.
