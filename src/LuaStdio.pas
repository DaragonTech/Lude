{
  Lua 5.1.4 - Pascal port
  Emulation of the Microsoft C runtime <stdio.h> used by Lua:
  buffered FILE streams over Win32 handles, with MSVC text-mode semantics
  (CR LF <-> LF translation, Ctrl-Z as end of file), popen/pclose, system,
  tmpfile/tmpnam, remove/rename, errno/strerror.
}
unit LuaStdio;

{$I lua.inc}

interface

{$IFDEF LUA_POSIX}
{ ======================================================================
  POSIX: the system C library's stdio, used directly.  PCFile is a real
  FILE*, so C modules can use the FILE* inside io library handles.
  ====================================================================== }

uses
  LuaTypes, LuaPosix;

const
  EOF_ = -1;
  { glibc values }
  _IOFBF = 0;
  _IOLBF = 1;
  _IONBF = 2;
  SEEK_SET = 0;
  SEEK_CUR = 1;
  SEEK_END = 2;
  BUFSIZ = 8192;
  EINVAL = 22;

type
  PCFile = Pointer;

var
  c_stdin, c_stdout, c_stderr: PCFile;

function c_errno: Integer; inline;
procedure c_set_errno(e: Integer); inline;
function c_strerror(e: Integer): PAnsiChar; inline;

function c_fopen(filename, mode: PAnsiChar): PCFile; inline;
function c_freopen(filename, mode: PAnsiChar; f: PCFile): PCFile; inline;
function c_fclose(f: PCFile): Integer; inline;
function c_fread(ptr: Pointer; size, count: NativeUInt; f: PCFile): NativeUInt; inline;
function c_fwrite(ptr: Pointer; size, count: NativeUInt; f: PCFile): NativeUInt; inline;
function c_fputs(s: PAnsiChar; f: PCFile): Integer; inline;
function c_fgets(buf: PAnsiChar; n: Integer; f: PCFile): PAnsiChar; inline;
function c_getc(f: PCFile): Integer; inline;
function c_ungetc(c: Integer; f: PCFile): Integer; inline;
function c_fflush(f: PCFile): Integer; inline;
procedure c_flushall; inline;
function c_fseek(f: PCFile; offset: c_long; whence: Integer): Integer; inline;
function c_ftell(f: PCFile): c_long; inline;
function c_setvbuf(f: PCFile; buf: PAnsiChar; mode: Integer; size: NativeUInt): Integer; inline;
function c_ferror(f: PCFile): Integer; inline;
function c_feof(f: PCFile): Integer; inline;
procedure c_clearerr(f: PCFile); inline;
function c_tmpfile: PCFile; inline;
function c_popen(command, mode: PAnsiChar): PCFile; inline;
function c_pclose(f: PCFile): Integer; inline;
{ fscanf(f, "%lf", &d): returns 1 on success, 0 on matching failure, EOF }
function c_fscanf_number(f: PCFile; var d: Double): Integer;

function c_system(command: PAnsiChar): Integer; inline;
function c_remove(filename: PAnsiChar): Integer; inline;
function c_rename(oldname, newname: PAnsiChar): Integer; inline;
{ lua_tmpnam with LUA_USE_MKSTEMP: "/tmp/lua_XXXXXX" (buf >= 32 bytes) }
function c_tmpnam(buf: PAnsiChar): PAnsiChar;
function c_getenv(name: PAnsiChar): PAnsiChar; inline;
procedure c_exit(code: Integer); inline;

implementation

function c_errno: Integer; begin Result := px_errno_location^; end;
procedure c_set_errno(e: Integer); begin px_errno_location^ := e; end;
function c_strerror(e: Integer): PAnsiChar; begin Result := px_strerror(e); end;
function c_fopen(filename, mode: PAnsiChar): PCFile; begin Result := px_fopen(filename, mode); end;
function c_freopen(filename, mode: PAnsiChar; f: PCFile): PCFile; begin Result := px_freopen(filename, mode, f); end;
function c_fclose(f: PCFile): Integer; begin Result := px_fclose(f); end;
function c_fread(ptr: Pointer; size, count: NativeUInt; f: PCFile): NativeUInt; begin Result := px_fread(ptr, size, count, f); end;
function c_fwrite(ptr: Pointer; size, count: NativeUInt; f: PCFile): NativeUInt; begin Result := px_fwrite(ptr, size, count, f); end;
function c_fputs(s: PAnsiChar; f: PCFile): Integer; begin Result := px_fputs(s, f); end;
function c_fgets(buf: PAnsiChar; n: Integer; f: PCFile): PAnsiChar; begin Result := px_fgets(buf, n, f); end;
function c_getc(f: PCFile): Integer; begin Result := px_getc(f); end;
function c_ungetc(c: Integer; f: PCFile): Integer; begin Result := px_ungetc(c, f); end;
function c_fflush(f: PCFile): Integer; begin Result := px_fflush(f); end;
procedure c_flushall; begin px_fflush(nil); end;
function c_fseek(f: PCFile; offset: c_long; whence: Integer): Integer; begin Result := px_fseek(f, offset, whence); end;
function c_ftell(f: PCFile): c_long; begin Result := px_ftell(f); end;
function c_setvbuf(f: PCFile; buf: PAnsiChar; mode: Integer; size: NativeUInt): Integer; begin Result := px_setvbuf(f, buf, mode, size); end;
function c_ferror(f: PCFile): Integer; begin Result := px_ferror(f); end;
function c_feof(f: PCFile): Integer; begin Result := px_feof(f); end;
procedure c_clearerr(f: PCFile); begin px_clearerr(f); end;
function c_tmpfile: PCFile; begin Result := px_tmpfile; end;
function c_popen(command, mode: PAnsiChar): PCFile; begin px_fflush(nil); Result := px_popen(command, mode); end;
function c_pclose(f: PCFile): Integer; begin Result := px_pclose(f); end;
function c_system(command: PAnsiChar): Integer; begin Result := px_system(command); end;
function c_remove(filename: PAnsiChar): Integer; begin Result := px_remove(filename); end;
function c_rename(oldname, newname: PAnsiChar): Integer; begin Result := px_rename(oldname, newname); end;
function c_getenv(name: PAnsiChar): PAnsiChar; begin Result := px_getenv(name); end;
procedure c_exit(code: Integer); begin px_exit(code); end;

function c_fscanf_number(f: PCFile; var d: Double): Integer;
begin
  Result := px_fscanf(f, '%lf', @d);
end;

function c_tmpnam(buf: PAnsiChar): PAnsiChar;
const TEMPLATE: PAnsiChar = '/tmp/lua_XXXXXX';
var fd, i: Integer;
begin
  for i := 0 to 15 do buf[i] := TEMPLATE[i];   { strcpy incl. the NUL }
  fd := px_mkstemp(buf);
  if fd = -1 then Exit(nil);
  px_close(fd);
  Result := buf;
end;

initialization
  c_stdin := libc_stdin;
  c_stdout := libc_stdout;
  c_stderr := libc_stderr;

{$ELSE}

uses
  LuaWin;

const
  EOF_ = -1;
  { MSVC values }
  _IOFBF = $0000;
  _IOLBF = $0040;
  _IONBF = $0004;
  SEEK_SET = 0;
  SEEK_CUR = 1;
  SEEK_END = 2;
  BUFSIZ = 512;
  INTERNAL_BUFSIZ = 4096;

  { MSVC errno values }
  EPERM = 1; ENOENT = 2; ESRCH = 3; EINTR = 4; EIO = 5; ENXIO = 6; E2BIG = 7;
  ENOEXEC = 8; EBADF = 9; ECHILD = 10; EAGAIN = 11; ENOMEM = 12; EACCES = 13;
  EFAULT = 14; EBUSY = 16; EEXIST = 17; EXDEV = 18; ENODEV = 19; ENOTDIR = 20;
  EISDIR = 21; EINVAL = 22; ENFILE = 23; EMFILE = 24; ENOTTY = 25; EFBIG = 27;
  ENOSPC = 28; ESPIPE = 29; EROFS = 30; EMLINK = 31; EPIPE = 32; EDOM = 33;
  ERANGE = 34; EDEADLK = 36; ENAMETOOLONG = 38; ENOLCK = 39; ENOSYS = 40;
  ENOTEMPTY = 41; EILSEQ = 42;

type
  PCFile = ^TCFile;
  TCFile = record
    h: HANDLE;
    canRead, canWrite, isText, isAppend: Boolean;
    isDevice, isPipe, isStd: Boolean;
    eof, err, ctrlz: Boolean;
    buf: PByte;
    bufsize: Integer;
    ownbuf: Boolean;
    bufmode: Integer;
    tempbuf: Boolean;            { stdout/stderr on a console: flush after each call }
    rpos, rlen: Integer;         { read buffer (raw bytes) }
    wlen: Integer;               { pending bytes in write buffer }
    lastop: Integer;             { 0 none, 1 read, 2 write }
    ungot: array[0..7] of Byte;
    tiny: array[0..3] of Byte;
    nungot: Integer;
    proc: HANDLE;                { popen: child process }
    next, prev: PCFile;          { list of open streams (for flushall) }
  end;

var
  c_stdin, c_stdout, c_stderr: PCFile;

function c_errno: Integer;
procedure c_set_errno(e: Integer);
function c_strerror(e: Integer): PAnsiChar;
function c_dosmaperr(oserr: DWORD): Integer;

function c_fopen(filename, mode: PAnsiChar): PCFile;
function c_freopen(filename, mode: PAnsiChar; f: PCFile): PCFile;
function c_fclose(f: PCFile): Integer;
function c_fread(ptr: Pointer; size, count: NativeUInt; f: PCFile): NativeUInt;
function c_fwrite(ptr: Pointer; size, count: NativeUInt; f: PCFile): NativeUInt;
function c_fputs(s: PAnsiChar; f: PCFile): Integer;
function c_fgets(buf: PAnsiChar; n: Integer; f: PCFile): PAnsiChar;
function c_getc(f: PCFile): Integer;
function c_ungetc(c: Integer; f: PCFile): Integer;
function c_fflush(f: PCFile): Integer;
procedure c_flushall;
function c_fseek(f: PCFile; offset: Integer; whence: Integer): Integer;
function c_ftell(f: PCFile): Integer;
function c_setvbuf(f: PCFile; buf: PAnsiChar; mode: Integer; size: NativeUInt): Integer;
function c_ferror(f: PCFile): Integer;
function c_feof(f: PCFile): Integer;
procedure c_clearerr(f: PCFile);
function c_tmpfile: PCFile;
function c_popen(command, mode: PAnsiChar): PCFile;
function c_pclose(f: PCFile): Integer;
{ fscanf(f, "%lf", &d): returns 1 on success, 0 on matching failure, EOF }
function c_fscanf_number(f: PCFile; var d: Double): Integer;

function c_system(command: PAnsiChar): Integer;
function c_remove(filename: PAnsiChar): Integer;
function c_rename(oldname, newname: PAnsiChar): Integer;
function c_tmpnam(buf: PAnsiChar): PAnsiChar;
function c_getenv(name: PAnsiChar): PAnsiChar;
procedure c_exit(code: Integer);

implementation

uses
  LuaCRT;

threadvar
  errno_: Integer;

var
  openlist: PCFile = nil;
  heap: HANDLE = 0;

function c_errno: Integer;
begin
  Result := errno_;
end;

procedure c_set_errno(e: Integer);
begin
  errno_ := e;
end;

const
  sys_errlist: array[0..43] of PAnsiChar = (
    'No error',
    'Operation not permitted',
    'No such file or directory',
    'No such process',
    'Interrupted function call',
    'Input/output error',
    'No such device or address',
    'Arg list too long',
    'Exec format error',
    'Bad file descriptor',
    'No child processes',
    'Resource temporarily unavailable',
    'Not enough space',
    'Permission denied',
    'Bad address',
    'Unknown error',
    'Resource device',
    'File exists',
    'Improper link',
    'No such device',
    'Not a directory',
    'Is a directory',
    'Invalid argument',
    'Too many open files in system',
    'Too many open files',
    'Inappropriate I/O control operation',
    'Unknown error',
    'File too large',
    'No space left on device',
    'Invalid seek',
    'Read-only file system',
    'Too many links',
    'Broken pipe',
    'Domain error',
    'Result too large',
    'Unknown error',
    'Resource deadlock avoided',
    'Unknown error',
    'Filename too long',
    'No locks available',
    'Function not implemented',
    'Directory not empty',
    'Illegal byte sequence',
    'Unknown error');

function c_strerror(e: Integer): PAnsiChar;
begin
  if (e < 0) or (e > 43) then e := 43;
  Result := sys_errlist[e];
end;

{ the MSVC _dosmaperr table }
function c_dosmaperr(oserr: DWORD): Integer;
begin
  case oserr of
    1: Result := EINVAL;            { ERROR_INVALID_FUNCTION }
    2, 3: Result := ENOENT;         { FILE_NOT_FOUND, PATH_NOT_FOUND }
    4: Result := EMFILE;
    5: Result := EACCES;
    6: Result := EBADF;
    7, 8, 9: Result := ENOMEM;
    10: Result := E2BIG;
    11: Result := ENOEXEC;
    12, 13: Result := EINVAL;
    15: Result := ENOENT;
    16: Result := EACCES;
    17: Result := EXDEV;
    18: Result := ENOENT;
    19..36: Result := EACCES;
    53: Result := ENOENT;
    65: Result := EACCES;
    67: Result := ENOENT;
    80: Result := EEXIST;
    82, 83: Result := EACCES;
    87: Result := EINVAL;
    89: Result := EAGAIN;
    108: Result := EACCES;
    109: Result := EPIPE;
    112: Result := ENOSPC;
    114: Result := EBADF;
    128, 129: Result := ECHILD;
    130: Result := EBADF;
    131: Result := EINVAL;
    132: Result := EACCES;
    145: Result := ENOTEMPTY;
    158: Result := EACCES;
    161: Result := ENOENT;
    164: Result := EAGAIN;
    167: Result := EACCES;
    183: Result := EEXIST;
    188..202: Result := ENOEXEC;
    206: Result := ENOENT;
    215: Result := EAGAIN;
    1816: Result := ENOMEM;
  else
    Result := EINVAL;
  end;
end;

procedure set_oserr;
begin
  errno_ := c_dosmaperr(GetLastError);
end;

function xalloc(n: NativeUInt): Pointer;
begin
  if heap = 0 then heap := GetProcessHeap;
  Result := HeapAlloc(heap, 0, n);
end;

procedure xfree(p: Pointer);
begin
  if p <> nil then HeapFree(heap, 0, p);
end;

procedure link_file(f: PCFile);
begin
  f^.prev := nil;
  f^.next := openlist;
  if openlist <> nil then openlist^.prev := f;
  openlist := f;
end;

procedure unlink_file(f: PCFile);
begin
  if f^.prev <> nil then f^.prev^.next := f^.next else openlist := f^.next;
  if f^.next <> nil then f^.next^.prev := f^.prev;
  f^.next := nil;
  f^.prev := nil;
end;

procedure init_file(f: PCFile; h: HANDLE);
var ft: DWORD;
begin
  FillChar(f^, SizeOf(TCFile), 0);
  f^.h := h;
  f^.isText := True;
  f^.bufmode := _IOFBF;
  f^.bufsize := INTERNAL_BUFSIZ;
  ft := GetFileType(h);
  f^.isDevice := ft = FILE_TYPE_CHAR;
  f^.isPipe := ft = FILE_TYPE_PIPE;
end;

procedure ensure_buf(f: PCFile);
begin
  if f^.buf = nil then
  begin
    if f^.bufsize <= 0 then f^.bufsize := INTERNAL_BUFSIZ;
    f^.buf := xalloc(f^.bufsize + 2);
    f^.ownbuf := True;
    if f^.buf = nil then
    begin
      { fall back to a tiny buffer }
      f^.bufsize := 1;
      f^.buf := @f^.tiny[0];
      f^.ownbuf := False;
    end;
  end;
end;

{ ------------------------------------------------------------------ writing }

function os_write(f: PCFile; p: PByte; n: Integer): Boolean;
var written: DWORD; hi: Longint;
begin
  Result := True;
  if n <= 0 then Exit;
  if f^.isAppend then
  begin
    hi := 0;
    SetFilePointer(f^.h, 0, @hi, FILE_END);
  end;
  while n > 0 do
  begin
    written := 0;
    if not WriteFile(f^.h, p, DWORD(n), @written, nil) or (written = 0) then
    begin
      set_oserr;
      f^.err := True;
      Exit(False);
    end;
    Inc(p, written);
    Dec(n, written);
  end;
end;

function flush_write(f: PCFile): Boolean;
begin
  Result := True;
  if (f^.lastop = 2) and (f^.wlen > 0) then
  begin
    Result := os_write(f, f^.buf, f^.wlen);
    f^.wlen := 0;
  end;
end;

{ discard read-ahead and reposition the OS file pointer to the logical position }
procedure drop_read(f: PCFile);
var back: Integer; hi: Longint;
begin
  if f^.lastop = 1 then
  begin
    back := (f^.rlen - f^.rpos) + f^.nungot;
    if (back > 0) and not (f^.isDevice or f^.isPipe) then
    begin
      hi := -1;
      SetFilePointer(f^.h, -back, @hi, FILE_CURRENT);
    end;
    f^.rpos := 0;
    f^.rlen := 0;
    f^.nungot := 0;
  end;
end;

function prep_write(f: PCFile): Boolean;
begin
  if not f^.canWrite then
  begin
    f^.err := True;
    errno_ := EBADF;
    Exit(False);
  end;
  if f^.lastop = 1 then drop_read(f);
  f^.lastop := 2;
  ensure_buf(f);
  Result := True;
end;

function put_byte(f: PCFile; b: Byte): Boolean; inline;
begin
  if f^.wlen >= f^.bufsize then
    if not flush_write(f) then Exit(False);
  f^.buf[f^.wlen] := b;
  Inc(f^.wlen);
  f^.lastop := 2;
  Result := True;
end;

function write_bytes(f: PCFile; p: PByte; n: NativeUInt): NativeUInt;
var i: NativeUInt;
begin
  Result := 0;
  if not prep_write(f) then Exit;
  i := 0;
  while i < n do
  begin
    if f^.isText and (p[i] = 10) then
      if not put_byte(f, 13) then Exit;
    if not put_byte(f, p[i]) then Exit;
    Inc(Result);
    Inc(i);
  end;
  if (f^.bufmode = _IONBF) or f^.tempbuf then
    flush_write(f);
end;

function c_fwrite(ptr: Pointer; size, count: NativeUInt; f: PCFile): NativeUInt;
var total, done: NativeUInt;
begin
  if (size = 0) or (count = 0) or (f = nil) then Exit(0);
  total := size * count;
  done := write_bytes(f, ptr, total);
  Result := done div size;
end;

function c_fputs(s: PAnsiChar; f: PCFile): Integer;
var n: NativeUInt;
begin
  n := c_strlen(s);
  if write_bytes(f, PByte(s), n) = n then Result := 0 else Result := EOF_;
end;

function c_fflush(f: PCFile): Integer;
begin
  if f = nil then
  begin
    c_flushall;
    Exit(0);
  end;
  Result := 0;
  if f^.lastop = 2 then
  begin
    if not flush_write(f) then Result := EOF_;
  end
  else if f^.lastop = 1 then
    drop_read(f);
  f^.lastop := 0;
end;

procedure c_flushall;
var f: PCFile;
begin
  f := openlist;
  while f <> nil do
  begin
    if f^.lastop = 2 then flush_write(f);
    f := f^.next;
  end;
end;

{ ------------------------------------------------------------------ reading }

function fill_buf(f: PCFile): Boolean;
var got: DWORD; e: DWORD;
begin
  f^.rpos := 0;
  f^.rlen := 0;
  if f^.ctrlz then Exit(False);
  ensure_buf(f);
  got := 0;
  if not ReadFile(f^.h, f^.buf, DWORD(f^.bufsize), @got, nil) then
  begin
    e := GetLastError;
    if (e = ERROR_BROKEN_PIPE) or (e = ERROR_NO_DATA) then
      Exit(False);  { end of pipe }
    errno_ := c_dosmaperr(e);
    f^.err := True;
    Exit(False);
  end;
  if got = 0 then Exit(False);
  f^.rlen := got;
  Result := True;
end;

function prep_read(f: PCFile): Boolean;
begin
  if not f^.canRead then
  begin
    f^.err := True;
    errno_ := EBADF;
    Exit(False);
  end;
  if f^.lastop = 2 then
  begin
    flush_write(f);
  end;
  if f^.lastop <> 1 then
  begin
    f^.rpos := 0;
    f^.rlen := 0;
  end;
  f^.lastop := 1;
  Result := True;
end;

{ next raw byte, or -1 }
function raw_get(f: PCFile): Integer; inline;
begin
  if f^.rpos >= f^.rlen then
    if not fill_buf(f) then Exit(-1);
  Result := f^.buf[f^.rpos];
  Inc(f^.rpos);
end;

function raw_peek(f: PCFile): Integer;
begin
  if f^.rpos >= f^.rlen then
    if not fill_buf(f) then Exit(-1);
  Result := f^.buf[f^.rpos];
end;

{ get one translated character (no ungetc handling) }
function get_char(f: PCFile): Integer;
var c: Integer;
begin
  c := raw_get(f);
  if c < 0 then
  begin
    f^.eof := True;
    Exit(EOF_);
  end;
  if f^.isText then
  begin
    if (c = 26) and not f^.isDevice then
    begin
      { Ctrl-Z: end of file in text mode; leave the file positioned on it }
      Dec(f^.rpos);
      f^.ctrlz := True;
      f^.eof := True;
      Exit(EOF_);
    end;
    if c = 13 then
    begin
      if raw_peek(f) = 10 then
      begin
        Inc(f^.rpos);
        c := 10;
      end;
    end;
  end;
  Result := c;
end;

function c_getc(f: PCFile): Integer;
begin
  if f^.nungot > 0 then
  begin
    Dec(f^.nungot);
    Exit(f^.ungot[f^.nungot]);
  end;
  if not prep_read(f) then Exit(EOF_);
  Result := get_char(f);
end;

function c_ungetc(c: Integer; f: PCFile): Integer;
begin
  if (c = EOF_) or (f^.nungot >= 4) then Exit(EOF_);
  if f^.lastop = 2 then flush_write(f);
  f^.lastop := 1;
  f^.ungot[f^.nungot] := Byte(c);
  Inc(f^.nungot);
  f^.eof := False;
  Result := c and $FF;
end;

function c_fread(ptr: Pointer; size, count: NativeUInt; f: PCFile): NativeUInt;
var total, done, avail: NativeUInt; p: PByte; c: Integer;
begin
  if (size = 0) or (count = 0) then Exit(0);
  total := size * count;
  p := ptr;
  done := 0;
  while (done < total) and (f^.nungot > 0) do
  begin
    Dec(f^.nungot);
    p[done] := f^.ungot[f^.nungot];
    Inc(done);
  end;
  if done < total then
  begin
    if not prep_read(f) then Exit(done div size);
    if not f^.isText then
    begin
      while done < total do
      begin
        if f^.rpos >= f^.rlen then
          if not fill_buf(f) then
          begin
            f^.eof := True;
            Break;
          end;
        avail := f^.rlen - f^.rpos;
        if avail > total - done then avail := total - done;
        Move(f^.buf[f^.rpos], p[done], avail);
        Inc(f^.rpos, avail);
        Inc(done, avail);
      end;
    end
    else
      while done < total do
      begin
        c := get_char(f);
        if c = EOF_ then Break;
        p[done] := Byte(c);
        Inc(done);
      end;
  end;
  Result := done div size;
end;

function c_fgets(buf: PAnsiChar; n: Integer; f: PCFile): PAnsiChar;
var i, c: Integer;
begin
  if n <= 0 then Exit(nil);
  i := 0;
  while i < n - 1 do
  begin
    c := c_getc(f);
    if c = EOF_ then
    begin
      if i = 0 then Exit(nil);
      Break;
    end;
    buf[i] := AnsiChar(c);
    Inc(i);
    if c = 10 then Break;
  end;
  buf[i] := #0;
  Result := buf;
end;

function c_fscanf_number(f: PCFile; var d: Double): Integer;
var c: Integer; s: AnsiString; digits: Boolean;
  procedure take;
  begin
    s := s + AnsiChar(c);
    c := c_getc(f);
  end;
begin
  { skip white space }
  repeat
    c := c_getc(f);
  until not c_isspace(c);
  if c = EOF_ then Exit(EOF_);
  s := '';
  digits := False;
  if (c = Ord('+')) or (c = Ord('-')) then take;
  while c_isdigit(c) do begin digits := True; take; end;
  if c = Ord('.') then
  begin
    take;
    while c_isdigit(c) do begin digits := True; take; end;
  end;
  if digits and ((c = Ord('e')) or (c = Ord('E'))) then
  begin
    take;
    if (c = Ord('+')) or (c = Ord('-')) then take;
    while c_isdigit(c) do take;
  end;
  if c <> EOF_ then c_ungetc(c, f);
  if not digits then Exit(0);
  d := c_strtod(PAnsiChar(s), nil);
  Result := 1;
end;

{ ------------------------------------------------------------------ open/close }

function parse_mode(mode: PAnsiChar; var access, disp: DWORD; var rd, wr, app, text: Boolean): Boolean;
begin
  Result := True;
  rd := False; wr := False; app := False; text := True;
  case mode^ of
    'r': begin rd := True; access := GENERIC_READ; disp := OPEN_EXISTING; end;
    'w': begin wr := True; access := GENERIC_WRITE; disp := CREATE_ALWAYS; end;
    'a': begin wr := True; app := True; access := GENERIC_WRITE; disp := OPEN_ALWAYS; end;
  else
    Exit(False);
  end;
  Inc(mode);
  while mode^ <> #0 do
  begin
    case mode^ of
      '+':
        begin
          rd := True; wr := True;
          access := GENERIC_READ or GENERIC_WRITE;
        end;
      'b': text := False;
      't': text := True;
    end;
    Inc(mode);
  end;
end;

function open_into(f: PCFile; filename, mode: PAnsiChar; flags: DWORD): Boolean;
var access, disp: DWORD; rd, wr, app, text: Boolean; h: HANDLE;
begin
  Result := False;
  access := 0; disp := 0;
  if not parse_mode(mode, access, disp, rd, wr, app, text) then
  begin
    errno_ := EINVAL;
    Exit;
  end;
  h := CreateFileA(filename, access, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, disp,
                   FILE_ATTRIBUTE_NORMAL or flags, 0);
  if h = INVALID_HANDLE_VALUE then
  begin
    set_oserr;
    Exit;
  end;
  init_file(f, h);
  f^.canRead := rd;
  f^.canWrite := wr;
  f^.isAppend := app;
  f^.isText := text;
  Result := True;
end;

function c_fopen(filename, mode: PAnsiChar): PCFile;
var f: PCFile;
begin
  f := xalloc(SizeOf(TCFile));
  if f = nil then
  begin
    errno_ := ENOMEM;
    Exit(nil);
  end;
  if not open_into(f, filename, mode, 0) then
  begin
    xfree(f);
    Exit(nil);
  end;
  link_file(f);
  Result := f;
end;

procedure release_handle(f: PCFile);
begin
  if f^.ownbuf then xfree(f^.buf);
  f^.buf := nil;
  f^.ownbuf := False;
  if not f^.isStd then CloseHandle(f^.h);
end;

function c_freopen(filename, mode: PAnsiChar; f: PCFile): PCFile;
var isStd: Boolean; nx, pv: PCFile;
begin
  c_fflush(f);
  isStd := f^.isStd;
  release_handle(f);
  nx := f^.next; pv := f^.prev;
  if not open_into(f, filename, mode, 0) then
  begin
    { the stream is closed on failure }
    f^.h := INVALID_HANDLE_VALUE;
    f^.canRead := False;
    f^.canWrite := False;
    f^.next := nx; f^.prev := pv;
    Exit(nil);
  end;
  f^.isStd := False;
  if isStd then ;
  f^.next := nx; f^.prev := pv;
  Result := f;
end;

function c_fclose(f: PCFile): Integer;
begin
  Result := 0;
  if f^.lastop = 2 then
    if not flush_write(f) then Result := EOF_;
  release_handle(f);
  if f^.isStd then
  begin
    { standard streams are static: keep the record, mark it closed }
    f^.canRead := False;
    f^.canWrite := False;
    Exit;
  end;
  unlink_file(f);
  xfree(f);
end;

function c_fseek(f: PCFile; offset: Integer; whence: Integer): Integer;
var hi: Longint; method: DWORD; r: DWORD; pos: Int64;
begin
  if (whence < 0) or (whence > 2) then
  begin
    errno_ := EINVAL;
    Exit(-1);
  end;
  if f^.lastop = 2 then flush_write(f);
  if (whence = SEEK_CUR) and (f^.lastop = 1) then
  begin
    { logical position = physical - unread bytes }
    offset := offset - ((f^.rlen - f^.rpos) + f^.nungot);
  end;
  f^.rpos := 0;
  f^.rlen := 0;
  f^.nungot := 0;
  f^.lastop := 0;
  f^.eof := False;
  f^.ctrlz := False;
  if f^.isDevice or f^.isPipe then
  begin
    errno_ := EINVAL;
    Exit(-1);
  end;
  case whence of
    SEEK_SET: method := FILE_BEGIN;
    SEEK_CUR: method := FILE_CURRENT;
  else
    method := FILE_END;
  end;
  if offset < 0 then hi := -1 else hi := 0;
  SetLastError(NO_ERROR);
  r := SetFilePointer(f^.h, offset, @hi, method);
  if (r = INVALID_SET_FILE_POINTER) and (GetLastError <> NO_ERROR) then
  begin
    set_oserr;
    Exit(-1);
  end;
  pos := (Int64(hi) shl 32) or r;
  if pos < 0 then
  begin
    errno_ := EINVAL;
    Exit(-1);
  end;
  Result := 0;
end;

function c_ftell(f: PCFile): Integer;
var hi: Longint; r: DWORD; pos: Int64;
begin
  if f^.isDevice or f^.isPipe then
  begin
    errno_ := EINVAL;
    Exit(-1);
  end;
  hi := 0;
  SetLastError(NO_ERROR);
  r := SetFilePointer(f^.h, 0, @hi, FILE_CURRENT);
  if (r = INVALID_SET_FILE_POINTER) and (GetLastError <> NO_ERROR) then
  begin
    set_oserr;
    Exit(-1);
  end;
  pos := (Int64(hi) shl 32) or r;
  if f^.lastop = 1 then
    pos := pos - ((f^.rlen - f^.rpos) + f^.nungot)
  else if f^.lastop = 2 then
    pos := pos + f^.wlen;
  if (pos > High(Integer)) or (pos < 0) then
  begin
    errno_ := EINVAL;
    Exit(-1);
  end;
  Result := Integer(pos);
end;

function c_setvbuf(f: PCFile; buf: PAnsiChar; mode: Integer; size: NativeUInt): Integer;
begin
  if (mode <> _IONBF) and ((size < 2) or (size > High(Integer))) then Exit(-1);
  if (mode <> _IOFBF) and (mode <> _IOLBF) and (mode <> _IONBF) then Exit(-1);
  c_fflush(f);
  if f^.ownbuf then xfree(f^.buf);
  f^.buf := nil;
  f^.ownbuf := False;
  f^.bufmode := mode;
  f^.tempbuf := False;
  if mode = _IONBF then
    f^.bufsize := INTERNAL_BUFSIZ   { written through at the end of every call }
  else
    f^.bufsize := Integer(size and not NativeUInt(1));
  Result := 0;
end;

function c_ferror(f: PCFile): Integer;
begin
  Result := Ord(f^.err);
end;

function c_feof(f: PCFile): Integer;
begin
  Result := Ord(f^.eof);
end;

procedure c_clearerr(f: PCFile);
begin
  f^.err := False;
  f^.eof := False;
end;

function c_tmpfile: PCFile;
var path: array[0..511] of AnsiChar; name: array[0..511] of AnsiChar; f: PCFile;
begin
  Result := nil;
  if GetTempPathA(SizeOf(path), @path[0]) = 0 then
  begin
    set_oserr;
    Exit;
  end;
  if GetTempFileNameA(@path[0], 't', 0, @name[0]) = 0 then
  begin
    set_oserr;
    Exit;
  end;
  f := xalloc(SizeOf(TCFile));
  if f = nil then Exit;
  if not open_into(f, @name[0], 'w+b', FILE_ATTRIBUTE_TEMPORARY or FILE_FLAG_DELETE_ON_CLOSE) then
  begin
    xfree(f);
    DeleteFileA(@name[0]);
    Exit;
  end;
  link_file(f);
  Result := f;
end;

{ ------------------------------------------------------------------ processes }

function comspec: AnsiString;
var buf: array[0..1023] of AnsiChar; n: DWORD;
begin
  n := GetEnvironmentVariableA('COMSPEC', @buf[0], SizeOf(buf));
  if (n > 0) and (n < SizeOf(buf)) then
    SetString(Result, PAnsiChar(@buf[0]), n)
  else
    Result := 'cmd.exe';
end;

function spawn_shell(const cmdline: AnsiString; hin, hout, herr: HANDLE; var pi: TProcessInformation): Boolean;
var si: TStartupInfoA; cl, shell: AnsiString;
begin
  FillChar(si, SizeOf(si), 0);
  si.cb := SizeOf(si);
  si.dwFlags := STARTF_USESTDHANDLES;
  si.hStdInput := hin;
  si.hStdOutput := hout;
  si.hStdError := herr;
  shell := comspec;
  if Pos(AnsiString(' '), shell) > 0 then
    cl := '"' + shell + '" /c ' + cmdline
  else
    cl := shell + ' /c ' + cmdline;
  UniqueString(cl);
  FillChar(pi, SizeOf(pi), 0);
  Result := CreateProcessA(nil, PAnsiChar(cl), nil, nil, True, 0, nil, nil, @si, @pi);
  if not Result then set_oserr;
end;

function c_system(command: PAnsiChar): Integer;
var pi: TProcessInformation; code: DWORD;
begin
  if command = nil then
  begin
    { is a command interpreter available? }
    if GetFileAttributesA(PAnsiChar(comspec)) <> INVALID_FILE_ATTRIBUTES then Exit(1);
    Exit(Ord(comspec = 'cmd.exe'));
  end;
  if not spawn_shell(command, GetStdHandle(STD_INPUT_HANDLE), GetStdHandle(STD_OUTPUT_HANDLE),
                     GetStdHandle(STD_ERROR_HANDLE), pi) then
    Exit(-1);
  CloseHandle(pi.hThread);
  WaitForSingleObject(pi.hProcess, INFINITE);
  code := 0;
  GetExitCodeProcess(pi.hProcess, @code);
  CloseHandle(pi.hProcess);
  Result := Integer(code);
end;

function c_popen(command, mode: PAnsiChar): PCFile;
var sa: TSecurityAttributes; hr, hw: HANDLE; pi: TProcessInformation; f: PCFile;
    reading, text: Boolean; ok: Boolean; m: PAnsiChar;
begin
  Result := nil;
  if (mode = nil) or ((mode^ <> 'r') and (mode^ <> 'w')) then
  begin
    errno_ := EINVAL;
    Exit;
  end;
  reading := mode^ = 'r';
  text := True;
  m := mode + 1;
  while m^ <> #0 do
  begin
    if m^ = 'b' then text := False else if m^ = 't' then text := True;
    Inc(m);
  end;
  sa.nLength := SizeOf(sa);
  sa.lpSecurityDescriptor := nil;
  sa.bInheritHandle := True;
  if not CreatePipe(@hr, @hw, @sa, 0) then
  begin
    set_oserr;
    Exit;
  end;
  if reading then
  begin
    SetHandleInformation(hr, HANDLE_FLAG_INHERIT, 0);
    ok := spawn_shell(command, GetStdHandle(STD_INPUT_HANDLE), hw, GetStdHandle(STD_ERROR_HANDLE), pi);
    CloseHandle(hw);
    if not ok then
    begin
      CloseHandle(hr);
      Exit;
    end;
  end
  else
  begin
    SetHandleInformation(hw, HANDLE_FLAG_INHERIT, 0);
    ok := spawn_shell(command, hr, GetStdHandle(STD_OUTPUT_HANDLE), GetStdHandle(STD_ERROR_HANDLE), pi);
    CloseHandle(hr);
    if not ok then
    begin
      CloseHandle(hw);
      Exit;
    end;
  end;
  CloseHandle(pi.hThread);
  f := xalloc(SizeOf(TCFile));
  if f = nil then
  begin
    errno_ := ENOMEM;
    Exit;
  end;
  if reading then init_file(f, hr) else init_file(f, hw);
  f^.canRead := reading;
  f^.canWrite := not reading;
  f^.isText := text;
  f^.proc := pi.hProcess;
  link_file(f);
  Result := f;
end;

function c_pclose(f: PCFile): Integer;
var proc: HANDLE; code: DWORD;
begin
  proc := f^.proc;
  if f^.lastop = 2 then flush_write(f);
  release_handle(f);
  unlink_file(f);
  xfree(f);
  if proc = 0 then
  begin
    errno_ := EINVAL;
    Exit(-1);
  end;
  if WaitForSingleObject(proc, INFINITE) = WAIT_FAILED then
  begin
    set_oserr;
    CloseHandle(proc);
    Exit(-1);
  end;
  code := 0;
  GetExitCodeProcess(proc, @code);
  CloseHandle(proc);
  Result := Integer(code);
end;

{ ------------------------------------------------------------------ misc }

function c_remove(filename: PAnsiChar): Integer;
begin
  if DeleteFileA(filename) then Result := 0
  else
  begin
    set_oserr;
    Result := -1;
  end;
end;

function c_rename(oldname, newname: PAnsiChar): Integer;
begin
  if MoveFileA(oldname, newname) then Result := 0
  else
  begin
    set_oserr;
    Result := -1;
  end;
end;

var
  tmpnam_counter: Integer = 0;
  tmpnam_buf: array[0..259] of AnsiChar;

function base32(v: Cardinal): AnsiString;
const digs: AnsiString = '0123456789abcdefghijklmnopqrstuv';
begin
  Result := '';
  repeat
    Result := digs[(v and 31) + 1] + Result;
    v := v shr 5;
  until v = 0;
end;

function c_tmpnam(buf: PAnsiChar): PAnsiChar;
var name: AnsiString; prefix: AnsiString;
{$IFDEF LUA_UCRT}
    path: array[0..259] of AnsiChar; n: DWORD;
{$ENDIF}
begin
{$IFDEF LUA_UCRT}
  n := GetTempPathA(SizeOf(path), @path[0]);
  if n = 0 then prefix := '\' else SetString(prefix, PAnsiChar(@path[0]), n);
{$ELSE}
  prefix := '\';
{$ENDIF}
  repeat
    name := prefix + 's' + base32(GetCurrentProcessId) + '.';
    if tmpnam_counter > 0 then name := name + base32(tmpnam_counter);
    Inc(tmpnam_counter);
  until GetFileAttributesA(PAnsiChar(name)) = INVALID_FILE_ATTRIBUTES;
  if buf = nil then buf := @tmpnam_buf[0];
  c_strcpy(buf, PAnsiChar(name));
  Result := buf;
end;

threadvar
  getenv_buf: PAnsiChar;

function c_getenv(name: PAnsiChar): PAnsiChar;
var n: DWORD;
begin
  n := GetEnvironmentVariableA(name, nil, 0);
  if n = 0 then Exit(nil);
  if getenv_buf <> nil then xfree(getenv_buf);
  getenv_buf := xalloc(n + 1);
  if getenv_buf = nil then Exit(nil);
  if GetEnvironmentVariableA(name, getenv_buf, n + 1) = 0 then
    getenv_buf^ := #0;
  Result := getenv_buf;
end;

procedure c_exit(code: Integer);
begin
  c_flushall;
  ExitProcess(Cardinal(code));
end;

{ ------------------------------------------------------------------ init }

var
  std_files: array[0..2] of TCFile;

procedure init_std(idx: Integer; which: DWORD; rd: Boolean);
var f: PCFile; mode: DWORD;
begin
  f := @std_files[idx];
  init_file(f, GetStdHandle(which));
  f^.isStd := True;
  f^.canRead := rd;
  f^.canWrite := not rd;
  if idx = 2 then
    f^.bufmode := _IONBF
  else if (idx = 1) and f^.isDevice and GetConsoleMode(f^.h, @mode) then
    f^.tempbuf := True;   { console stdout: flushed after every call }
  link_file(f);
end;

initialization
  heap := GetProcessHeap;
  init_std(0, STD_INPUT_HANDLE, True);
  init_std(1, STD_OUTPUT_HANDLE, False);
  init_std(2, STD_ERROR_HANDLE, False);
  c_stdin := @std_files[0];
  c_stdout := @std_files[1];
  c_stderr := @std_files[2];

finalization
  c_flushall;
{$ENDIF}

end.
