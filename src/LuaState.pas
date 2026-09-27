{
  Lua 5.1.4 - Pascal port of lstate.c
  Global State
}
unit LuaState;

{$I lua.inc}

interface

uses
  LuaTypes;

function luaE_newthread(L: Plua_State): Plua_State;
procedure luaE_freethread(L, L1: Plua_State);
function lua_newstate(f: lua_Alloc; ud: Pointer): Plua_State; cdecl;
procedure lua_close(L: Plua_State); cdecl;

implementation

uses
  LuaMem, LuaGC, LuaFunc, LuaTable, LuaString, LuaTM, LuaLex, LuaDo, LuaZIO;

type
  PLG = ^TLG;
  TLG = record
    l: lua_State;
    g: global_State;
  end;

procedure stack_init(L1, L: Plua_State);
begin
  { initialize CallInfo array }
  L1^.base_ci := luaM_newvector(L, BASIC_CI_SIZE, SizeOf(TCallInfo));
  L1^.ci := L1^.base_ci;
  L1^.size_ci := BASIC_CI_SIZE;
  L1^.end_ci := L1^.base_ci + L1^.size_ci - 1;
  { initialize stack array }
  L1^.stack := luaM_newvector(L, BASIC_STACK_SIZE + EXTRA_STACK, SizeOf(TValue));
  L1^.stacksize := BASIC_STACK_SIZE + EXTRA_STACK;
  L1^.top := L1^.stack;
  L1^.stack_last := L1^.stack + (L1^.stacksize - EXTRA_STACK) - 1;
  { initialize first ci }
  L1^.ci^.func := L1^.top;
  setnilvalue(L1^.top);  { `function' entry for this `ci' }
  Inc(L1^.top);
  L1^.base := L1^.top;
  L1^.ci^.base := L1^.top;
  L1^.ci^.top := L1^.top + LUA_MINSTACK;
end;

procedure freestack(L, L1: Plua_State);
begin
  luaM_freearray(L, L1^.base_ci, L1^.size_ci, SizeOf(TCallInfo));
  luaM_freearray(L, L1^.stack, L1^.stacksize, SizeOf(TValue));
end;

{ open parts that may cause memory-allocation errors }
procedure f_luaopen(L: Plua_State; ud: Pointer);
var g: Pglobal_State;
begin
  g := L^.l_G;
  stack_init(L, L);  { init stack }
  sethvalue(L, gt(L), luaH_new(L, 0, 2));  { table of globals }
  sethvalue(L, registry(L), luaH_new(L, 0, 2));  { registry }
  luaS_resize(L, MINSTRTABSIZE);  { initial size of string table }
  luaT_init(L);
  luaX_init(L);
  luaS_fix(luaS_newliteral(L, MEMERRMSG));
  g^.GCthreshold := 4 * g^.totalbytes;
end;

procedure preinit_state(L: Plua_State; g: Pglobal_State);
begin
  L^.l_G := g;
  L^.stack := nil;
  L^.stacksize := 0;
  L^.errorJmp := nil;
  L^.hook := nil;
  L^.hookmask := 0;
  L^.basehookcount := 0;
  L^.allowhook := 1;
  L^.hookcount := L^.basehookcount;
  L^.openupval := nil;
  L^.size_ci := 0;
  L^.nCcalls := 0;
  L^.baseCcalls := 0;
  L^.status := 0;
  L^.base_ci := nil;
  L^.ci := nil;
  L^.savedpc := nil;
  L^.errfunc := 0;
  setnilvalue(gt(L));
end;

procedure close_state(L: Plua_State);
var g: Pglobal_State;
begin
  g := L^.l_G;
  luaF_close(L, L^.stack);  { close all upvalues for this thread }
  luaC_freeall(L);  { collect all objects }
  luaM_freearray(L, g^.strt.hash, g^.strt.size, SizeOf(PTString));
  luaZ_freebuffer(L, @g^.buff);
  freestack(L, L);
  g^.frealloc(g^.ud, L, SizeOf(TLG), 0);
end;

function luaE_newthread(L: Plua_State): Plua_State;
var L1: Plua_State;
begin
  L1 := luaM_malloc(L, SizeOf(lua_State));
  luaC_link(L, obj2gco(L1), LUA_TTHREAD);
  preinit_state(L1, L^.l_G);
  stack_init(L1, L);  { init stack }
  setobj(L, gt(L1), gt(L));  { share table of globals }
  L1^.hookmask := L^.hookmask;
  L1^.basehookcount := L^.basehookcount;
  L1^.hook := L^.hook;
  L1^.hookcount := L1^.basehookcount;
  Result := L1;
end;

procedure luaE_freethread(L, L1: Plua_State);
begin
  luaF_close(L1, L1^.stack);  { close all upvalues for this thread }
  freestack(L, L1);
  luaM_freemem(L, L1, SizeOf(lua_State));
end;

function lua_newstate(f: lua_Alloc; ud: Pointer): Plua_State; cdecl;
var i: Integer; L: Plua_State; g: Pglobal_State; l_: Pointer;
begin
  l_ := f(ud, nil, 0, SizeOf(TLG));
  if l_ = nil then Exit(nil);
  L := l_;
  g := @PLG(L)^.g;
  L^.next := nil;
  L^.tt := LUA_TTHREAD;
  g^.currentwhite := (1 shl WHITE0BIT) or (1 shl FIXEDBIT);
  L^.marked := luaC_white(g);
  L^.marked := L^.marked or (1 shl FIXEDBIT) or (1 shl SFIXEDBIT);
  preinit_state(L, g);
  g^.frealloc := f;
  g^.ud := ud;
  g^.mainthread := L;
  g^.uvhead.prev := @g^.uvhead;
  g^.uvhead.lnext := @g^.uvhead;
  g^.GCthreshold := 0;  { mark it as unfinished state }
  g^.strt.size := 0;
  g^.strt.nuse := 0;
  g^.strt.hash := nil;
  setnilvalue(registry(L));
  luaZ_initbuffer(@g^.buff);
  g^.panic := nil;
  g^.gcstate := GCSpause;
  g^.rootgc := obj2gco(L);
  g^.sweepstrgc := 0;
  g^.sweepgc := @g^.rootgc;
  g^.gray := nil;
  g^.grayagain := nil;
  g^.weak := nil;
  g^.tmudata := nil;
  g^.totalbytes := SizeOf(TLG);
  g^.gcpause := LUAI_GCPAUSE;
  g^.gcstepmul := LUAI_GCMUL;
  g^.gcdept := 0;
  for i := 0 to NUM_TAGS - 1 do g^.mt[i] := nil;
  if luaD_rawrunprotected(L, f_luaopen, nil) <> 0 then
  begin
    { memory allocation error: free partial state }
    close_state(L);
    L := nil;
  end;
  Result := L;
end;

procedure callallgcTM(L: Plua_State; ud: Pointer);
begin
  luaC_callGCTM(L);  { call GC metamethods for all udata }
end;

procedure lua_close(L: Plua_State); cdecl;
begin
  L := L^.l_G^.mainthread;  { only the main thread can be closed }
  luaF_close(L, L^.stack);  { close all upvalues for this thread }
  luaC_separateudata(L, 1);  { separate udata that have GC metamethods }
  L^.errfunc := 0;  { no error function during GC metamethods }
  repeat  { repeat until no more errors }
    L^.ci := L^.base_ci;
    L^.base := L^.ci^.base;
    L^.top := L^.ci^.base;
    L^.nCcalls := 0;
    L^.baseCcalls := 0;
  until luaD_rawrunprotected(L, callallgcTM, nil) = 0;
  close_state(L);
end;

end.
