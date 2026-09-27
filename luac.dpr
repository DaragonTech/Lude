{
  luac.exe - Lua compiler (Pascal port of luac.c + print.c, Lua 5.1.4).
  Saves bytecodes to files; also lists bytecodes.
  Like the C luac it uses internal functions of the core (luaU_dump,
  luaF_newproto, ...), so it links the Lua units statically instead of
  going through lua5.1.dll.
}
program luac;

{$I src/lua.inc}
{$IFDEF MSWINDOWS}{$APPTYPE CONSOLE}{$ENDIF}

uses
  LuaTypes in 'src/LuaTypes.pas',
  LuaCRT in 'src/LuaCRT.pas',
  LuaWin in 'src/LuaWin.pas',
  LuaStdio in 'src/LuaStdio.pas',
  LuaFPU in 'src/LuaFPU.pas',
  LuaObject in 'src/LuaObject.pas',
  LuaOpcodes in 'src/LuaOpcodes.pas',
  LuaTM in 'src/LuaTM.pas',
  LuaZIO in 'src/LuaZIO.pas',
  LuaMem in 'src/LuaMem.pas',
  LuaString in 'src/LuaString.pas',
  LuaFunc in 'src/LuaFunc.pas',
  LuaTable in 'src/LuaTable.pas',
  LuaGC in 'src/LuaGC.pas',
  LuaState in 'src/LuaState.pas',
  LuaDo in 'src/LuaDo.pas',
  LuaDebug in 'src/LuaDebug.pas',
  LuaVM in 'src/LuaVM.pas',
  LuaLex in 'src/LuaLex.pas',
  LuaCode in 'src/LuaCode.pas',
  LuaParser in 'src/LuaParser.pas',
  LuaDump in 'src/LuaDump.pas',
  LuaUndump in 'src/LuaUndump.pas',
  LuaAPI in 'src/LuaAPI.pas',
  LuaAuxLib in 'src/LuaAuxLib.pas';

const
  PROGNAME = 'luac';                { default program name }
  OUTPUT = PROGNAME + '.out';       { default output file }

{$IFNDEF LUA_POSIX}
function GetCommandLineA: PAnsiChar; stdcall; external 'kernel32.dll';
{$ENDIF}

var
  argv_store: array of AnsiString;
  argv_arr: array of PAnsiChar;
  argc: Integer;
  argv: PPAnsiChar;

  listing: Integer = 0;             { list bytecodes? }
  dumping: Boolean = True;          { dump bytecodes? }
  stripping: Integer = 0;           { strip debug information? }
  Output_: array[0..8] of AnsiChar = OUTPUT + #0;  { default output file name }
  output_name: PAnsiChar;           { actual output file name }
  progname_: PAnsiChar = PROGNAME;  { actual program name }

{$IFDEF LUA_POSIX}
procedure parse_cmdline;
var i: Integer;
begin
  argc := System.argc;
  SetLength(argv_arr, argc + 1);
  for i := 0 to argc - 1 do argv_arr[i] := System.argv[i];
  argv_arr[argc] := nil;
  argv := @argv_arr[0];
end;
{$ELSE}
{ ------------------------------------------------ MSVC argv parsing }

procedure parse_cmdline;
var p: PAnsiChar; arg: AnsiString; inquote: Boolean; nbs, i: Integer;
  procedure add(const a: AnsiString);
  begin
    SetLength(argv_store, Length(argv_store) + 1);
    argv_store[High(argv_store)] := a;
  end;
begin
  p := GetCommandLineA;
  arg := '';
  inquote := False;
  while (p^ <> #0) and (inquote or ((p^ <> ' ') and (p^ <> #9))) do
  begin
    if p^ = '"' then inquote := not inquote
    else arg := arg + p^;
    Inc(p);
  end;
  add(arg);
  while True do
  begin
    while (p^ = ' ') or (p^ = #9) do Inc(p);
    if p^ = #0 then Break;
    arg := '';
    inquote := False;
    while True do
    begin
      nbs := 0;
      while p^ = '\' do begin Inc(p); Inc(nbs); end;
      if p^ = '"' then
      begin
        for i := 1 to nbs div 2 do arg := arg + '\';
        if (nbs mod 2) = 1 then
        begin
          arg := arg + '"';
          Inc(p);
        end
        else if inquote and ((p + 1)^ = '"') then
        begin
          arg := arg + '"';
          Inc(p, 2);
        end
        else
        begin
          inquote := not inquote;
          Inc(p);
        end;
      end
      else
      begin
        for i := 1 to nbs do arg := arg + '\';
        if (p^ = #0) or ((not inquote) and ((p^ = ' ') or (p^ = #9))) then Break;
        arg := arg + p^;
        Inc(p);
      end;
    end;
    add(arg);
  end;
  argc := Length(argv_store);
  SetLength(argv_arr, argc + 1);
  for i := 0 to argc - 1 do argv_arr[i] := PAnsiChar(argv_store[i]);
  argv_arr[argc] := nil;
  argv := @argv_arr[0];
end;
{$ENDIF}

{ ------------------------------------------------ output helpers }

procedure out_s(const s: AnsiString);
begin
  if s <> '' then c_fwrite(PAnsiChar(s), 1, Length(s), c_stdout);
end;

procedure err_s(const s: AnsiString);
begin
  if s <> '' then c_fwrite(PAnsiChar(s), 1, Length(s), c_stderr);
end;

function itos(n: Integer): AnsiString;
begin
  Result := c_itoa(n);
end;

function ptos(p: Pointer): AnsiString;
begin
  Result := c_fmt_pointer(p);   { %p }
end;

{ ------------------------------------------------ luac.c }

procedure fatal(message: PAnsiChar);
begin
  err_s(AnsiString(progname_) + ': ' + AnsiString(message) + #10);
  c_exit(1);
end;

procedure cannot(what: PAnsiChar);
begin
  err_s(AnsiString(progname_) + ': cannot ' + AnsiString(what) + ' ' +
    AnsiString(output_name) + ': ' + AnsiString(c_strerror(c_errno)) + #10);
  c_exit(1);
end;

procedure usage(message: PAnsiChar);
begin
  if message^ = '-' then
    err_s(AnsiString(progname_) + ': unrecognized option ''' + AnsiString(message) + '''' + #10)
  else
    err_s(AnsiString(progname_) + ': ' + AnsiString(message) + #10);
  err_s('usage: ' + AnsiString(progname_) + ' [options] [filenames].'#10 +
    'Available options are:'#10 +
    '  -        process stdin'#10 +
    '  -l       list'#10 +
    '  -o name  output to file ''name'' (default is "' + AnsiString(PAnsiChar(@Output_[0])) + '")'#10 +
    '  -p       parse only'#10 +
    '  -s       strip debug information'#10 +
    '  -v       show version information'#10 +
    '  --       stop handling options'#10);
  c_exit(1);
end;

function IS_(i: Integer; s: PAnsiChar): Boolean;
begin
  Result := c_strcmp(argv[i], s) = 0;
end;

function doargs: Integer;
var i, version: Integer;
begin
  version := 0;
  if (argv[0] <> nil) and (argv[0]^ <> #0) then progname_ := argv[0];
  i := 1;
  while i < argc do
  begin
    if argv[i]^ <> '-' then          { end of options; keep it }
      Break
    else if IS_(i, '--') then        { end of options; skip it }
    begin
      Inc(i);
      if version <> 0 then Inc(version);
      Break;
    end
    else if IS_(i, '-') then         { end of options; use stdin }
      Break
    else if IS_(i, '-l') then        { list }
      Inc(listing)
    else if IS_(i, '-o') then        { output file }
    begin
      Inc(i);
      output_name := argv[i];
      if (output_name = nil) or (output_name^ = #0) then usage('''-o'' needs argument');
      if IS_(i, '-') then output_name := nil;
    end
    else if IS_(i, '-p') then        { parse only }
      dumping := False
    else if IS_(i, '-s') then        { strip debug information }
      stripping := 1
    else if IS_(i, '-v') then        { show version }
      Inc(version)
    else                             { unknown option }
      usage(argv[i]);
    Inc(i);
  end;
  if (i = argc) and ((listing <> 0) or not dumping) then
  begin
    dumping := False;
    Dec(i);
    argv[i] := @Output_[0];
  end;
  if version <> 0 then
  begin
    out_s(LUA_RELEASE + '  ' + LUA_COPYRIGHT + #10);
    if version = argc - 1 then c_exit(0);
  end;
  Result := i;
end;

function toproto(L: Plua_State; i: Integer): PProto;
begin
  Result := clvalue(L^.top + i)^.l.p;
end;

function combine(L: Plua_State; n: Integer): PProto;
var i, pc: Integer; f: PProto;
begin
  if n = 1 then
    Result := toproto(L, -1)
  else
  begin
    f := luaF_newproto(L);
    setptvalue(L, L^.top, f); incr_top(L);
    f^.source := luaS_newliteral(L, '=(' + PROGNAME + ')');
    f^.maxstacksize := 1;
    pc := 2 * n + 1;
    f^.code := luaM_newvector(L, pc, SizeOf(Instruction));
    f^.sizecode := pc;
    f^.p := luaM_newvector(L, n, SizeOf(PProto));
    f^.sizep := n;
    pc := 0;
    for i := 0 to n - 1 do
    begin
      f^.p[i] := toproto(L, i - n - 1);
      f^.code[pc] := CREATE_ABx(OP_CLOSURE, 0, i); Inc(pc);
      f^.code[pc] := CREATE_ABC(OP_CALL, 0, 1, 1); Inc(pc);
    end;
    f^.code[pc] := CREATE_ABC(OP_RETURN, 0, 1, 0);
    Result := f;
  end;
end;

function writer(L: Plua_State; p: Pointer; size: size_t; u: Pointer): Integer; cdecl;
begin
  Result := Ord((c_fwrite(p, size, 1, PCFile(u)) <> 1) and (size <> 0));
end;

{ ------------------------------------------------ print.c }

procedure PrintString(ts: PTString);
var s: PAnsiChar; i, n: size_t; c: Integer; r: AnsiString; o: AnsiString;
begin
  s := getstr(ts);
  n := ts^.len;
  r := '"';
  i := 0;
  while i < n do
  begin
    c := Ord(s[i]);
    case c of
      Ord('"'):  r := r + '\"';
      Ord('\'):  r := r + '\\';
      7:  r := r + '\a';
      8:  r := r + '\b';
      12: r := r + '\f';
      10: r := r + '\n';
      13: r := r + '\r';
      9:  r := r + '\t';
      11: r := r + '\v';
    else
      if (c >= $20) and (c < $7F) then   { isprint in the "C" locale }
        r := r + AnsiChar(c)
      else
      begin
        o := itos(c);
        while Length(o) < 3 do o := '0' + o;
        r := r + '\' + o;
      end;
    end;
    Inc(i);
  end;
  out_s(r + '"');
end;

procedure PrintConstant(f: PProto; i: Integer);
var o: PTValue; buf: array[0..LUAI_MAXNUMBER2STR] of AnsiChar;
begin
  o := @f^.k[i];
  case ttype(o) of
    LUA_TNIL: out_s('nil');
    LUA_TBOOLEAN: if bvalue(o) <> 0 then out_s('true') else out_s('false');
    LUA_TNUMBER:
      begin
        lua_number2str(@buf[0], nvalue(o));   { LUA_NUMBER_FMT }
        out_s(AnsiString(PAnsiChar(@buf[0])));
      end;
    LUA_TSTRING: PrintString(rawtsvalue(o));
  else                                         { cannot happen }
    out_s('? type=' + itos(ttype(o)));
  end;
end;

procedure PrintCode(f: PProto);
var code: PInstruction; pc, n, a, b, c, bx, sbx, line: Integer;
  i: Instruction; o: OpCode; nm: AnsiString;
begin
  code := f^.code;
  n := f^.sizecode;
  pc := 0;
  while pc < n do
  begin
    i := code[pc];
    o := GET_OPCODE(i);
    a := GETARG_A(i);
    b := GETARG_B(i);
    c := GETARG_C(i);
    bx := GETARG_Bx(i);
    sbx := GETARG_sBx(i);
    line := getline_(f, pc);
    out_s(#9 + itos(pc + 1) + #9);
    if line > 0 then out_s('[' + itos(line) + ']'#9) else out_s('[-]'#9);
    nm := AnsiString(luaP_opnames[o]);
    while Length(nm) < 9 do nm := nm + ' ';
    out_s(nm + #9);
    case getOpMode(o) of
      iABC:
        begin
          out_s(itos(a));
          if getBMode(o) <> OpArgN then
            if ISK(b) then out_s(' ' + itos(-1 - INDEXK(b))) else out_s(' ' + itos(b));
          if getCMode(o) <> OpArgN then
            if ISK(c) then out_s(' ' + itos(-1 - INDEXK(c))) else out_s(' ' + itos(c));
        end;
      iABx:
        if getBMode(o) = OpArgK then out_s(itos(a) + ' ' + itos(-1 - bx))
        else out_s(itos(a) + ' ' + itos(bx));
      iAsBx:
        if o = OP_JMP then out_s(itos(sbx)) else out_s(itos(a) + ' ' + itos(sbx));
    end;
    case o of
      OP_LOADK:
        begin out_s(#9'; '); PrintConstant(f, bx); end;
      OP_GETUPVAL, OP_SETUPVAL:
        if f^.sizeupvalues > 0 then out_s(#9'; ' + AnsiString(getstr(f^.upvalues[b])))
        else out_s(#9'; -');
      OP_GETGLOBAL, OP_SETGLOBAL:
        out_s(#9'; ' + AnsiString(svalue(@f^.k[bx])));
      OP_GETTABLE, OP_SELF:
        if ISK(c) then begin out_s(#9'; '); PrintConstant(f, INDEXK(c)); end;
      OP_SETTABLE, OP_ADD, OP_SUB, OP_MUL, OP_DIV, OP_POW, OP_EQ, OP_LT, OP_LE:
        if ISK(b) or ISK(c) then
        begin
          out_s(#9'; ');
          if ISK(b) then PrintConstant(f, INDEXK(b)) else out_s('-');
          out_s(' ');
          if ISK(c) then PrintConstant(f, INDEXK(c)) else out_s('-');
        end;
      OP_JMP, OP_FORLOOP, OP_FORPREP:
        out_s(#9'; to ' + itos(sbx + pc + 2));
      OP_CLOSURE:
        out_s(#9'; ' + ptos(f^.p[bx]));
      OP_SETLIST:
        if c = 0 then begin Inc(pc); out_s(#9'; ' + itos(Integer(code[pc]))); end
        else out_s(#9'; ' + itos(c));
    end;
    out_s(#10);
    Inc(pc);
  end;
end;

function SS(x: Integer): AnsiString;
begin
  if x = 1 then Result := '' else Result := 's';
end;

function S_(x: Integer): AnsiString;
begin
  Result := itos(x) + ' ';
end;

procedure PrintHeader(f: PProto);
var s: PAnsiChar; kind, vararg: AnsiString;
begin
  s := getstr(f^.source);
  if (s^ = '@') or (s^ = '=') then
    Inc(s)
  else if s^ = LUA_SIGNATURE_CHAR then
    s := '(bstring)'
  else
    s := '(string)';
  if f^.linedefined = 0 then kind := 'main' else kind := 'function';
  out_s(#10 + kind + ' <' + AnsiString(s) + ':' + itos(f^.linedefined) + ',' +
    itos(f^.lastlinedefined) + '> (' + itos(f^.sizecode) + ' instruction' + SS(f^.sizecode) +
    ', ' + itos(f^.sizecode * SizeOf(Instruction)) + ' bytes at ' + ptos(f) + ')'#10);
  if f^.is_vararg <> 0 then vararg := '+' else vararg := '';
  out_s(itos(f^.numparams) + vararg + ' param' + SS(f^.numparams) + ', ' +
    itos(f^.maxstacksize) + ' slot' + SS(f^.maxstacksize) + ', ' +
    itos(f^.nups) + ' upvalue' + SS(f^.nups) + ', ');
  out_s(itos(f^.sizelocvars) + ' local' + SS(f^.sizelocvars) + ', ' +
    itos(f^.sizek) + ' constant' + SS(f^.sizek) + ', ' +
    itos(f^.sizep) + ' function' + SS(f^.sizep) + #10);
end;

procedure PrintConstants(f: PProto);
var i, n: Integer;
begin
  n := f^.sizek;
  out_s('constants (' + itos(n) + ') for ' + ptos(f) + ':'#10);
  for i := 0 to n - 1 do
  begin
    out_s(#9 + itos(i + 1) + #9);
    PrintConstant(f, i);
    out_s(#10);
  end;
end;

procedure PrintLocals(f: PProto);
var i, n: Integer;
begin
  n := f^.sizelocvars;
  out_s('locals (' + itos(n) + ') for ' + ptos(f) + ':'#10);
  for i := 0 to n - 1 do
    out_s(#9 + itos(i) + #9 + AnsiString(getstr(f^.locvars[i].varname)) + #9 +
      itos(f^.locvars[i].startpc + 1) + #9 + itos(f^.locvars[i].endpc + 1) + #10);
end;

procedure PrintUpvalues(f: PProto);
var i, n: Integer;
begin
  n := f^.sizeupvalues;
  out_s('upvalues (' + itos(n) + ') for ' + ptos(f) + ':'#10);
  if f^.upvalues = nil then Exit;
  for i := 0 to n - 1 do
    out_s(#9 + itos(i) + #9 + AnsiString(getstr(f^.upvalues[i])) + #10);
end;

procedure luaU_print(f: PProto; full: Boolean);
var i, n: Integer;
begin
  n := f^.sizep;
  PrintHeader(f);
  PrintCode(f);
  if full then
  begin
    PrintConstants(f);
    PrintLocals(f);
    PrintUpvalues(f);
  end;
  for i := 0 to n - 1 do luaU_print(f^.p[i], full);
end;

{ ------------------------------------------------ main }

type
  TSmain = record
    argc: Integer;
    argv: PPAnsiChar;
  end;
  PSmain = ^TSmain;

function pmain(L: Plua_State): Integer; cdecl;
var s: PSmain; i: Integer; f: PProto; filename: PAnsiChar; D: PCFile;
begin
  s := PSmain(lua_touserdata(L, 1));
  if lua_checkstack(L, s^.argc) = 0 then fatal('too many input files');
  for i := 0 to s^.argc - 1 do
  begin
    if c_strcmp(s^.argv[i], '-') = 0 then filename := nil else filename := s^.argv[i];
    if luaL_loadfile(L, filename) <> 0 then fatal(lua_tostring(L, -1));
  end;
  f := combine(L, s^.argc);
  if listing <> 0 then luaU_print(f, listing > 1);
  if dumping then
  begin
    if output_name = nil then D := c_stdout else D := c_fopen(output_name, 'wb');
    if D = nil then cannot('open');
    luaU_dump(L, f, writer, D, stripping);
    if c_ferror(D) <> 0 then cannot('write');
    if c_fclose(D) <> 0 then cannot('close');
  end;
  Result := 0;
end;

var
  L: Plua_State;
  s: TSmain;
  i: Integer;
begin
  lua_set_c_fpu_mode;
  output_name := @Output_[0];
  parse_cmdline;
  i := doargs;
  Dec(argc, i);
  Inc(argv, i);
  if argc <= 0 then usage('no input files given');
  L := luaL_newstate;
  if L = nil then fatal('not enough memory for state');
  s.argc := argc;
  s.argv := argv;
  if lua_cpcall(L, pmain, @s) <> 0 then fatal(lua_tostring(L, -1));
  lua_close(L);
  c_exit(0);
end.
