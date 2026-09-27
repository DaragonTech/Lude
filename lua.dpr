{
  lua.exe - Lua stand-alone interpreter (Pascal port of lua.c, Lua 5.1.4).
  Windows: uses lua5.1.dll through the LuaDLL import unit, like the
  LuaBinaries lua5.1.exe.
  Linux: Lua is linked in (LuaStatic) and the C API is exported from the
  executable (LuaHostExports), like "make linux" (-Wl,-E), so C modules
  loaded with require find it.  Uses the C library's stdio and signal().
  Behaviour, messages and exit codes follow lua.c.
}
program lua;

{$I src/lua.inc}
{$IFDEF MSWINDOWS}{$APPTYPE CONSOLE}{$ENDIF}

uses
{$IFDEF LUA_POSIX}
  LuaStatic in 'src/LuaStatic.pas',
  LuaHostExports in 'src/LuaHostExports.pas',
  LuaPosix in 'src/LuaPosix.pas',
{$ELSE}
  LuaDLL in 'src/LuaDLL.pas',
{$ENDIF}
  LuaFPU in 'src/LuaFPU.pas';

const
  LUA_PROMPT = '> ';
  LUA_PROMPT2 = '>> ';
  LUA_PROGNAME = 'lua';
  LUA_MAXINPUT = 512;
  LUA_INIT = 'LUA_INIT';

{$IFDEF LUA_POSIX}
{ ---------------------------------------------------------------- C library bits }

const
  SIGINT = 2;
  SIG_DFL = nil;

type
  TSigHandler = procedure(sig: Integer); cdecl;

function px_signal(sig: Integer; handler: TSigHandler): Pointer; cdecl; external libc name 'signal';

var
  argv: array of PAnsiChar;     { NULL terminated, like C }
  argc: Integer;

procedure parse_cmdline;
var i: Integer;
begin
  argc := System.argc;
  SetLength(argv, argc + 1);
  for i := 0 to argc - 1 do argv[i] := System.argv[i];
  argv[argc] := nil;
end;

{ fprintf(stderr, ...); fflush(stderr) }
procedure fputs_stderr(const s: AnsiString);
begin
  px_fputs(PAnsiChar(s), libc_stderr);
  px_fflush(libc_stderr);
end;

{ fputs(s, stdout); fflush(stdout) }
procedure fputs_stdout(const s: AnsiString);
begin
  px_fputs(PAnsiChar(s), libc_stdout);
  px_fflush(libc_stdout);
end;

{ fgets(b, LUA_MAXINPUT, stdin), then as seen through strlen }
function fgets_stdin(var line: AnsiString): Boolean;
var buf: array[0..LUA_MAXINPUT - 1] of AnsiChar;
begin
  Result := px_fgets(@buf[0], LUA_MAXINPUT, libc_stdin) <> nil;
  if Result then line := AnsiString(PAnsiChar(@buf[0])) else line := '';
end;

function getenv_(name: PAnsiChar; var value: AnsiString): Boolean;
var p: PAnsiChar;
begin
  p := px_getenv(name);
  Result := p <> nil;
  if Result then value := AnsiString(p);
end;

function stdin_is_tty: Boolean;
begin
  Result := px_isatty(0) <> 0;
end;

procedure exit_(code: Integer);
begin
  px_exit(code);   { flushes the C streams }
end;

{$ELSE}
const
  kernel32 = 'kernel32.dll';
  STD_INPUT_HANDLE  = Cardinal(-10);
  STD_OUTPUT_HANDLE = Cardinal(-11);
  STD_ERROR_HANDLE  = Cardinal(-12);
  FILE_TYPE_CHAR = 2;
  CTRL_C_EVENT = 0;

type
  THandlerRoutine = function(dwCtrlType: Cardinal): LongBool; stdcall;

function GetStdHandle(nStdHandle: Cardinal): NativeUInt; stdcall; external kernel32;
function GetFileType(hFile: NativeUInt): Cardinal; stdcall; external kernel32;
function WriteFile(hFile: NativeUInt; lpBuffer: Pointer; n: Cardinal; written: PCardinal; ov: Pointer): LongBool; stdcall; external kernel32;
function ReadFile(hFile: NativeUInt; lpBuffer: Pointer; n: Cardinal; read: PCardinal; ov: Pointer): LongBool; stdcall; external kernel32;
function GetCommandLineA: PAnsiChar; stdcall; external kernel32;
function GetEnvironmentVariableA(lpName, lpBuffer: PAnsiChar; nSize: Cardinal): Cardinal; stdcall; external kernel32;
function SetConsoleCtrlHandler(HandlerRoutine: THandlerRoutine; Add: LongBool): LongBool; stdcall; external kernel32;
procedure ExitProcess(uExitCode: Cardinal); stdcall; external kernel32;

{ ---------------------------------------------------------------- C runtime bits }

{ fputs to stdout/stderr in text mode (LF -> CR LF), unbuffered }
procedure out_str(h: NativeUInt; const s: AnsiString);
var t: AnsiString; i: Integer; w: Cardinal;
begin
  t := '';
  for i := 1 to Length(s) do
  begin
    if s[i] = #10 then t := t + #13;
    t := t + s[i];
  end;
  if Length(t) > 0 then WriteFile(h, @t[1], Length(t), @w, nil);
end;

procedure fputs_stderr(const s: AnsiString);
begin
  out_str(GetStdHandle(STD_ERROR_HANDLE), s);
end;

procedure fputs_stdout(const s: AnsiString);
begin
  out_str(GetStdHandle(STD_OUTPUT_HANDLE), s);
end;

{ fgets(b, LUA_MAXINPUT, stdin) in text mode, reading byte by byte so that
  nothing is read ahead of what the library's own stdin will see }
function fgets_stdin(var line: AnsiString): Boolean;
var c: AnsiChar; got: Cardinal; h: NativeUInt; pendingCR: Boolean;
begin
  line := '';
  h := GetStdHandle(STD_INPUT_HANDLE);
  pendingCR := False;
  while Length(line) < LUA_MAXINPUT - 1 do
  begin
    got := 0;
    if not ReadFile(h, @c, 1, @got, nil) or (got = 0) then
    begin
      if pendingCR then line := line + #13;
      Break;
    end;
    if pendingCR then
    begin
      pendingCR := False;
      if c = #10 then
      begin
        line := line + #10;
        Break;
      end;
      line := line + #13;
    end;
    if c = #13 then
    begin
      pendingCR := True;
      Continue;
    end;
    if (c = #26) and (GetFileType(h) <> FILE_TYPE_CHAR) then Break;
    line := line + c;
    if c = #10 then Break;
  end;
  Result := Length(line) > 0;
end;

function getenv_(name: PAnsiChar; var value: AnsiString): Boolean;
var n: Cardinal;
begin
  n := GetEnvironmentVariableA(name, nil, 0);
  if n = 0 then Exit(False);
  SetLength(value, n);
  n := GetEnvironmentVariableA(name, PAnsiChar(value), n);
  SetLength(value, n);
  Result := True;
end;

{ argv as built by the Microsoft C runtime from the command line }
var
  argv_store: array of AnsiString;
  argv: array of PAnsiChar;     { NULL terminated, like C }
  argc: Integer;

procedure parse_cmdline;
var p: PAnsiChar; arg: AnsiString; inquote: Boolean; nbs, i: Integer;
  procedure add(const a: AnsiString);
  begin
    SetLength(argv_store, Length(argv_store) + 1);
    argv_store[High(argv_store)] := a;
  end;
begin
  p := GetCommandLineA;
  { program name: up to the first white space outside quotes, no escapes }
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
        else
        begin
          if inquote and ((p + 1)^ = '"') then
          begin
            arg := arg + '"';  { "" inside quotes: literal quote }
            Inc(p, 2);
          end
          else
          begin
            inquote := not inquote;
            Inc(p);
          end;
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
  SetLength(argv, argc + 1);
  for i := 0 to argc - 1 do argv[i] := PAnsiChar(argv_store[i]);
  argv[argc] := nil;
end;

function stdin_is_tty: Boolean;
begin
  Result := GetFileType(GetStdHandle(STD_INPUT_HANDLE)) = FILE_TYPE_CHAR;
end;

procedure exit_(code: Integer);
begin
  ExitProcess(Cardinal(code));
end;
{$ENDIF}

{ ---------------------------------------------------------------- lua.c }

var
  globalL: Plua_State = nil;
  progname: PAnsiChar = LUA_PROGNAME;
  sigint_armed: Boolean = False;

procedure lstop(L: Plua_State; ar: Plua_Debug); cdecl;
begin
  lua_sethook(L, nil, 0, 0);
  luaL_errorf(L, 'interrupted!', []);
end;

{$IFDEF LUA_POSIX}
procedure laction(i: Integer); cdecl;
begin
  px_signal(i, SIG_DFL);  { if another SIGINT happens before lstop,
                            terminate process (default action) }
  lua_sethook(globalL, lstop, LUA_MASKCALL or LUA_MASKRET or LUA_MASKCOUNT, 1);
end;
{$ELSE}
{ signal(SIGINT, laction) of the MS C runtime is a console control handler }
function ctrl_handler(dwCtrlType: Cardinal): LongBool; stdcall;
begin
  if (dwCtrlType = CTRL_C_EVENT) and sigint_armed then
  begin
    sigint_armed := False;  { signal(i, SIG_DFL) }
    lua_sethook(globalL, lstop, LUA_MASKCALL or LUA_MASKRET or LUA_MASKCOUNT, 1);
    Result := True;
  end
  else
    Result := False;
end;
{$ENDIF}

procedure print_usage;
begin
  fputs_stderr('usage: ' + AnsiString(progname) + ' [options] [script [args]].'#10 +
    'Available options are:'#10 +
    '  -e stat  execute string ''stat'''#10 +
    '  -l name  require library ''name'''#10 +
    '  -i       enter interactive mode after executing ''script'''#10 +
    '  -v       show version information'#10 +
    '  --       stop handling options'#10 +
    '  -        execute stdin and stop handling options'#10);
end;

procedure l_message(pname: PAnsiChar; msg: PAnsiChar);
begin
  if pname <> nil then fputs_stderr(AnsiString(pname) + ': ');
  fputs_stderr(AnsiString(msg) + #10);
end;

function report(L: Plua_State; status: Integer): Integer;
var msg: PAnsiChar;
begin
  if (status <> 0) and not lua_isnil(L, -1) then
  begin
    msg := lua_tostring(L, -1);
    if msg = nil then msg := '(error object is not a string)';
    l_message(progname, msg);
    lua_pop(L, 1);
  end;
  Result := status;
end;

function traceback(L: Plua_State): Integer; cdecl;
begin
  if lua_isstring(L, 1) = 0 then  { 'message' not a string? }
    Exit(1);  { keep it intact }
  lua_getfield(L, LUA_GLOBALSINDEX, 'debug');
  if not lua_istable(L, -1) then
  begin
    lua_pop(L, 1);
    Exit(1);
  end;
  lua_getfield(L, -1, 'traceback');
  if not lua_isfunction(L, -1) then
  begin
    lua_pop(L, 2);
    Exit(1);
  end;
  lua_pushvalue(L, 1);  { pass error message }
  lua_pushinteger(L, 2);  { skip this function and traceback }
  lua_call(L, 2, 1);  { call debug.traceback }
  Result := 1;
end;

function docall(L: Plua_State; narg: Integer; clear: Boolean): Integer;
var status, base, nres: Integer;
begin
  base := lua_gettop(L) - narg;  { function index }
  lua_pushcfunction(L, traceback);  { push traceback function }
  lua_insert(L, base);  { put it under chunk and args }
{$IFDEF LUA_POSIX}
  px_signal(SIGINT, laction);
{$ELSE}
  sigint_armed := True;
{$ENDIF}
  if clear then nres := 0 else nres := LUA_MULTRET;
  status := lua_pcall(L, narg, nres, base);
{$IFDEF LUA_POSIX}
  px_signal(SIGINT, SIG_DFL);
{$ELSE}
  sigint_armed := False;
{$ENDIF}
  lua_remove(L, base);  { remove traceback function }
  { force a complete garbage collection in case of errors }
  if status <> 0 then lua_gc(L, LUA_GCCOLLECT, 0);
  Result := status;
end;

procedure print_version;
begin
  l_message(nil, LUA_RELEASE + '  ' + LUA_COPYRIGHT);
end;

function getargs(L: Plua_State; n: Integer): Integer;
var narg, i: Integer;
begin
  narg := argc - (n + 1);  { number of arguments to the script }
  luaL_checkstack(L, narg + 3, 'too many arguments to script');
  for i := n + 1 to argc - 1 do
    lua_pushstring(L, argv[i]);
  lua_createtable(L, narg, n + 1);
  for i := 0 to argc - 1 do
  begin
    lua_pushstring(L, argv[i]);
    lua_rawseti(L, -2, i - n);
  end;
  Result := narg;
end;

function dofile(L: Plua_State; name: PAnsiChar): Integer;
var status: Integer;
begin
  status := luaL_loadfile(L, name);
  if status = 0 then status := docall(L, 0, True);
  Result := report(L, status);
end;

function dostring(L: Plua_State; s: PAnsiChar; name: PAnsiChar): Integer;
var status, len: Integer;
begin
  len := 0;
  while s[len] <> #0 do Inc(len);
  status := luaL_loadbuffer(L, s, len, name);
  if status = 0 then status := docall(L, 0, True);
  Result := report(L, status);
end;

function dolibrary(L: Plua_State; name: PAnsiChar): Integer;
begin
  lua_getglobal(L, 'require');
  lua_pushstring(L, name);
  Result := report(L, docall(L, 1, True));
end;

function get_prompt(L: Plua_State; firstline: Boolean): AnsiString;
var p: PAnsiChar;
begin
  if firstline then lua_getfield(L, LUA_GLOBALSINDEX, '_PROMPT')
  else lua_getfield(L, LUA_GLOBALSINDEX, '_PROMPT2');
  p := lua_tostring(L, -1);
  if p = nil then
  begin
    if firstline then Result := LUA_PROMPT else Result := LUA_PROMPT2;
  end
  else
    Result := AnsiString(p);
  lua_pop(L, 1);  { remove global }
end;

function incomplete(L: Plua_State; status: Integer): Boolean;
var lmsg: size_t; msg: PAnsiChar; m: AnsiString;
begin
  if status = LUA_ERRSYNTAX then
  begin
    msg := lua_tolstring(L, -1, @lmsg);
    SetString(m, msg, lmsg);
    { strstr(msg, "'<eof>'") == msg + lmsg - 7 }
    if (lmsg >= 7) and (Pos(AnsiString('''<eof>'''), m) = Integer(lmsg) - 6) then
    begin
      lua_pop(L, 1);
      Exit(True);
    end;
  end;
  Result := False;  { else... }
end;

function pushline(L: Plua_State; firstline: Boolean): Boolean;
var b: AnsiString; prmt: AnsiString;
begin
  prmt := get_prompt(L, firstline);
  fputs_stdout(prmt);
  if not fgets_stdin(b) then
    Exit(False);  { no input }
  if (Length(b) > 0) and (b[Length(b)] = #10) then  { line ends with newline? }
    SetLength(b, Length(b) - 1);  { remove it }
  if Pos(AnsiString(#0), b) > 0 then SetLength(b, Pos(AnsiString(#0), b) - 1);
  if firstline and (Length(b) > 0) and (b[1] = '=') then  { first line starts with `=' ? }
    lua_pushfstringf(L, 'return %s', [PAnsiChar(PAnsiChar(b) + 1)])  { change it to `return' }
  else
    lua_pushstring(L, PAnsiChar(b));
  Result := True;
end;

function loadline(L: Plua_State): Integer;
var status: Integer;
begin
  lua_settop(L, 0);
  if not pushline(L, True) then
    Exit(-1);  { no input }
  while True do
  begin  { repeat until gets a complete line }
    status := luaL_loadbuffer(L, lua_tostring(L, 1), lua_strlen(L, 1), '=stdin');
    if not incomplete(L, status) then Break;  { cannot try to add lines? }
    if not pushline(L, False) then  { no more input? }
      Exit(-1);
    lua_pushliteral(L, #10);  { add a new line... }
    lua_insert(L, -2);  { ...between the two lines }
    lua_concat(L, 3);  { join them }
  end;
  lua_remove(L, 1);  { remove line }
  Result := status;
end;

procedure dotty(L: Plua_State);
var status: Integer; oldprogname: PAnsiChar;
begin
  oldprogname := progname;
  progname := nil;
  while True do
  begin
    status := loadline(L);
    if status = -1 then Break;
    if status = 0 then status := docall(L, 0, False);
    report(L, status);
    if (status = 0) and (lua_gettop(L) > 0) then
    begin  { any result to print? }
      lua_getglobal(L, 'print');
      lua_insert(L, 1);
      if lua_pcall(L, lua_gettop(L) - 1, 0, 0) <> 0 then
        l_message(progname, lua_pushfstringf(L, 'error calling ''print'' (%s)',
                                             [lua_tostring(L, -1)]));
    end;
  end;
  lua_settop(L, 0);  { clear stack }
  fputs_stdout(#10);
  progname := oldprogname;
end;

function handle_script(L: Plua_State; n: Integer): Integer;
var status, narg: Integer; fname: PAnsiChar;
begin
  narg := getargs(L, n);  { collect arguments }
  lua_setglobal(L, 'arg');
  fname := argv[n];
  if (AnsiString(fname) = '-') and (AnsiString(argv[n - 1]) <> '--') then
    fname := nil;  { stdin }
  status := luaL_loadfile(L, fname);
  lua_insert(L, -(narg + 1));
  if status = 0 then
    status := docall(L, narg, False)
  else
    lua_pop(L, narg);
  Result := report(L, status);
end;

{ check that argument has no extra characters at the end }
function collectargs(var pi, pv, pe: Boolean): Integer;
var i: Integer;
begin
  i := 1;
  while argv[i] <> nil do
  begin
    if argv[i][0] <> '-' then  { not an option? }
      Exit(i);
    case argv[i][1] of  { option }
      '-':
        begin
          if argv[i][2] <> #0 then Exit(-1);
          if argv[i + 1] <> nil then Exit(i + 1) else Exit(0);
        end;
      #0:
        Exit(i);
      'i', 'v':
        begin
          if argv[i][2] <> #0 then Exit(-1);
          if argv[i][1] = 'i' then pi := True;
          pv := True;
        end;
      'e', 'l':
        begin
          if argv[i][1] = 'e' then pe := True;
          if argv[i][2] = #0 then
          begin
            Inc(i);
            if argv[i] = nil then Exit(-1);
          end;
        end;
    else
      Exit(-1);
    end;
    Inc(i);
  end;
  Result := 0;
end;

function runargs(L: Plua_State; n: Integer): Integer;
var i: Integer; chunk, filename: PAnsiChar;
begin
  i := 1;
  while i < n do
  begin
    if argv[i] <> nil then
      case argv[i][1] of
        'e':
          begin
            chunk := argv[i] + 2;
            if chunk^ = #0 then
            begin
              Inc(i);
              chunk := argv[i];
            end;
            if dostring(L, chunk, '=(command line)') <> 0 then
              Exit(1);
          end;
        'l':
          begin
            filename := argv[i] + 2;
            if filename^ = #0 then
            begin
              Inc(i);
              filename := argv[i];
            end;
            if dolibrary(L, filename) <> 0 then
              Exit(1);  { stop if file fails }
          end;
      end;
    Inc(i);
  end;
  Result := 0;
end;

function handle_luainit(L: Plua_State): Integer;
var init: AnsiString;
begin
  if not getenv_(LUA_INIT, init) then Exit(0)  { status OK }
  else if (Length(init) > 0) and (init[1] = '@') then
    Result := dofile(L, PAnsiChar(init) + 1)
  else
    Result := dostring(L, PAnsiChar(init), '=' + LUA_INIT);
end;

type
  PSmain = ^TSmain;
  TSmain = record
    argc: Integer;
    status: Integer;
  end;

function pmain(L: Plua_State): Integer; cdecl;
var s: PSmain; script: Integer; has_i, has_v, has_e: Boolean;
begin
  s := PSmain(lua_touserdata(L, 1));
  has_i := False; has_v := False; has_e := False;
  globalL := L;
  if (argv[0] <> nil) and (argv[0][0] <> #0) then progname := argv[0];
  lua_gc(L, LUA_GCSTOP, 0);  { stop collector during initialization }
  luaL_openlibs(L);  { open libraries }
  lua_gc(L, LUA_GCRESTART, 0);
  s^.status := handle_luainit(L);
  if s^.status <> 0 then Exit(0);
  script := collectargs(has_i, has_v, has_e);
  if script < 0 then
  begin  { invalid args? }
    print_usage;
    s^.status := 1;
    Exit(0);
  end;
  if has_v then print_version;
  if script > 0 then s^.status := runargs(L, script)
  else s^.status := runargs(L, s^.argc);
  if s^.status <> 0 then Exit(0);
  if script <> 0 then
    s^.status := handle_script(L, script);
  if s^.status <> 0 then Exit(0);
  if has_i then
    dotty(L)
  else if (script = 0) and not has_e and not has_v then
  begin
    if stdin_is_tty then
    begin
      print_version;
      dotty(L);
    end
    else
      dofile(L, nil);  { executes stdin as a file }
  end;
  Result := 0;
end;

var
  L: Plua_State;
  s: TSmain;
  status: Integer;
begin
  lua_set_c_fpu_mode;
  parse_cmdline;
{$IFNDEF LUA_POSIX}
  SetConsoleCtrlHandler(ctrl_handler, True);
{$ENDIF}
  L := lua_open;  { create state }
  if L = nil then
  begin
    l_message(argv[0], 'cannot create state: not enough memory');
    exit_(1);
  end;
  s.argc := argc;
  s.status := 0;
  status := lua_cpcall(L, pmain, @s);
  report(L, status);
  lua_close(L);
  if (status <> 0) or (s.status <> 0) then exit_(1) else exit_(0);
end.
