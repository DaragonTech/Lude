{
  Lua 5.1.4 - Pascal port of ltable.c
  Lua tables (hash)
}
unit LuaTable;

{$I lua.inc}

interface

uses
  LuaTypes;

function luaH_getnum(t: PTable; key: Integer): PTValue;
function luaH_setnum(L: Plua_State; t: PTable; key: Integer): PTValue;
function luaH_getstr(t: PTable; key: PTString): PTValue;
function luaH_setstr(L: Plua_State; t: PTable; key: PTString): PTValue;
function luaH_get(t: PTable; key: PTValue): PTValue;
function luaH_set(L: Plua_State; t: PTable; key: PTValue): PTValue;
function luaH_new(L: Plua_State; narray, nhash: Integer): PTable;
procedure luaH_resizearray(L: Plua_State; t: PTable; nasize: Integer);
procedure luaH_free(L: Plua_State; t: PTable);
function luaH_next(L: Plua_State; t: PTable; key: StkId): Integer;
function luaH_getn(t: PTable): Integer;
function dummynode: PNode; inline;

var
  dummynode_: TNode;  { in the interface: used by the inline dummynode }

implementation

uses
  LuaCRT, LuaObject, LuaMem, LuaGC, LuaDebug;

const
  MAXBITS = 26;
  MAXASIZE = 1 shl MAXBITS;

function dummynode: PNode;
begin
  Result := @dummynode_;
end;

function hashpow2(t: PTable; n: Cardinal): PNode; inline;
begin
  Result := gnode(t, lmod(n, sizenode(t)));
end;

function hashmod(t: PTable; n: Cardinal): PNode; inline;
begin
  Result := gnode(t, Integer(n mod Cardinal((sizenode(t) - 1) or 1)));
end;

function hashpointer(t: PTable; p: Pointer): PNode; inline;
begin
  Result := hashmod(t, Cardinal(NativeUInt(p)));
end;

{ hash for lua_Numbers }
function hashnum(t: PTable; n: lua_Number): PNode;
var a: array[0..1] of Cardinal;
begin
  if luai_numeq(n, 0) then  { avoid problems with -0 }
    Exit(gnode(t, 0));
  Move(n, a, SizeOf(a));
  a[0] := a[0] + a[1];
  Result := hashmod(t, a[0]);
end;

{ returns the `main' position of an element in a table (that is, the index
  of its hash value) }
function mainposition(t: PTable; key: PTValue): PNode;
begin
  case key^.tt of
    LUA_TNUMBER: Result := hashnum(t, key^.value.n);
    LUA_TSTRING: Result := hashpow2(t, rawtsvalue(key)^.hash);
    LUA_TBOOLEAN: Result := hashpow2(t, Cardinal(key^.value.b));
    LUA_TLIGHTUSERDATA: Result := hashpointer(t, key^.value.p);
  else
    Result := hashpointer(t, key^.value.gc);
  end;
end;

{ returns the index for `key' if `key' is an appropriate key to live in
  the array part of the table, -1 otherwise. }
function arrayindex(key: PTValue): Integer;
var n: lua_Number; k: Integer;
begin
  if key^.tt = LUA_TNUMBER then
  begin
    n := key^.value.n;
    k := lua_number2int(n);
    if luai_numeq(k, n) then Exit(k);
  end;
  Result := -1;  { `key' did not match some condition }
end;

{ returns the index of a `key' for table traversals. First goes all
  elements in the array part, then elements in the hash part. The
  beginning of a traversal is signalled by -1. }
function findindex(L: Plua_State; t: PTable; key: StkId): Integer;
var i: Integer; n: PNode;
begin
  if ttisnil(key) then Exit(-1);  { first iteration }
  i := arrayindex(key);
  if (0 < i) and (i <= t^.sizearray) then  { is `key' inside array part? }
    Exit(i - 1)  { yes; that's the index (corrected to C) }
  else
  begin
    n := mainposition(t, key);
    repeat  { check whether `key' is somewhere in the chain }
      { key may be dead already, but it is ok to use it in `next' }
      if (luaO_rawequalObj(key2tval(n), key) <> 0) or
         ((gkey(n)^.tt = LUA_TDEADKEY) and iscollectable(key) and
          (gkey(n)^.value.gc = key^.value.gc)) then
      begin
        i := Integer((PAnsiChar(n) - PAnsiChar(gnode(t, 0))) div SizeOf(TNode));  { key index in hash table }
        { hash elements are numbered after array ones }
        Exit(i + t^.sizearray);
      end
      else
        n := n^.i_key.next;
    until n = nil;
    luaG_runerror(L, 'invalid key to ''next''', []);  { key not found }
    Result := 0;  { to avoid warnings }
  end;
end;

function luaH_next(L: Plua_State; t: PTable; key: StkId): Integer;
var i: Integer;
begin
  i := findindex(L, t, key);  { find original element }
  Inc(i);
  while i < t^.sizearray do
  begin  { try first array part }
    if not ttisnil(@t^.arr[i]) then
    begin  { a non-nil value? }
      setnvalue(key, i + 1);
      setobj(L, key + 1, @t^.arr[i]);
      Exit(1);
    end;
    Inc(i);
  end;
  i := i - t^.sizearray;
  while i < sizenode(t) do
  begin  { then hash part }
    if not ttisnil(gval(gnode(t, i))) then
    begin  { a non-nil value? }
      setobj(L, key, key2tval(gnode(t, i)));
      setobj(L, key + 1, gval(gnode(t, i)));
      Exit(1);
    end;
    Inc(i);
  end;
  Result := 0;  { no more elements }
end;

{ ============================================================== Rehash }

function computesizes(nums: PInteger; var narray: Integer): Integer;
var i, twotoi, a, na, n: Integer;
begin
  a := 0;  { number of elements smaller than 2^i }
  na := 0;  { number of elements to go to array part }
  n := 0;  { optimal size for array part }
  i := 0;
  twotoi := 1;
  while twotoi div 2 < narray do
  begin
    if nums[i] > 0 then
    begin
      Inc(a, nums[i]);
      if a > twotoi div 2 then
      begin  { more than half elements present? }
        n := twotoi;  { optimal size (till now) }
        na := a;  { all elements smaller than n will go to array part }
      end;
    end;
    if a = narray then Break;  { all elements already counted }
    Inc(i);
    twotoi := twotoi * 2;
  end;
  narray := n;
  Result := na;
end;

function countint(key: PTValue; nums: PInteger): Integer;
var k: Integer;
begin
  k := arrayindex(key);
  if (0 < k) and (k <= MAXASIZE) then
  begin  { is `key' an appropriate array index? }
    Inc(nums[ceillog2(k)]);  { count as such }
    Result := 1;
  end
  else
    Result := 0;
end;

function numusearray(t: PTable; nums: PInteger): Integer;
var lg, ttlg, ause, i, lc, lim: Integer;
begin
  ause := 0;  { summation of `nums' }
  i := 1;  { count to traverse all array keys }
  lg := 0;
  ttlg := 1;
  while lg <= MAXBITS do
  begin  { for each slice }
    lc := 0;  { counter }
    lim := ttlg;
    if lim > t^.sizearray then
    begin
      lim := t^.sizearray;  { adjust upper limit }
      if i > lim then
        Break;  { no more elements to count }
    end;
    { count elements in range (2^(lg-1), 2^lg] }
    while i <= lim do
    begin
      if not ttisnil(@t^.arr[i - 1]) then Inc(lc);
      Inc(i);
    end;
    Inc(nums[lg], lc);
    Inc(ause, lc);
    Inc(lg);
    ttlg := ttlg * 2;
  end;
  Result := ause;
end;

function numusehash(t: PTable; nums: PInteger; var pnasize: Integer): Integer;
var totaluse, ause, i: Integer; n: PNode;
begin
  totaluse := 0;  { total number of elements }
  ause := 0;  { summation of `nums' }
  i := sizenode(t);
  while i > 0 do
  begin
    Dec(i);
    n := @t^.node[i];
    if not ttisnil(gval(n)) then
    begin
      Inc(ause, countint(key2tval(n), nums));
      Inc(totaluse);
    end;
  end;
  Inc(pnasize, ause);
  Result := totaluse;
end;

procedure setarrayvector(L: Plua_State; t: PTable; size: Integer);
var i: Integer;
begin
  t^.arr := luaM_reallocv(L, t^.arr, t^.sizearray, size, SizeOf(TValue));
  for i := t^.sizearray to size - 1 do
    setnilvalue(@t^.arr[i]);
  t^.sizearray := size;
end;

procedure setnodevector(L: Plua_State; t: PTable; size: Integer);
var lsize, i: Integer; n: PNode;
begin
  if size = 0 then
  begin  { no elements to hash part? }
    t^.node := dummynode;  { use common `dummynode' }
    lsize := 0;
  end
  else
  begin
    lsize := ceillog2(size);
    if lsize > MAXBITS then
      luaG_runerror(L, 'table overflow', []);
    size := twoto(lsize);
    t^.node := luaM_newvector(L, size, SizeOf(TNode));
    for i := 0 to size - 1 do
    begin
      n := gnode(t, i);
      n^.i_key.next := nil;
      setnilvalue(gkey(n));
      setnilvalue(gval(n));
    end;
  end;
  t^.lsizenode := lu_byte(lsize);
  t^.lastfree := gnode(t, size);  { all positions are free }
end;

procedure resize(L: Plua_State; t: PTable; nasize, nhsize: Integer);
var i, oldasize, oldhsize: Integer; nold, old: PNode;
begin
  oldasize := t^.sizearray;
  oldhsize := t^.lsizenode;
  nold := t^.node;  { save old hash ... }
  if nasize > oldasize then  { array part must grow? }
    setarrayvector(L, t, nasize);
  { create new hash part with appropriate size }
  setnodevector(L, t, nhsize);
  if nasize < oldasize then
  begin  { array part must shrink? }
    t^.sizearray := nasize;
    { re-insert vanishing slice }
    for i := nasize to oldasize - 1 do
    begin
      if not ttisnil(@t^.arr[i]) then
        setobj(L, luaH_setnum(L, t, i + 1), @t^.arr[i]);
    end;
    { shrink array }
    t^.arr := luaM_reallocv(L, t^.arr, oldasize, nasize, SizeOf(TValue));
  end;
  { re-insert elements from hash part }
  for i := twoto(oldhsize) - 1 downto 0 do
  begin
    old := nold + i;
    if not ttisnil(gval(old)) then
      setobj(L, luaH_set(L, t, key2tval(old)), gval(old));
  end;
  if nold <> dummynode then
    luaM_freearray(L, nold, twoto(oldhsize), SizeOf(TNode));  { free old array }
end;

procedure luaH_resizearray(L: Plua_State; t: PTable; nasize: Integer);
var nsize: Integer;
begin
  if t^.node = dummynode then nsize := 0 else nsize := sizenode(t);
  resize(L, t, nasize, nsize);
end;

procedure rehash(L: Plua_State; t: PTable; ek: PTValue);
var nasize, na, i, totaluse: Integer; nums: array[0..MAXBITS] of Integer;
begin
  for i := 0 to MAXBITS do nums[i] := 0;  { reset counts }
  nasize := numusearray(t, @nums[0]);  { count keys in array part }
  totaluse := nasize;  { all those keys are integer keys }
  Inc(totaluse, numusehash(t, @nums[0], nasize));  { count keys in hash part }
  { count extra key }
  Inc(nasize, countint(ek, @nums[0]));
  Inc(totaluse);
  { compute new size for array part }
  na := computesizes(@nums[0], nasize);
  { resize the table to new computed sizes }
  resize(L, t, nasize, totaluse - na);
end;

function luaH_new(L: Plua_State; narray, nhash: Integer): PTable;
var t: PTable;
begin
  t := luaM_malloc(L, SizeOf(TTable));
  luaC_link(L, obj2gco(t), LUA_TTABLE);
  t^.metatable := nil;
  t^.flags := lu_byte(not 0);
  { temporary values (kept only if some malloc fails) }
  t^.arr := nil;
  t^.sizearray := 0;
  t^.lsizenode := 0;
  t^.node := dummynode;
  setarrayvector(L, t, narray);
  setnodevector(L, t, nhash);
  Result := t;
end;

procedure luaH_free(L: Plua_State; t: PTable);
begin
  if t^.node <> dummynode then
    luaM_freearray(L, t^.node, sizenode(t), SizeOf(TNode));
  luaM_freearray(L, t^.arr, t^.sizearray, SizeOf(TValue));
  luaM_freemem(L, t, SizeOf(TTable));
end;

function getfreepos(t: PTable): PNode;
begin
  while PAnsiChar(t^.lastfree) > PAnsiChar(t^.node) do
  begin
    Dec(t^.lastfree);
    if ttisnil(gkey(t^.lastfree)) then
      Exit(t^.lastfree);
  end;
  Result := nil;  { could not find a free place }
end;

{ inserts a new key into a hash table; first, check whether key's main
  position is free. If not, check whether colliding node is in its main
  position or not: if it is not, move colliding node to an empty place and
  put new key in its main position; otherwise (colliding node is in its main
  position), new key goes to an empty position. }
function newkey(L: Plua_State; t: PTable; key: PTValue): PTValue;
var mp, othern, n: PNode;
begin
  mp := mainposition(t, key);
  if (not ttisnil(gval(mp))) or (mp = dummynode) then
  begin
    n := getfreepos(t);  { get a free place }
    if n = nil then
    begin  { cannot find a free place? }
      rehash(L, t, key);  { grow table }
      Exit(luaH_set(L, t, key));  { re-insert key into grown table }
    end;
    othern := mainposition(t, key2tval(mp));
    if othern <> mp then
    begin  { is colliding node out of its main position? }
      { yes; move colliding node into free position }
      while othern^.i_key.next <> mp do othern := othern^.i_key.next;  { find previous }
      othern^.i_key.next := n;  { redo the chain with `n' in place of `mp' }
      n^ := mp^;  { copy colliding node into free pos. (mp->next also goes) }
      mp^.i_key.next := nil;  { now `mp' is free }
      setnilvalue(gval(mp));
    end
    else
    begin  { colliding node is in its own main position }
      { new node will go into free position }
      n^.i_key.next := mp^.i_key.next;  { chain new position }
      mp^.i_key.next := n;
      mp := n;
    end;
  end;
  mp^.i_key.value := key^.value;
  mp^.i_key.tt := key^.tt;
  luaC_barriert(L, t, key);
  Result := gval(mp);
end;

{ search function for integers }
function luaH_getnum(t: PTable; key: Integer): PTValue;
var nk: lua_Number; n: PNode;
begin
  { (1 <= key && key <= t->sizearray) }
  if Cardinal(key - 1) < Cardinal(t^.sizearray) then
    Exit(@t^.arr[key - 1])
  else
  begin
    nk := key;
    n := hashnum(t, nk);
    repeat  { check whether `key' is somewhere in the chain }
      if (n^.i_key.tt = LUA_TNUMBER) and luai_numeq(n^.i_key.value.n, nk) then
        Exit(gval(n))  { that's it }
      else
        n := n^.i_key.next;
    until n = nil;
    Result := luaO_nilobject;
  end;
end;

{ search function for strings }
function luaH_getstr(t: PTable; key: PTString): PTValue;
var n: PNode;
begin
  n := hashpow2(t, key^.hash);
  repeat  { check whether `key' is somewhere in the chain }
    if (n^.i_key.tt = LUA_TSTRING) and (PTString(n^.i_key.value.gc) = key) then
      Exit(gval(n))  { that's it }
    else
      n := n^.i_key.next;
  until n = nil;
  Result := luaO_nilobject;
end;

{ main search function }
function luaH_get(t: PTable; key: PTValue): PTValue;
var k: Integer; n: PNode; num: lua_Number;
begin
  case key^.tt of
    LUA_TNIL: Exit(luaO_nilobject);
    LUA_TSTRING: Exit(luaH_getstr(t, rawtsvalue(key)));
    LUA_TNUMBER:
      begin
        num := key^.value.n;
        k := lua_number2int(num);
        if luai_numeq(k, num) then  { index is int? }
          Exit(luaH_getnum(t, k));  { use specialized version }
        { else go through }
      end;
  end;
  n := mainposition(t, key);
  repeat  { check whether `key' is somewhere in the chain }
    if luaO_rawequalObj(key2tval(n), key) <> 0 then
      Exit(gval(n))  { that's it }
    else
      n := n^.i_key.next;
  until n = nil;
  Result := luaO_nilobject;
end;

function luaH_set(L: Plua_State; t: PTable; key: PTValue): PTValue;
var p: PTValue;
begin
  p := luaH_get(t, key);
  t^.flags := 0;
  if p <> luaO_nilobject then
    Result := p
  else
  begin
    if ttisnil(key) then luaG_runerror(L, 'table index is nil', [])
    else if (key^.tt = LUA_TNUMBER) and c_isnan(key^.value.n) then
      luaG_runerror(L, 'table index is NaN', []);
    Result := newkey(L, t, key);
  end;
end;

function luaH_setnum(L: Plua_State; t: PTable; key: Integer): PTValue;
var p: PTValue; k: TValue;
begin
  p := luaH_getnum(t, key);
  if p <> luaO_nilobject then
    Result := p
  else
  begin
    setnvalue(@k, key);
    Result := newkey(L, t, @k);
  end;
end;

function luaH_setstr(L: Plua_State; t: PTable; key: PTString): PTValue;
var p: PTValue; k: TValue;
begin
  p := luaH_getstr(t, key);
  if p <> luaO_nilobject then
    Result := p
  else
  begin
    setsvalue(L, @k, key);
    Result := newkey(L, t, @k);
  end;
end;

function unbound_search(t: PTable; j: Cardinal): Integer;
var i, m: Cardinal;
begin
  i := j;  { i is zero or a present index }
  Inc(j);
  { find `i' and `j' such that i is present and j is not }
  while not ttisnil(luaH_getnum(t, Integer(j))) do
  begin
    i := j;
    j := j * 2;
    if j > Cardinal(MAX_INT) then
    begin  { overflow? }
      { table was built with bad purposes: resort to linear search }
      i := 1;
      while not ttisnil(luaH_getnum(t, Integer(i))) do Inc(i);
      Exit(Integer(i - 1));
    end;
  end;
  { now do a binary search between them }
  while j - i > 1 do
  begin
    m := (i + j) div 2;
    if ttisnil(luaH_getnum(t, Integer(m))) then j := m
    else i := m;
  end;
  Result := Integer(i);
end;

{ Try to find a boundary in table `t'. A `boundary' is an integer index
  such that t[i] is non-nil and t[i+1] is nil (and 0 if t[1] is nil). }
function luaH_getn(t: PTable): Integer;
var j, i, m: Cardinal;
begin
  j := Cardinal(t^.sizearray);
  if (j > 0) and ttisnil(@t^.arr[j - 1]) then
  begin
    { there is a boundary in the array part: (binary) search for it }
    i := 0;
    while j - i > 1 do
    begin
      m := (i + j) div 2;
      if ttisnil(@t^.arr[m - 1]) then j := m
      else i := m;
    end;
    Result := Integer(i);
  end
  { else must find a boundary in hash part }
  else if t^.node = dummynode then  { hash part is empty? }
    Result := Integer(j)  { that is easy... }
  else
    Result := unbound_search(t, j);
end;

initialization
  FillChar(dummynode_, SizeOf(dummynode_), 0);
end.
