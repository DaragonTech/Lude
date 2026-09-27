{
  Lua 5.1.4 - Pascal port of lparser.c
  Lua Parser
}
unit LuaParser;

{$I lua.inc}

interface

uses
  LuaTypes;

function luaY_parser(L: Plua_State; z: PZIO; buff: PMbuffer; name: PAnsiChar): PProto;

implementation

uses
  LuaCRT, LuaObject, LuaMem, LuaString, LuaFunc, LuaTable, LuaGC, LuaDo,
  LuaLex, LuaCode;

type
  PConsControl = ^TConsControl;
  TConsControl = record
    v: Texpdesc;  { last list item read }
    t: Pexpdesc;  { table descriptor }
    nh: Integer;  { total number of `record' elements }
    na: Integer;  { total number of array elements }
    tostore: Integer;  { number of array elements pending to be stored }
  end;

  PLHS_assign = ^TLHS_assign;
  TLHS_assign = record
    prev: PLHS_assign;
    v: Texpdesc;  { variable (global, local, upvalue, or indexed) }
  end;

const
  UNARY_PRIORITY = 8;  { priority for unary operators }

  priority_left: array[0..14] of lu_byte = (6, 6, 7, 7, 7, 10, 5, 3, 3, 3, 3, 3, 3, 2, 1);
  priority_right: array[0..14] of lu_byte = (6, 6, 7, 7, 7, 9, 4, 3, 3, 3, 3, 3, 3, 2, 1);

procedure chunk(ls: PLexState); forward;
procedure expr(ls: PLexState; v: Pexpdesc); forward;

function hasmultret(k: expkind): Boolean; inline;
begin
  Result := (k = VCALL) or (k = VVARARG);
end;

function getlocvar(fs: PFuncState; i: Integer): PLocVar; inline;
begin
  Result := @fs^.f^.locvars[fs^.actvar[i]];
end;

procedure anchor_token(ls: PLexState);
var ts: PTString;
begin
  if (ls^.t.token = TK_NAME) or (ls^.t.token = TK_STRING) then
  begin
    ts := ls^.t.seminfo.ts;
    luaX_newstring(ls, getstr(ts), ts^.len);
  end;
end;

procedure error_expected(ls: PLexState; token: Integer);
begin
  luaX_syntaxerror(ls,
    luaO_pushfstring(ls^.L, '''%s'' expected', [luaX_token2str(ls, token)]));
end;

procedure errorlimit(fs: PFuncState; limit: Integer; what: PAnsiChar);
var msg: PAnsiChar;
begin
  if fs^.f^.linedefined = 0 then
    msg := luaO_pushfstring(fs^.L, 'main function has more than %d %s', [limit, what])
  else
    msg := luaO_pushfstring(fs^.L, 'function at line %d has more than %d %s',
                            [fs^.f^.linedefined, limit, what]);
  luaX_lexerror(fs^.ls, msg, 0);
end;

procedure luaY_checklimit(fs: PFuncState; v, l: Integer; m: PAnsiChar); inline;
begin
  if v > l then errorlimit(fs, l, m);
end;

function testnext(ls: PLexState; c: Integer): Boolean;
begin
  if ls^.t.token = c then
  begin
    luaX_next(ls);
    Result := True;
  end
  else
    Result := False;
end;

procedure check(ls: PLexState; c: Integer);
begin
  if ls^.t.token <> c then
    error_expected(ls, c);
end;

procedure checknext(ls: PLexState; c: Integer);
begin
  check(ls, c);
  luaX_next(ls);
end;

procedure check_condition(ls: PLexState; c: Boolean; msg: PAnsiChar); inline;
begin
  if not c then luaX_syntaxerror(ls, msg);
end;

procedure check_match(ls: PLexState; what, who, where: Integer);
begin
  if not testnext(ls, what) then
  begin
    if where = ls^.linenumber then
      error_expected(ls, what)
    else
      luaX_syntaxerror(ls, luaO_pushfstring(ls^.L,
        '''%s'' expected (to close ''%s'' at line %d)',
        [luaX_token2str(ls, what), luaX_token2str(ls, who), where]));
  end;
end;

function str_checkname(ls: PLexState): PTString;
var ts: PTString;
begin
  check(ls, TK_NAME);
  ts := ls^.t.seminfo.ts;
  luaX_next(ls);
  Result := ts;
end;

procedure init_exp(e: Pexpdesc; k: expkind; i: Integer);
begin
  e^.f := NO_JUMP;
  e^.t := NO_JUMP;
  e^.k := k;
  e^.info := i;
end;

procedure codestring(ls: PLexState; e: Pexpdesc; s: PTString);
begin
  init_exp(e, VK, luaK_stringK(ls^.fs, s));
end;

procedure checkname(ls: PLexState; e: Pexpdesc);
begin
  codestring(ls, e, str_checkname(ls));
end;

function registerlocalvar(ls: PLexState; varname: PTString): Integer;
var fs: PFuncState; f: PProto; oldsize: Integer; nl: Integer;
begin
  fs := ls^.fs;
  f := fs^.f;
  oldsize := f^.sizelocvars;
  nl := fs^.nlocvars;
  if nl + 1 > f^.sizelocvars then
    f^.locvars := luaM_growaux_(ls^.L, f^.locvars, f^.sizelocvars, SizeOf(TLocVar),
                                32767, 'too many local variables');
  while oldsize < f^.sizelocvars do
  begin
    f^.locvars[oldsize].varname := nil;
    Inc(oldsize);
  end;
  f^.locvars[fs^.nlocvars].varname := varname;
  luaC_objbarrier(ls^.L, f, varname);
  Result := fs^.nlocvars;
  Inc(fs^.nlocvars);
end;

procedure new_localvar(ls: PLexState; name: PTString; n: Integer);
var fs: PFuncState;
begin
  fs := ls^.fs;
  luaY_checklimit(fs, fs^.nactvar + n + 1, LUAI_MAXVARS, 'local variables');
  fs^.actvar[fs^.nactvar + n] := Word(registerlocalvar(ls, name));
end;

procedure new_localvarliteral(ls: PLexState; const v: AnsiString; n: Integer);
begin
  new_localvar(ls, luaX_newstring(ls, PAnsiChar(v), Length(v)), n);
end;

procedure adjustlocalvars(ls: PLexState; nvars: Integer);
var fs: PFuncState;
begin
  fs := ls^.fs;
  fs^.nactvar := lu_byte(fs^.nactvar + nvars);
  while nvars > 0 do
  begin
    getlocvar(fs, fs^.nactvar - nvars)^.startpc := fs^.pc;
    Dec(nvars);
  end;
end;

procedure removevars(ls: PLexState; tolevel: Integer);
var fs: PFuncState;
begin
  fs := ls^.fs;
  while fs^.nactvar > tolevel do
  begin
    Dec(fs^.nactvar);
    getlocvar(fs, fs^.nactvar)^.endpc := fs^.pc;
  end;
end;

function indexupvalue(fs: PFuncState; name: PTString; v: Pexpdesc): Integer;
var i: Integer; f: PProto; oldsize, nups: Integer;
begin
  f := fs^.f;
  oldsize := f^.sizeupvalues;
  for i := 0 to f^.nups - 1 do
  begin
    if (fs^.upvalues[i].k = v^.k) and (fs^.upvalues[i].info = v^.info) then
      Exit(i);
  end;
  { new one }
  luaY_checklimit(fs, f^.nups + 1, LUAI_MAXUPVALUES, 'upvalues');
  nups := f^.nups;
  if nups + 1 > f^.sizeupvalues then
    f^.upvalues := luaM_growaux_(fs^.L, f^.upvalues, f^.sizeupvalues, SizeOf(PTString), MAX_INT, '');
  while oldsize < f^.sizeupvalues do
  begin
    f^.upvalues[oldsize] := nil;
    Inc(oldsize);
  end;
  f^.upvalues[f^.nups] := name;
  luaC_objbarrier(fs^.L, f, name);
  fs^.upvalues[f^.nups].k := lu_byte(v^.k);
  fs^.upvalues[f^.nups].info := lu_byte(v^.info);
  Result := f^.nups;
  Inc(f^.nups);
end;

function searchvar(fs: PFuncState; n: PTString): Integer;
var i: Integer;
begin
  for i := fs^.nactvar - 1 downto 0 do
  begin
    if n = getlocvar(fs, i)^.varname then
      Exit(i);
  end;
  Result := -1;  { not found }
end;

procedure markupval(fs: PFuncState; level: Integer);
var bl: PBlockCnt;
begin
  bl := fs^.bl;
  while (bl <> nil) and (bl^.nactvar > level) do bl := bl^.previous;
  if bl <> nil then bl^.upval := 1;
end;

function singlevaraux(fs: PFuncState; n: PTString; var_: Pexpdesc; base: Integer): Integer;
var v: Integer;
begin
  if fs = nil then
  begin  { no more levels? }
    init_exp(var_, VGLOBAL, NO_REG);  { default is global variable }
    Result := VGLOBAL;
  end
  else
  begin
    v := searchvar(fs, n);  { look up at current level }
    if v >= 0 then
    begin
      init_exp(var_, VLOCAL, v);
      if base = 0 then
        markupval(fs, v);  { local will be used as an upval }
      Result := VLOCAL;
    end
    else
    begin  { not found at current level; try upper one }
      if singlevaraux(fs^.prev, n, var_, 0) = VGLOBAL then
        Exit(VGLOBAL);
      var_^.info := indexupvalue(fs, n, var_);  { else was LOCAL or UPVAL }
      var_^.k := VUPVAL;  { upvalue in this level }
      Result := VUPVAL;
    end;
  end;
end;

procedure singlevar(ls: PLexState; var_: Pexpdesc);
var varname: PTString; fs: PFuncState;
begin
  varname := str_checkname(ls);
  fs := ls^.fs;
  if singlevaraux(fs, varname, var_, 1) = VGLOBAL then
    var_^.info := luaK_stringK(fs, varname);  { info points to global name }
end;

procedure adjust_assign(ls: PLexState; nvars, nexps: Integer; e: Pexpdesc);
var fs: PFuncState; extra, reg: Integer;
begin
  fs := ls^.fs;
  extra := nvars - nexps;
  if hasmultret(e^.k) then
  begin
    Inc(extra);  { includes call itself }
    if extra < 0 then extra := 0;
    luaK_setreturns(fs, e, extra);  { last exp. provides the difference }
    if extra > 1 then luaK_reserveregs(fs, extra - 1);
  end
  else
  begin
    if e^.k <> VVOID then  { close last expression }
      luaK_exp2nextreg(fs, e);
    if extra > 0 then
    begin
      reg := fs^.freereg;
      luaK_reserveregs(fs, extra);
      luaK_nil(fs, reg, extra);
    end;
  end;
end;

procedure enterlevel(ls: PLexState);
begin
  Inc(ls^.L^.nCcalls);
  if ls^.L^.nCcalls > LUAI_MAXCCALLS then
    luaX_lexerror(ls, 'chunk has too many syntax levels', 0);
end;

procedure leavelevel(ls: PLexState); inline;
begin
  Dec(ls^.L^.nCcalls);
end;

procedure enterblock(fs: PFuncState; bl: PBlockCnt; isbreakable: lu_byte);
begin
  bl^.breaklist := NO_JUMP;
  bl^.isbreakable := isbreakable;
  bl^.nactvar := fs^.nactvar;
  bl^.upval := 0;
  bl^.previous := fs^.bl;
  fs^.bl := bl;
end;

procedure leaveblock(fs: PFuncState);
var bl: PBlockCnt;
begin
  bl := fs^.bl;
  fs^.bl := bl^.previous;
  removevars(fs^.ls, bl^.nactvar);
  if bl^.upval <> 0 then
    luaK_codeABC(fs, OP_CLOSE, bl^.nactvar, 0, 0);
  fs^.freereg := fs^.nactvar;  { free registers }
  luaK_patchtohere(fs, bl^.breaklist);
end;

procedure pushclosure(ls: PLexState; func: PFuncState; v: Pexpdesc);
var fs: PFuncState; f: PProto; oldsize, i: Integer; o: OpCode;
begin
  fs := ls^.fs;
  f := fs^.f;
  oldsize := f^.sizep;
  if fs^.np + 1 > f^.sizep then
    f^.p := luaM_growaux_(ls^.L, f^.p, f^.sizep, SizeOf(PProto), MAXARG_Bx, 'constant table overflow');
  while oldsize < f^.sizep do
  begin
    f^.p[oldsize] := nil;
    Inc(oldsize);
  end;
  f^.p[fs^.np] := func^.f;
  Inc(fs^.np);
  luaC_objbarrier(ls^.L, f, func^.f);
  init_exp(v, VRELOCABLE, luaK_codeABx(fs, OP_CLOSURE, 0, fs^.np - 1));
  for i := 0 to func^.f^.nups - 1 do
  begin
    if func^.upvalues[i].k = VLOCAL then o := OP_MOVE else o := OP_GETUPVAL;
    luaK_codeABC(fs, o, 0, func^.upvalues[i].info, 0);
  end;
end;

procedure open_func(ls: PLexState; fs: PFuncState);
var L: Plua_State; f: PProto;
begin
  L := ls^.L;
  f := luaF_newproto(L);
  fs^.f := f;
  fs^.prev := ls^.fs;  { linked list of funcstates }
  fs^.ls := ls;
  fs^.L := L;
  ls^.fs := fs;
  fs^.pc := 0;
  fs^.lasttarget := -1;
  fs^.jpc := NO_JUMP;
  fs^.freereg := 0;
  fs^.nk := 0;
  fs^.np := 0;
  fs^.nlocvars := 0;
  fs^.nactvar := 0;
  fs^.bl := nil;
  f^.source := ls^.source;
  f^.maxstacksize := 2;  { registers 0/1 are always valid }
  fs^.h := luaH_new(L, 0, 0);
  { anchor table of constants and prototype (to avoid being collected) }
  sethvalue(L, L^.top, fs^.h);
  incr_top(L);
  setptvalue(L, L^.top, f);
  incr_top(L);
end;

procedure close_func(ls: PLexState);
var L: Plua_State; fs: PFuncState; f: PProto;
begin
  L := ls^.L;
  fs := ls^.fs;
  f := fs^.f;
  removevars(ls, 0);
  luaK_ret(fs, 0, 0);  { final return }
  f^.code := luaM_reallocv(L, f^.code, f^.sizecode, fs^.pc, SizeOf(Instruction));
  f^.sizecode := fs^.pc;
  f^.lineinfo := luaM_reallocv(L, f^.lineinfo, f^.sizelineinfo, fs^.pc, SizeOf(Integer));
  f^.sizelineinfo := fs^.pc;
  f^.k := luaM_reallocv(L, f^.k, f^.sizek, fs^.nk, SizeOf(TValue));
  f^.sizek := fs^.nk;
  f^.p := luaM_reallocv(L, f^.p, f^.sizep, fs^.np, SizeOf(PProto));
  f^.sizep := fs^.np;
  f^.locvars := luaM_reallocv(L, f^.locvars, f^.sizelocvars, fs^.nlocvars, SizeOf(TLocVar));
  f^.sizelocvars := fs^.nlocvars;
  f^.upvalues := luaM_reallocv(L, f^.upvalues, f^.sizeupvalues, f^.nups, SizeOf(PTString));
  f^.sizeupvalues := f^.nups;
  ls^.fs := fs^.prev;
  Dec(L^.top, 2);  { remove table and prototype from the stack }
  { last token read was anchored in defunct function; must reanchor it }
  if fs <> nil then anchor_token(ls);
end;

function luaY_parser(L: Plua_State; z: PZIO; buff: PMbuffer; name: PAnsiChar): PProto;
var lexstate: TLexState; funcstate: TFuncState;
begin
  FillChar(lexstate, SizeOf(lexstate), 0);
  lexstate.buff := buff;
  luaX_setinput(L, @lexstate, z, luaS_new(L, name));
  open_func(@lexstate, @funcstate);
  funcstate.f^.is_vararg := VARARG_ISVARARG;  { main func. is always vararg }
  luaX_next(@lexstate);  { read first token }
  chunk(@lexstate);
  check(@lexstate, TK_EOS);
  close_func(@lexstate);
  Result := funcstate.f;
end;

{ ============================================================
  GRAMMAR RULES
  ============================================================ }

procedure field(ls: PLexState; v: Pexpdesc);
var fs: PFuncState; key: Texpdesc;
begin
  { field -> ['.' | ':'] NAME }
  fs := ls^.fs;
  luaK_exp2anyreg(fs, v);
  luaX_next(ls);  { skip the dot or colon }
  checkname(ls, @key);
  luaK_indexed(fs, v, @key);
end;

procedure yindex(ls: PLexState; v: Pexpdesc);
begin
  { index -> '[' expr ']' }
  luaX_next(ls);  { skip the '[' }
  expr(ls, v);
  luaK_exp2val(ls^.fs, v);
  checknext(ls, Ord(']'));
end;

{ Rules for Constructors }

procedure recfield(ls: PLexState; cc: PConsControl);
var fs: PFuncState; reg, rkkey: Integer; key, val: Texpdesc;
begin
  { recfield -> (NAME | `['exp1`]') = exp1 }
  fs := ls^.fs;
  reg := ls^.fs^.freereg;
  if ls^.t.token = TK_NAME then
  begin
    luaY_checklimit(fs, cc^.nh, MAX_INT, 'items in a constructor');
    checkname(ls, @key);
  end
  else  { ls->t.token == '[' }
    yindex(ls, @key);
  Inc(cc^.nh);
  checknext(ls, Ord('='));
  rkkey := luaK_exp2RK(fs, @key);
  expr(ls, @val);
  luaK_codeABC(fs, OP_SETTABLE, cc^.t^.info, rkkey, luaK_exp2RK(fs, @val));
  fs^.freereg := reg;  { free registers }
end;

procedure closelistfield(fs: PFuncState; cc: PConsControl);
begin
  if cc^.v.k = VVOID then Exit;  { there is no list item }
  luaK_exp2nextreg(fs, @cc^.v);
  cc^.v.k := VVOID;
  if cc^.tostore = LFIELDS_PER_FLUSH then
  begin
    luaK_setlist(fs, cc^.t^.info, cc^.na, cc^.tostore);  { flush }
    cc^.tostore := 0;  { no more items pending }
  end;
end;

procedure lastlistfield(fs: PFuncState; cc: PConsControl);
begin
  if cc^.tostore = 0 then Exit;
  if hasmultret(cc^.v.k) then
  begin
    luaK_setmultret(fs, @cc^.v);
    luaK_setlist(fs, cc^.t^.info, cc^.na, LUA_MULTRET);
    Dec(cc^.na);  { do not count last expression (unknown number of elements) }
  end
  else
  begin
    if cc^.v.k <> VVOID then
      luaK_exp2nextreg(fs, @cc^.v);
    luaK_setlist(fs, cc^.t^.info, cc^.na, cc^.tostore);
  end;
end;

procedure listfield(ls: PLexState; cc: PConsControl);
begin
  expr(ls, @cc^.v);
  luaY_checklimit(ls^.fs, cc^.na, MAX_INT, 'items in a constructor');
  Inc(cc^.na);
  Inc(cc^.tostore);
end;

procedure constructor_(ls: PLexState; t: Pexpdesc);
var fs: PFuncState; line, pc: Integer; cc: TConsControl;
begin
  { constructor -> ?? }
  fs := ls^.fs;
  line := ls^.linenumber;
  pc := luaK_codeABC(fs, OP_NEWTABLE, 0, 0, 0);
  cc.na := 0;
  cc.nh := 0;
  cc.tostore := 0;
  cc.t := t;
  init_exp(t, VRELOCABLE, pc);
  init_exp(@cc.v, VVOID, 0);  { no value (yet) }
  luaK_exp2nextreg(ls^.fs, t);  { fix it at stack top (for gc) }
  checknext(ls, Ord('{'));
  repeat
    if ls^.t.token = Ord('}') then Break;
    closelistfield(fs, @cc);
    case ls^.t.token of
      TK_NAME:
        begin  { may be listfields or recfields }
          luaX_lookahead(ls);
          if ls^.lookahead.token <> Ord('=') then  { expression? }
            listfield(ls, @cc)
          else
            recfield(ls, @cc);
        end;
      Ord('['):
        recfield(ls, @cc);  { constructor_item -> recfield }
    else
      listfield(ls, @cc);  { constructor_part -> listfield }
    end;
  until not (testnext(ls, Ord(',')) or testnext(ls, Ord(';')));
  check_match(ls, Ord('}'), Ord('{'), line);
  lastlistfield(fs, @cc);
  SETARG_B(fs^.f^.code[pc], luaO_int2fb(cc.na));  { set initial array size }
  SETARG_C(fs^.f^.code[pc], luaO_int2fb(cc.nh));  { set initial table size }
end;

procedure parlist(ls: PLexState);
var fs: PFuncState; f: PProto; nparams: Integer;
begin
  // parlist -> [ param { `,' param } ] 
  fs := ls^.fs;
  f := fs^.f;
  nparams := 0;
  f^.is_vararg := 0;
  if ls^.t.token <> Ord(')') then
  begin  { is `parlist' not empty? }
    repeat
      case ls^.t.token of
        TK_NAME:
          begin  { param -> NAME }
            new_localvar(ls, str_checkname(ls), nparams);
            Inc(nparams);
          end;
        TK_DOTS:
          begin  { param -> `...' }
            luaX_next(ls);
            { use `arg' as default name }
            new_localvarliteral(ls, 'arg', nparams);
            Inc(nparams);
            f^.is_vararg := VARARG_HASARG or VARARG_NEEDSARG;
            f^.is_vararg := f^.is_vararg or VARARG_ISVARARG;
          end;
      else
        luaX_syntaxerror(ls, '<name> or ''...'' expected');
      end;
    until not ((f^.is_vararg = 0) and testnext(ls, Ord(',')));
  end;
  adjustlocalvars(ls, nparams);
  f^.numparams := lu_byte(fs^.nactvar - (f^.is_vararg and VARARG_HASARG));
  luaK_reserveregs(fs, fs^.nactvar);  { reserve register for parameters }
end;

procedure body(ls: PLexState; e: Pexpdesc; needself: Boolean; line: Integer);
var new_fs: TFuncState;
begin
  { body ->  `(' parlist `)' chunk END }
  open_func(ls, @new_fs);
  new_fs.f^.linedefined := line;
  checknext(ls, Ord('('));
  if needself then
  begin
    new_localvarliteral(ls, 'self', 0);
    adjustlocalvars(ls, 1);
  end;
  parlist(ls);
  checknext(ls, Ord(')'));
  chunk(ls);
  new_fs.f^.lastlinedefined := ls^.linenumber;
  check_match(ls, TK_END, TK_FUNCTION, line);
  close_func(ls);
  pushclosure(ls, @new_fs, e);
end;

function explist1(ls: PLexState; v: Pexpdesc): Integer;
var n: Integer;
begin
  // explist1 -> expr { `,' expr } 
  n := 1;  { at least one expression }
  expr(ls, v);
  while testnext(ls, Ord(',')) do
  begin
    luaK_exp2nextreg(ls^.fs, v);
    expr(ls, v);
    Inc(n);
  end;
  Result := n;
end;

procedure funcargs(ls: PLexState; f: Pexpdesc);
var fs: PFuncState; args: Texpdesc; base, nparams, line: Integer;
begin
  fs := ls^.fs;
  line := ls^.linenumber;
  FillChar(args, SizeOf(args), 0);
  case ls^.t.token of
    Ord('('):
      begin  { funcargs -> `(' [ explist1 ] `)' }
        if line <> ls^.lastline then
          luaX_syntaxerror(ls, 'ambiguous syntax (function call x new statement)');
        luaX_next(ls);
        if ls^.t.token = Ord(')') then  { arg list is empty? }
          args.k := VVOID
        else
        begin
          explist1(ls, @args);
          luaK_setmultret(fs, @args);
        end;
        check_match(ls, Ord(')'), Ord('('), line);
      end;
    Ord('{'):
      constructor_(ls, @args);  { funcargs -> constructor }
    TK_STRING:
      begin  { funcargs -> STRING }
        codestring(ls, @args, ls^.t.seminfo.ts);
        luaX_next(ls);  { must use `seminfo' before `next' }
      end;
  else
    begin
      luaX_syntaxerror(ls, 'function arguments expected');
      Exit;
    end;
  end;
  base := f^.info;  { base register for call }
  if hasmultret(args.k) then
    nparams := LUA_MULTRET  { open call }
  else
  begin
    if args.k <> VVOID then
      luaK_exp2nextreg(fs, @args);  { close last argument }
    nparams := fs^.freereg - (base + 1);
  end;
  init_exp(f, VCALL, luaK_codeABC(fs, OP_CALL, base, nparams + 1, 2));
  luaK_fixline(fs, line);
  fs^.freereg := base + 1;  { call remove function and arguments and leaves
                              (unless changed) one result }
end;

{ Expression parsing }

procedure prefixexp(ls: PLexState; v: Pexpdesc);
var line: Integer;
begin
  { prefixexp -> NAME | '(' expr ')' }
  case ls^.t.token of
    Ord('('):
      begin
        line := ls^.linenumber;
        luaX_next(ls);
        expr(ls, v);
        check_match(ls, Ord(')'), Ord('('), line);
        luaK_dischargevars(ls^.fs, v);
      end;
    TK_NAME:
      singlevar(ls, v);
  else
    luaX_syntaxerror(ls, 'unexpected symbol');
  end;
end;

procedure primaryexp(ls: PLexState; v: Pexpdesc);
var fs: PFuncState; key: Texpdesc;
begin
  // primaryexp -> prefixexp { `.' NAME | `[' exp `]' | `:' NAME funcargs | funcargs } 
  fs := ls^.fs;
  prefixexp(ls, v);
  while True do
  begin
    case ls^.t.token of
      Ord('.'):
        field(ls, v);  { field }
      Ord('['):
        begin  { `[' exp1 `]' }
          luaK_exp2anyreg(fs, v);
          yindex(ls, @key);
          luaK_indexed(fs, v, @key);
        end;
      Ord(':'):
        begin  { `:' NAME funcargs }
          luaX_next(ls);
          checkname(ls, @key);
          luaK_self(fs, v, @key);
          funcargs(ls, v);
        end;
      Ord('('), TK_STRING, Ord('{'):
        begin  { funcargs }
          luaK_exp2nextreg(fs, v);
          funcargs(ls, v);
        end;
    else
      Exit;
    end;
  end;
end;

procedure simpleexp(ls: PLexState; v: Pexpdesc);
var fs: PFuncState;
begin
  { simpleexp -> NUMBER | STRING | NIL | true | false | ... |
                 constructor | FUNCTION body | primaryexp }
  case ls^.t.token of
    TK_NUMBER:
      begin
        init_exp(v, VKNUM, 0);
        v^.nval := ls^.t.seminfo.r;
      end;
    TK_STRING:
      codestring(ls, v, ls^.t.seminfo.ts);
    TK_NIL:
      init_exp(v, VNIL, 0);
    TK_TRUE:
      init_exp(v, VTRUE, 0);
    TK_FALSE:
      init_exp(v, VFALSE, 0);
    TK_DOTS:
      begin  { vararg }
        fs := ls^.fs;
        check_condition(ls, fs^.f^.is_vararg <> 0,
                        'cannot use ''...'' outside a vararg function');
        fs^.f^.is_vararg := fs^.f^.is_vararg and lu_byte(not VARARG_NEEDSARG);  { don't need 'arg' }
        init_exp(v, VVARARG, luaK_codeABC(fs, OP_VARARG, 0, 1, 0));
      end;
    Ord('{'):
      begin  { constructor }
        constructor_(ls, v);
        Exit;
      end;
    TK_FUNCTION:
      begin
        luaX_next(ls);
        body(ls, v, False, ls^.linenumber);
        Exit;
      end;
  else
    begin
      primaryexp(ls, v);
      Exit;
    end;
  end;
  luaX_next(ls);
end;

function getunopr(op: Integer): UnOpr;
begin
  case op of
    TK_NOT: Result := OPR_NOT;
    Ord('-'): Result := OPR_MINUS;
    Ord('#'): Result := OPR_LEN;
  else
    Result := OPR_NOUNOPR;
  end;
end;

function getbinopr(op: Integer): BinOpr;
begin
  case op of
    Ord('+'): Result := OPR_ADD;
    Ord('-'): Result := OPR_SUB;
    Ord('*'): Result := OPR_MUL;
    Ord('/'): Result := OPR_DIV;
    Ord('%'): Result := OPR_MOD;
    Ord('^'): Result := OPR_POW;
    TK_CONCAT: Result := OPR_CONCAT;
    TK_NE: Result := OPR_NE;
    TK_EQ: Result := OPR_EQ;
    Ord('<'): Result := OPR_LT;
    TK_LE: Result := OPR_LE;
    Ord('>'): Result := OPR_GT;
    TK_GE: Result := OPR_GE;
    TK_AND: Result := OPR_AND;
    TK_OR: Result := OPR_OR;
  else
    Result := OPR_NOBINOPR;
  end;
end;

{ subexpr -> (simpleexp | unop subexpr) ( binop subexpr )*
  where `binop' is any binary operator with a priority higher than `limit' }
function subexpr(ls: PLexState; v: Pexpdesc; limit: Cardinal): BinOpr;
var op, nextop: BinOpr; uop: UnOpr; v2: Texpdesc;
begin
  enterlevel(ls);
  uop := getunopr(ls^.t.token);
  if uop <> OPR_NOUNOPR then
  begin
    luaX_next(ls);
    subexpr(ls, v, UNARY_PRIORITY);
    luaK_prefix(ls^.fs, uop, v);
  end
  else
    simpleexp(ls, v);
  { expand while operators have priorities higher than `limit' }
  op := getbinopr(ls^.t.token);
  while (op <> OPR_NOBINOPR) and (Cardinal(priority_left[op]) > limit) do
  begin
    luaX_next(ls);
    luaK_infix(ls^.fs, op, v);
    { read sub-expression with higher priority }
    nextop := subexpr(ls, @v2, priority_right[op]);
    luaK_posfix(ls^.fs, op, v, @v2);
    op := nextop;
  end;
  leavelevel(ls);
  Result := op;  { return first untreated operator }
end;

procedure expr(ls: PLexState; v: Pexpdesc);
begin
  subexpr(ls, v, 0);
end;

{ Rules for Statements }

function block_follow(token: Integer): Boolean;
begin
  case token of
    TK_ELSE, TK_ELSEIF, TK_END, TK_UNTIL, TK_EOS:
      Result := True;
  else
    Result := False;
  end;
end;

procedure block(ls: PLexState);
var fs: PFuncState; bl: TBlockCnt;
begin
  { block -> chunk }
  fs := ls^.fs;
  enterblock(fs, @bl, 0);
  chunk(ls);
  leaveblock(fs);
end;

{ check whether, in an assignment to a local variable, the local variable
  is needed in a previous assignment (to a table). If so, save original
  local value in a safe place and use this safe copy in the previous
  assignment. }
procedure check_conflict(ls: PLexState; lh: PLHS_assign; v: Pexpdesc);
var fs: PFuncState; extra: Integer; conflict: Boolean;
begin
  fs := ls^.fs;
  extra := fs^.freereg;  { eventual position to save local variable }
  conflict := False;
  while lh <> nil do
  begin
    if lh^.v.k = VINDEXED then
    begin
      if lh^.v.info = v^.info then
      begin  { conflict? }
        conflict := True;
        lh^.v.info := extra;  { previous assignment will use safe copy }
      end;
      if lh^.v.aux = v^.info then
      begin  { conflict? }
        conflict := True;
        lh^.v.aux := extra;  { previous assignment will use safe copy }
      end;
    end;
    lh := lh^.prev;
  end;
  if conflict then
  begin
    luaK_codeABC(fs, OP_MOVE, fs^.freereg, v^.info, 0);  { make copy }
    luaK_reserveregs(fs, 1);
  end;
end;

procedure assignment(ls: PLexState; lh: PLHS_assign; nvars: Integer);
var e: Texpdesc; nv: TLHS_assign; nexps: Integer;
begin
  FillChar(e, SizeOf(e), 0);
  check_condition(ls, (VLOCAL <= lh^.v.k) and (lh^.v.k <= VINDEXED), 'syntax error');
  if testnext(ls, Ord(',')) then
  begin  { assignment -> `,' primaryexp assignment }
    nv.prev := lh;
    primaryexp(ls, @nv.v);
    if nv.v.k = VLOCAL then
      check_conflict(ls, lh, @nv.v);
    luaY_checklimit(ls^.fs, nvars, LUAI_MAXCCALLS - ls^.L^.nCcalls,
                    'variables in assignment');
    assignment(ls, @nv, nvars + 1);
  end
  else
  begin  { assignment -> `=' explist1 }
    checknext(ls, Ord('='));
    nexps := explist1(ls, @e);
    if nexps <> nvars then
    begin
      adjust_assign(ls, nvars, nexps, @e);
      if nexps > nvars then
        Dec(ls^.fs^.freereg, nexps - nvars);  { remove extra values }
    end
    else
    begin
      luaK_setoneret(ls^.fs, @e);  { close last expression }
      luaK_storevar(ls^.fs, @lh^.v, @e);
      Exit;  { avoid default }
    end;
  end;
  init_exp(@e, VNONRELOC, ls^.fs^.freereg - 1);  { default assignment }
  luaK_storevar(ls^.fs, @lh^.v, @e);
end;

function cond(ls: PLexState): Integer;
var v: Texpdesc;
begin
  { cond -> exp }
  expr(ls, @v);  { read condition }
  if v.k = VNIL then v.k := VFALSE;  { `falses' are all equal here }
  luaK_goiftrue(ls^.fs, @v);
  Result := v.f;
end;

procedure breakstat(ls: PLexState);
var fs: PFuncState; bl: PBlockCnt; upval: Integer;
begin
  fs := ls^.fs;
  bl := fs^.bl;
  upval := 0;
  while (bl <> nil) and (bl^.isbreakable = 0) do
  begin
    upval := upval or bl^.upval;
    bl := bl^.previous;
  end;
  if bl = nil then
    luaX_syntaxerror(ls, 'no loop to break');
  if upval <> 0 then
    luaK_codeABC(fs, OP_CLOSE, bl^.nactvar, 0, 0);
  luaK_concat(fs, bl^.breaklist, luaK_jump(fs));
end;

procedure whilestat(ls: PLexState; line: Integer);
var fs: PFuncState; whileinit, condexit: Integer; bl: TBlockCnt;
begin
  { whilestat -> WHILE cond DO block END }
  fs := ls^.fs;
  luaX_next(ls);  { skip WHILE }
  whileinit := luaK_getlabel(fs);
  condexit := cond(ls);
  enterblock(fs, @bl, 1);
  checknext(ls, TK_DO);
  block(ls);
  luaK_patchlist(fs, luaK_jump(fs), whileinit);
  check_match(ls, TK_END, TK_WHILE, line);
  leaveblock(fs);
  luaK_patchtohere(fs, condexit);  { false conditions finish the loop }
end;

procedure repeatstat(ls: PLexState; line: Integer);
var condexit, repeat_init: Integer; fs: PFuncState; bl1, bl2: TBlockCnt;
begin
  { repeatstat -> REPEAT block UNTIL cond }
  fs := ls^.fs;
  repeat_init := luaK_getlabel(fs);
  enterblock(fs, @bl1, 1);  { loop block }
  enterblock(fs, @bl2, 0);  { scope block }
  luaX_next(ls);  { skip REPEAT }
  chunk(ls);
  check_match(ls, TK_UNTIL, TK_REPEAT, line);
  condexit := cond(ls);  { read condition (inside scope block) }
  if bl2.upval = 0 then
  begin  { no upvalues? }
    leaveblock(fs);  { finish scope }
    luaK_patchlist(ls^.fs, condexit, repeat_init);  { close the loop }
  end
  else
  begin  { complete semantics when there are upvalues }
    breakstat(ls);  { if condition then break }
    luaK_patchtohere(ls^.fs, condexit);  { else... }
    leaveblock(fs);  { finish scope... }
    luaK_patchlist(ls^.fs, luaK_jump(fs), repeat_init);  { and repeat }
  end;
  leaveblock(fs);  { finish loop }
end;

function exp1(ls: PLexState): Integer;
var e: Texpdesc; k: Integer;
begin
  expr(ls, @e);
  k := e.k;
  luaK_exp2nextreg(ls^.fs, @e);
  Result := k;
end;

procedure forbody(ls: PLexState; base, line, nvars: Integer; isnum: Boolean);
var bl: TBlockCnt; fs: PFuncState; prep, endfor: Integer;
begin
  { forbody -> DO block }
  fs := ls^.fs;
  adjustlocalvars(ls, 3);  { control variables }
  checknext(ls, TK_DO);
  if isnum then prep := luaK_codeAsBx(fs, OP_FORPREP, base, NO_JUMP)
  else prep := luaK_jump(fs);
  enterblock(fs, @bl, 0);  { scope for declared variables }
  adjustlocalvars(ls, nvars);
  luaK_reserveregs(fs, nvars);
  block(ls);
  leaveblock(fs);  { end of scope for declared variables }
  luaK_patchtohere(fs, prep);
  if isnum then endfor := luaK_codeAsBx(fs, OP_FORLOOP, base, NO_JUMP)
  else endfor := luaK_codeABC(fs, OP_TFORLOOP, base, 0, nvars);
  luaK_fixline(fs, line);  { pretend that `OP_FOR' starts the loop }
  if isnum then luaK_patchlist(fs, endfor, prep + 1)
  else luaK_patchlist(fs, luaK_jump(fs), prep + 1);
end;

procedure fornum(ls: PLexState; varname: PTString; line: Integer);
var fs: PFuncState; base: Integer;
begin
  { fornum -> NAME = exp1,exp1[,exp1] forbody }
  fs := ls^.fs;
  base := fs^.freereg;
  new_localvarliteral(ls, '(for index)', 0);
  new_localvarliteral(ls, '(for limit)', 1);
  new_localvarliteral(ls, '(for step)', 2);
  new_localvar(ls, varname, 3);
  checknext(ls, Ord('='));
  exp1(ls);  { initial value }
  checknext(ls, Ord(','));
  exp1(ls);  { limit }
  if testnext(ls, Ord(',')) then
    exp1(ls)  { optional step }
  else
  begin  { default step = 1 }
    luaK_codeABx(fs, OP_LOADK, fs^.freereg, luaK_numberK(fs, 1));
    luaK_reserveregs(fs, 1);
  end;
  forbody(ls, base, line, 1, True);
end;

procedure forlist(ls: PLexState; indexname: PTString);
var fs: PFuncState; e: Texpdesc; nvars, line, base: Integer;
begin
  // forlist -> NAME {,NAME} IN explist1 forbody 
  fs := ls^.fs;
  nvars := 0;
  base := fs^.freereg;
  { create control variables }
  new_localvarliteral(ls, '(for generator)', nvars); Inc(nvars);
  new_localvarliteral(ls, '(for state)', nvars); Inc(nvars);
  new_localvarliteral(ls, '(for control)', nvars); Inc(nvars);
  { create declared variables }
  new_localvar(ls, indexname, nvars); Inc(nvars);
  while testnext(ls, Ord(',')) do
  begin
    new_localvar(ls, str_checkname(ls), nvars);
    Inc(nvars);
  end;
  checknext(ls, TK_IN);
  line := ls^.linenumber;
  adjust_assign(ls, 3, explist1(ls, @e), @e);
  luaK_checkstack(fs, 3);  { extra space to call generator }
  forbody(ls, base, line, nvars - 3, False);
end;

procedure forstat(ls: PLexState; line: Integer);
var fs: PFuncState; varname: PTString; bl: TBlockCnt;
begin
  { forstat -> FOR (fornum | forlist) END }
  fs := ls^.fs;
  enterblock(fs, @bl, 1);  { scope for loop and control variables }
  luaX_next(ls);  { skip `for' }
  varname := str_checkname(ls);  { first variable name }
  case ls^.t.token of
    Ord('='): fornum(ls, varname, line);
    Ord(','), TK_IN: forlist(ls, varname);
  else
    luaX_syntaxerror(ls, '''='' or ''in'' expected');
  end;
  check_match(ls, TK_END, TK_FOR, line);
  leaveblock(fs);  { loop scope (`break' jumps to this point) }
end;

function test_then_block(ls: PLexState): Integer;
var condexit: Integer;
begin
  { test_then_block -> [IF | ELSEIF] cond THEN block }
  luaX_next(ls);  { skip IF or ELSEIF }
  condexit := cond(ls);
  checknext(ls, TK_THEN);
  block(ls);  { `then' part }
  Result := condexit;
end;

procedure ifstat(ls: PLexState; line: Integer);
var fs: PFuncState; flist, escapelist: Integer;
begin
  // ifstat -> IF cond THEN block {ELSEIF cond THEN block} [ELSE block] END 
  fs := ls^.fs;
  escapelist := NO_JUMP;
  flist := test_then_block(ls);  { IF cond THEN block }
  while ls^.t.token = TK_ELSEIF do
  begin
    luaK_concat(fs, escapelist, luaK_jump(fs));
    luaK_patchtohere(fs, flist);
    flist := test_then_block(ls);  { ELSEIF cond THEN block }
  end;
  if ls^.t.token = TK_ELSE then
  begin
    luaK_concat(fs, escapelist, luaK_jump(fs));
    luaK_patchtohere(fs, flist);
    luaX_next(ls);  { skip ELSE (after patch, for correct line info) }
    block(ls);  { `else' part }
  end
  else
    luaK_concat(fs, escapelist, flist);
  luaK_patchtohere(fs, escapelist);
  check_match(ls, TK_END, TK_IF, line);
end;

procedure localfunc(ls: PLexState);
var v, b: Texpdesc; fs: PFuncState;
begin
  fs := ls^.fs;
  new_localvar(ls, str_checkname(ls), 0);
  init_exp(@v, VLOCAL, fs^.freereg);
  luaK_reserveregs(fs, 1);
  adjustlocalvars(ls, 1);
  body(ls, @b, False, ls^.linenumber);
  luaK_storevar(fs, @v, @b);
  { debug information will only see the variable after this point! }
  getlocvar(fs, fs^.nactvar - 1)^.startpc := fs^.pc;
end;

procedure localstat(ls: PLexState);
var nvars, nexps: Integer; e: Texpdesc;
begin
  // stat -> LOCAL NAME {`,' NAME} [`=' explist1] 
  nvars := 0;
  FillChar(e, SizeOf(e), 0);
  repeat
    new_localvar(ls, str_checkname(ls), nvars);
    Inc(nvars);
  until not testnext(ls, Ord(','));
  if testnext(ls, Ord('=')) then
    nexps := explist1(ls, @e)
  else
  begin
    e.k := VVOID;
    nexps := 0;
  end;
  adjust_assign(ls, nvars, nexps, @e);
  adjustlocalvars(ls, nvars);
end;

function funcname(ls: PLexState; v: Pexpdesc): Boolean;
var needself: Boolean;
begin
  // funcname -> NAME {field} [`:' NAME] 
  needself := False;
  singlevar(ls, v);
  while ls^.t.token = Ord('.') do
    field(ls, v);
  if ls^.t.token = Ord(':') then
  begin
    needself := True;
    field(ls, v);
  end;
  Result := needself;
end;

procedure funcstat(ls: PLexState; line: Integer);
var needself: Boolean; v, b: Texpdesc;
begin
  { funcstat -> FUNCTION funcname body }
  luaX_next(ls);  { skip FUNCTION }
  needself := funcname(ls, @v);
  body(ls, @b, needself, line);
  luaK_storevar(ls^.fs, @v, @b);
  luaK_fixline(ls^.fs, line);  { definition `happens' in the first line }
end;

procedure exprstat(ls: PLexState);
var fs: PFuncState; v: TLHS_assign;
begin
  { stat -> func | assignment }
  fs := ls^.fs;
  primaryexp(ls, @v.v);
  if v.v.k = VCALL then  { stat -> func }
    SETARG_C(fs^.f^.code[v.v.info], 1)  { call statement uses no results }
  else
  begin  { stat -> assignment }
    v.prev := nil;
    assignment(ls, @v, 1);
  end;
end;

procedure retstat(ls: PLexState);
var fs: PFuncState; e: Texpdesc; first, nret: Integer;
begin
  { stat -> RETURN explist }
  fs := ls^.fs;
  luaX_next(ls);  { skip RETURN }
  if block_follow(ls^.t.token) or (ls^.t.token = Ord(';')) then
  begin
    first := 0;
    nret := 0;  { return no values }
  end
  else
  begin
    nret := explist1(ls, @e);  { optional return values }
    if hasmultret(e.k) then
    begin
      luaK_setmultret(fs, @e);
      if (e.k = VCALL) and (nret = 1) then
      begin  { tail call? }
        SET_OPCODE(fs^.f^.code[e.info], OP_TAILCALL);
      end;
      first := fs^.nactvar;
      nret := LUA_MULTRET;  { return all values }
    end
    else
    begin
      if nret = 1 then  { only one single value? }
        first := luaK_exp2anyreg(fs, @e)
      else
      begin
        luaK_exp2nextreg(fs, @e);  { values must go to the `stack' }
        first := fs^.nactvar;  { return all `active' values }
      end;
    end;
  end;
  luaK_ret(fs, first, nret);
end;

function statement(ls: PLexState): Boolean;
var line: Integer;
begin
  line := ls^.linenumber;  { may be needed for error messages }
  case ls^.t.token of
    TK_IF:
      begin  { stat -> ifstat }
        ifstat(ls, line);
        Result := False;
      end;
    TK_WHILE:
      begin  { stat -> whilestat }
        whilestat(ls, line);
        Result := False;
      end;
    TK_DO:
      begin  { stat -> DO block END }
        luaX_next(ls);  { skip DO }
        block(ls);
        check_match(ls, TK_END, TK_DO, line);
        Result := False;
      end;
    TK_FOR:
      begin  { stat -> forstat }
        forstat(ls, line);
        Result := False;
      end;
    TK_REPEAT:
      begin  { stat -> repeatstat }
        repeatstat(ls, line);
        Result := False;
      end;
    TK_FUNCTION:
      begin
        funcstat(ls, line);  { stat -> funcstat }
        Result := False;
      end;
    TK_LOCAL:
      begin  { stat -> localstat }
        luaX_next(ls);  { skip LOCAL }
        if testnext(ls, TK_FUNCTION) then  { local function? }
          localfunc(ls)
        else
          localstat(ls);
        Result := False;
      end;
    TK_RETURN:
      begin  { stat -> retstat }
        retstat(ls);
        Result := True;  { must be last statement }
      end;
    TK_BREAK:
      begin  { stat -> breakstat }
        luaX_next(ls);  { skip BREAK }
        breakstat(ls);
        Result := True;  { must be last statement }
      end;
  else
    begin
      exprstat(ls);
      Result := False;  { to avoid warnings }
    end;
  end;
end;

procedure chunk(ls: PLexState);
var islast: Boolean;
begin
  // chunk -> { stat [`;'] } 
  islast := False;
  enterlevel(ls);
  while (not islast) and (not block_follow(ls^.t.token)) do
  begin
    islast := statement(ls);
    testnext(ls, Ord(';'));
    ls^.fs^.freereg := ls^.fs^.nactvar;  { free registers }
  end;
  leavelevel(ls);
end;

end.
