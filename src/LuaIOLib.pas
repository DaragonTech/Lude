{
  Lua 5.1.4 - Pascal port of liolib.c
  Standard I/O (and system) library

  Note: the userdata of a file handle holds a pointer to this port's own
  FILE implementation (LuaStdio.TCFile), not to a Microsoft CRT FILE.
}
unit LuaIOLib;

{$I lua.inc}

interface

uses
  LuaTypes;

function luaopen_io(L: Plua_State): Integer; cdecl;

implementation

uses
  LuaCRT, LuaAPI, LuaAuxLib, LuaStdio;

const
  IDX_INPUT = 1;
  IDX_OUTPUT = 2;

  fnames: array[0..1] of PAnsiChar = ('input', 'output');

type
  PPCFile = ^PCFile;

function pushresult(L: Plua_State; i: Boolean; filename: PAnsiChar): Integer;
var en: Integer;
begin
  en := c_errno;  { calls to Lua API may change this value }
  if i then
  begin
    lua_pushboolean(L, 1);
    Result := 1;
  end
  else
  begin
    lua_pushnil(L);
    if filename <> nil then
      lua_pushfstringf(L, '%s: %s', [filename, c_strerror(en)])
    else
      lua_pushfstringf(L, '%s', [c_strerror(en)]);
    lua_pushinteger(L, en);
    Result := 3;
  end;
end;

procedure fileerror(L: Plua_State; arg: Integer; filename: PAnsiChar);
begin
  lua_pushfstringf(L, '%s: %s', [filename, c_strerror(c_errno)]);
  luaL_argerror(L, arg, lua_tostring(L, -1));
end;

function tofilep(L: Plua_State): PPCFile; inline;
begin
  Result := PPCFile(luaL_checkudata(L, 1, LUA_FILEHANDLE));
end;

function io_type(L: Plua_State): Integer; cdecl;
var ud: Pointer;
begin
  luaL_checkany(L, 1);
  ud := lua_touserdata(L, 1);
  lua_getfield(L, LUA_REGISTRYINDEX, LUA_FILEHANDLE);
  if (ud = nil) or (lua_getmetatable(L, 1) = 0) or (lua_rawequal(L, -2, -1) = 0) then
    lua_pushnil(L)  { not a file }
  else if PPCFile(ud)^ = nil then
    lua_pushlstring(L, 'closed file', 11)
  else
    lua_pushlstring(L, 'file', 4);
  Result := 1;
end;

function tofile(L: Plua_State): PCFile;
var f: PPCFile;
begin
  f := tofilep(L);
  if f^ = nil then
    luaL_errorf(L, 'attempt to use a closed file', []);
  Result := f^;
end;

{ When creating file handles, always creates a `closed' file handle
  before opening the actual file; so, if there is a memory error, the
  file is not left opened. }
function newfile(L: Plua_State): PPCFile;
var pf: PPCFile;
begin
  pf := PPCFile(lua_newuserdata(L, SizeOf(PCFile)));
  pf^ := nil;  { file handle is currently `closed' }
  luaL_getmetatable(L, LUA_FILEHANDLE);
  lua_setmetatable(L, -2);
  Result := pf;
end;

{ function to (not) close the standard files stdin, stdout, and stderr }
function io_noclose(L: Plua_State): Integer; cdecl;
begin
  lua_pushnil(L);
  lua_pushlstring(L, 'cannot close standard file', 26);
  Result := 2;
end;

{ function to close 'popen' files }
function io_pclose(L: Plua_State): Integer; cdecl;
var p: PPCFile; ok: Boolean;
begin
  p := tofilep(L);
  ok := c_pclose(p^) <> -1;
  p^ := nil;
  Result := pushresult(L, ok, nil);
end;

{ function to close regular files }
function io_fclose(L: Plua_State): Integer; cdecl;
var p: PPCFile; ok: Boolean;
begin
  p := tofilep(L);
  ok := c_fclose(p^) = 0;
  p^ := nil;
  Result := pushresult(L, ok, nil);
end;

function aux_close(L: Plua_State): Integer;
begin
  lua_getfenv(L, 1);
  lua_getfield(L, -1, '__close');
  Result := lua_tocfunction(L, -1)(L);
end;

function io_close(L: Plua_State): Integer; cdecl;
begin
  if lua_isnone(L, 1) then
    lua_rawgeti(L, LUA_ENVIRONINDEX, IDX_OUTPUT);
  tofile(L);  { make sure argument is a file }
  Result := aux_close(L);
end;

function io_gc(L: Plua_State): Integer; cdecl;
var f: PCFile;
begin
  f := tofilep(L)^;
  { ignore closed files }
  if f <> nil then
    aux_close(L);
  Result := 0;
end;

function io_tostring(L: Plua_State): Integer; cdecl;
var f: PCFile;
begin
  f := tofilep(L)^;
  if f = nil then
    lua_pushlstring(L, 'file (closed)', 13)
  else
    lua_pushfstringf(L, 'file (%p)', [Pointer(f)]);
  Result := 1;
end;

function io_open(L: Plua_State): Integer; cdecl;
var filename, mode: PAnsiChar; pf: PPCFile;
begin
  filename := luaL_checkstring(L, 1);
  mode := luaL_optstring(L, 2, 'r');
  pf := newfile(L);
  pf^ := c_fopen(filename, mode);
  if pf^ = nil then Result := pushresult(L, False, filename) else Result := 1;
end;

{ this function has a separated environment, which defines the
  correct __close for 'popen' files }
function io_popen(L: Plua_State): Integer; cdecl;
var filename, mode: PAnsiChar; pf: PPCFile;
begin
  filename := luaL_checkstring(L, 1);
  mode := luaL_optstring(L, 2, 'r');
  pf := newfile(L);
  pf^ := c_popen(filename, mode);
  if pf^ = nil then Result := pushresult(L, False, filename) else Result := 1;
end;

function io_tmpfile(L: Plua_State): Integer; cdecl;
var pf: PPCFile;
begin
  pf := newfile(L);
  pf^ := c_tmpfile;
  if pf^ = nil then Result := pushresult(L, False, nil) else Result := 1;
end;

function getiofile(L: Plua_State; findex: Integer): PCFile;
var f: PCFile;
begin
  lua_rawgeti(L, LUA_ENVIRONINDEX, findex);
  f := PPCFile(lua_touserdata(L, -1))^;
  if f = nil then
    luaL_errorf(L, 'standard %s file is closed', [fnames[findex - 1]]);
  Result := f;
end;

function g_iofile(L: Plua_State; f: Integer; mode: PAnsiChar): Integer;
var filename: PAnsiChar; pf: PPCFile;
begin
  if not lua_isnoneornil(L, 1) then
  begin
    filename := lua_tostring(L, 1);
    if filename <> nil then
    begin
      pf := newfile(L);
      pf^ := c_fopen(filename, mode);
      if pf^ = nil then
        fileerror(L, 1, filename);
    end
    else
    begin
      tofile(L);  { check that it's a valid file handle }
      lua_pushvalue(L, 1);
    end;
    lua_rawseti(L, LUA_ENVIRONINDEX, f);
  end;
  { return current value }
  lua_rawgeti(L, LUA_ENVIRONINDEX, f);
  Result := 1;
end;

function io_input(L: Plua_State): Integer; cdecl;
begin
  Result := g_iofile(L, IDX_INPUT, 'r');
end;

function io_output(L: Plua_State): Integer; cdecl;
begin
  Result := g_iofile(L, IDX_OUTPUT, 'w');
end;

function io_readline(L: Plua_State): Integer; cdecl; forward;

procedure aux_lines(L: Plua_State; idx: Integer; toclose: Boolean);
begin
  lua_pushvalue(L, idx);
  lua_pushboolean(L, Ord(toclose));  { close/not close file when finished }
  lua_pushcclosure(L, io_readline, 2);
end;

function f_lines(L: Plua_State): Integer; cdecl;
begin
  tofile(L);  { check that it's a valid file handle }
  aux_lines(L, 1, False);
  Result := 1;
end;

function io_lines(L: Plua_State): Integer; cdecl;
var filename: PAnsiChar; pf: PPCFile;
begin
  if lua_isnoneornil(L, 1) then
  begin  { no arguments? }
    { will iterate over default input }
    lua_rawgeti(L, LUA_ENVIRONINDEX, IDX_INPUT);
    Result := f_lines(L);
  end
  else
  begin
    filename := luaL_checkstring(L, 1);
    pf := newfile(L);
    pf^ := c_fopen(filename, 'r');
    if pf^ = nil then
      fileerror(L, 1, filename);
    aux_lines(L, lua_gettop(L), True);
    Result := 1;
  end;
end;

{ ======================================================
  READ
  ======================================================= }

function read_number(L: Plua_State; f: PCFile): Boolean;
var d: lua_Number;
begin
  d := 0;
  if c_fscanf_number(f, d) = 1 then
  begin
    lua_pushnumber(L, d);
    Result := True;
  end
  else
    Result := False;  { read fails }
end;

function test_eof(L: Plua_State; f: PCFile): Boolean;
var c: Integer;
begin
  c := c_getc(f);
  c_ungetc(c, f);
  lua_pushlstring(L, nil, 0);
  Result := c <> EOF_;
end;

function read_line(L: Plua_State; f: PCFile): Boolean;
var b: luaL_Buffer; len: size_t; p: PAnsiChar;
begin
  luaL_buffinit(L, @b);
  while True do
  begin
    p := luaL_prepbuffer(@b);
    if c_fgets(p, LUAL_BUFFERSIZE, f) = nil then
    begin  { eof? }
      luaL_pushresult(@b);  { close buffer }
      Exit(lua_objlen(L, -1) > 0);  { check whether read something }
    end;
    len := c_strlen(p);
    if (len = 0) or (p[len - 1] <> #10) then
      luaL_addsize(@b, len)
    else
    begin
      luaL_addsize(@b, len - 1);  { do not include `eol' }
      luaL_pushresult(@b);  { close buffer }
      Exit(True);  { read at least an `eol' }
    end;
  end;
end;

function read_chars(L: Plua_State; f: PCFile; n: size_t): Boolean;
var rlen, nr: size_t; b: luaL_Buffer; p: PAnsiChar;
begin
  luaL_buffinit(L, @b);
  rlen := LUAL_BUFFERSIZE;  { try to read that much each time }
  repeat
    p := luaL_prepbuffer(@b);
    if rlen > n then rlen := n;  { cannot read more than asked }
    nr := c_fread(p, 1, rlen, f);
    luaL_addsize(@b, nr);
    Dec(n, nr);  { still have to read `n' chars }
  until not ((n > 0) and (nr = rlen));  { until end of count or eof }
  luaL_pushresult(@b);  { close buffer }
  Result := (n = 0) or (lua_objlen(L, -1) > 0);
end;

function g_read(L: Plua_State; f: PCFile; first: Integer): Integer;
var nargs, n: Integer; success: Boolean; len: size_t; p: PAnsiChar;
begin
  nargs := lua_gettop(L) - 1;
  c_clearerr(f);
  if nargs = 0 then
  begin  { no arguments? }
    success := read_line(L, f);
    n := first + 1;  { to return 1 result }
  end
  else
  begin  { ensure stack space for all results and for auxlib's buffer }
    luaL_checkstack(L, nargs + LUA_MINSTACK, 'too many arguments');
    success := True;
    n := first;
    while (nargs > 0) and success do
    begin
      Dec(nargs);
      if lua_type(L, n) = LUA_TNUMBER then
      begin
        len := size_t(lua_tointeger(L, n));
        if len = 0 then success := test_eof(L, f)
        else success := read_chars(L, f, len);
      end
      else
      begin
        p := lua_tostring(L, n);
        luaL_argcheck(L, (p <> nil) and (p[0] = '*'), n, 'invalid option');
        case p[1] of
          'n':  { number }
            success := read_number(L, f);
          'l':  { line }
            success := read_line(L, f);
          'a':  { file }
            begin
              read_chars(L, f, not size_t(0));  { read MAX_SIZE_T chars }
              success := True;  { always success }
            end;
        else
          Exit(luaL_argerror(L, n, 'invalid format'));
        end;
      end;
      Inc(n);
    end;
  end;
  if c_ferror(f) <> 0 then
    Exit(pushresult(L, False, nil));
  if not success then
  begin
    lua_pop(L, 1);  { remove last result }
    lua_pushnil(L);  { push nil instead }
  end;
  Result := n - first;
end;

function io_read(L: Plua_State): Integer; cdecl;
begin
  Result := g_read(L, getiofile(L, IDX_INPUT), 1);
end;

function f_read(L: Plua_State): Integer; cdecl;
begin
  Result := g_read(L, tofile(L), 2);
end;

function io_readline(L: Plua_State): Integer; cdecl;
var f: PCFile; sucess: Boolean;
begin
  f := PPCFile(lua_touserdata(L, lua_upvalueindex(1)))^;
  if f = nil then  { file is already closed? }
    luaL_errorf(L, 'file is already closed', []);
  sucess := read_line(L, f);
  if c_ferror(f) <> 0 then
    Exit(luaL_errorf(L, '%s', [c_strerror(c_errno)]));
  if sucess then Result := 1
  else
  begin  { EOF }
    if lua_toboolean(L, lua_upvalueindex(2)) <> 0 then
    begin  { generator created file? }
      lua_settop(L, 0);
      lua_pushvalue(L, lua_upvalueindex(1));
      aux_close(L);  { close it }
    end;
    Result := 0;
  end;
end;

{ ====================================================== }

function g_write(L: Plua_State; f: PCFile; arg: Integer): Integer;
var nargs: Integer; status: Boolean; len: size_t; s: PAnsiChar;
    buf: array[0..LUAI_MAXNUMBER2STR - 1] of AnsiChar;
begin
  nargs := lua_gettop(L) - 1;
  status := True;
  while nargs > 0 do
  begin
    Dec(nargs);
    if lua_type(L, arg) = LUA_TNUMBER then
    begin
      { optimization: could be done exactly as for strings }
      lua_number2str(@buf[0], lua_tonumber(L, arg));
      len := c_strlen(@buf[0]);
      status := status and (c_fwrite(@buf[0], 1, len, f) = len) and (len > 0);
    end
    else
    begin
      s := luaL_checklstring(L, arg, @len);
      status := status and (c_fwrite(s, 1, len, f) = len);
    end;
    Inc(arg);
  end;
  Result := pushresult(L, status, nil);
end;

function io_write(L: Plua_State): Integer; cdecl;
begin
  Result := g_write(L, getiofile(L, IDX_OUTPUT), 1);
end;

function f_write(L: Plua_State): Integer; cdecl;
begin
  Result := g_write(L, tofile(L), 2);
end;

const
  seek_mode: array[0..2] of Integer = (SEEK_SET, SEEK_CUR, SEEK_END);
  seek_modenames: array[0..3] of PAnsiChar = ('set', 'cur', 'end', nil);
  vbuf_mode: array[0..2] of Integer = (_IONBF, _IOFBF, _IOLBF);
  vbuf_modenames: array[0..3] of PAnsiChar = ('no', 'full', 'line', nil);

function f_seek(L: Plua_State): Integer; cdecl;
var f: PCFile; op: Integer; offset: c_long;
begin
  f := tofile(L);
  op := luaL_checkoption(L, 2, 'cur', @seek_modenames[0]);
  offset := luaL_optlong(L, 3, 0);
  op := c_fseek(f, offset, seek_mode[op]);
  if op <> 0 then
    Result := pushresult(L, False, nil)  { error }
  else
  begin
    lua_pushinteger(L, c_ftell(f));
    Result := 1;
  end;
end;

function f_setvbuf(L: Plua_State): Integer; cdecl;
var f: PCFile; op, res: Integer; sz: lua_Integer;
begin
  f := tofile(L);
  op := luaL_checkoption(L, 2, nil, @vbuf_modenames[0]);
  sz := luaL_optinteger(L, 3, LUAL_BUFFERSIZE);
  res := c_setvbuf(f, nil, vbuf_mode[op], size_t(sz));
  Result := pushresult(L, res = 0, nil);
end;

function io_flush(L: Plua_State): Integer; cdecl;
begin
  Result := pushresult(L, c_fflush(getiofile(L, IDX_OUTPUT)) = 0, nil);
end;

function f_flush(L: Plua_State): Integer; cdecl;
begin
  Result := pushresult(L, c_fflush(tofile(L)) = 0, nil);
end;

const
  iolib: array[0..11] of luaL_Reg = (
    (name: 'close'; func: io_close),
    (name: 'flush'; func: io_flush),
    (name: 'input'; func: io_input),
    (name: 'lines'; func: io_lines),
    (name: 'open'; func: io_open),
    (name: 'output'; func: io_output),
    (name: 'popen'; func: io_popen),
    (name: 'read'; func: io_read),
    (name: 'tmpfile'; func: io_tmpfile),
    (name: 'type'; func: io_type),
    (name: 'write'; func: io_write),
    (name: nil; func: nil));

  flib: array[0..9] of luaL_Reg = (
    (name: 'close'; func: io_close),
    (name: 'flush'; func: f_flush),
    (name: 'lines'; func: f_lines),
    (name: 'read'; func: f_read),
    (name: 'seek'; func: f_seek),
    (name: 'setvbuf'; func: f_setvbuf),
    (name: 'write'; func: f_write),
    (name: '__gc'; func: io_gc),
    (name: '__tostring'; func: io_tostring),
    (name: nil; func: nil));

procedure createmeta(L: Plua_State);
begin
  luaL_newmetatable(L, LUA_FILEHANDLE);  { create metatable for file handles }
  lua_pushvalue(L, -1);  { push metatable }
  lua_setfield(L, -2, '__index');  { metatable.__index = metatable }
  luaL_register(L, nil, @flib[0]);  { file methods }
end;

procedure createstdfile(L: Plua_State; f: PCFile; k: Integer; fname: PAnsiChar);
begin
  newfile(L)^ := f;
  if k > 0 then
  begin
    lua_pushvalue(L, -1);
    lua_rawseti(L, LUA_ENVIRONINDEX, k);
  end;
  lua_pushvalue(L, -2);  { copy environment }
  lua_setfenv(L, -2);  { set it }
  lua_setfield(L, -3, fname);
end;

procedure newfenv(L: Plua_State; cls: lua_CFunction);
begin
  lua_createtable(L, 0, 1);
  lua_pushcfunction(L, cls);
  lua_setfield(L, -2, '__close');
end;

function luaopen_io(L: Plua_State): Integer; cdecl;
begin
  createmeta(L);
  { create (private) environment (with fields IDX_INPUT, IDX_OUTPUT, __close) }
  newfenv(L, io_fclose);
  lua_replace(L, LUA_ENVIRONINDEX);
  { open library }
  luaL_register(L, LUA_IOLIBNAME, @iolib[0]);
  { create (and set) default files }
  newfenv(L, io_noclose);  { close function for default files }
  createstdfile(L, c_stdin, IDX_INPUT, 'stdin');
  createstdfile(L, c_stdout, IDX_OUTPUT, 'stdout');
  createstdfile(L, c_stderr, 0, 'stderr');
  lua_pop(L, 1);  { pop environment for default files }
  lua_getfield(L, -1, 'popen');
  newfenv(L, io_pclose);  { create environment for 'popen' }
  lua_setfenv(L, -2);  { set fenv for 'popen' }
  lua_pop(L, 1);  { pop 'popen' }
  Result := 1;
end;

end.
