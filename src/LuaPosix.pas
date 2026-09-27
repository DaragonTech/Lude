{
  Lua 5.1.4 - Pascal port: C library imports for POSIX systems (Linux, macOS).

  On Windows the port emulates the Microsoft C runtime in Pascal; on
  Linux it uses the system C library directly, like the C build of Lua
  does (luaconf.h with LUA_USE_POSIX + LUA_USE_DLOPEN): stdio streams are
  real FILE*s, memory comes from malloc, C modules are loaded with dlopen,
  and the math functions are libm's.
}
unit LuaPosix;

{$I lua.inc}

interface

{$IFDEF LUA_POSIX}

const
{$IFDEF FPC}
  libc = 'c';
  libm = 'm';
  libdl = 'dl';
{$ELSE}
  libc = 'libc.so.6';
  libm = 'libm.so.6';
  libdl = 'libdl.so.2';
{$ENDIF}

type
  PFILE = Pointer;
  time_t = Int64;
  Ptime_t = ^time_t;
  clock_t = NativeInt;

  { struct tm (glibc and macOS, 64-bit) }
  Ptm = ^Ttm;
  Ttm = record
    tm_sec, tm_min, tm_hour, tm_mday, tm_mon, tm_year, tm_wday, tm_yday, tm_isdst: Integer;
    tm_gmtoff: NativeInt;
    tm_zone: PAnsiChar;
  end;

{ memory }
function px_malloc(size: NativeUInt): Pointer; cdecl; external libc name 'malloc';
function px_realloc(p: Pointer; size: NativeUInt): Pointer; cdecl; external libc name 'realloc';
procedure px_free(p: Pointer); cdecl; external libc name 'free';

{ stdio }
function px_fopen(filename, mode: PAnsiChar): PFILE; cdecl; external libc name 'fopen';
function px_freopen(filename, mode: PAnsiChar; f: PFILE): PFILE; cdecl; external libc name 'freopen';
function px_fclose(f: PFILE): Integer; cdecl; external libc name 'fclose';
function px_fread(ptr: Pointer; size, n: NativeUInt; f: PFILE): NativeUInt; cdecl; external libc name 'fread';
function px_fwrite(ptr: Pointer; size, n: NativeUInt; f: PFILE): NativeUInt; cdecl; external libc name 'fwrite';
function px_fputs(s: PAnsiChar; f: PFILE): Integer; cdecl; external libc name 'fputs';
function px_fgets(buf: PAnsiChar; n: Integer; f: PFILE): PAnsiChar; cdecl; external libc name 'fgets';
function px_getc(f: PFILE): Integer; cdecl; external libc name 'getc';
function px_ungetc(c: Integer; f: PFILE): Integer; cdecl; external libc name 'ungetc';
function px_fflush(f: PFILE): Integer; cdecl; external libc name 'fflush';
function px_fseek(f: PFILE; offset: NativeInt; whence: Integer): Integer; cdecl; external libc name 'fseek';
function px_ftell(f: PFILE): NativeInt; cdecl; external libc name 'ftell';
function px_setvbuf(f: PFILE; buf: PAnsiChar; mode: Integer; size: NativeUInt): Integer; cdecl; external libc name 'setvbuf';
function px_ferror(f: PFILE): Integer; cdecl; external libc name 'ferror';
function px_feof(f: PFILE): Integer; cdecl; external libc name 'feof';
procedure px_clearerr(f: PFILE); cdecl; external libc name 'clearerr';
function px_tmpfile: PFILE; cdecl; external libc name 'tmpfile';
function px_popen(command, mode: PAnsiChar): PFILE; cdecl; external libc name 'popen';
function px_pclose(f: PFILE): Integer; cdecl; external libc name 'pclose';
function px_fscanf(f: PFILE; fmt: PAnsiChar): Integer; cdecl; varargs; external libc name 'fscanf';
function px_remove(filename: PAnsiChar): Integer; cdecl; external libc name 'remove';
function px_rename(oldname, newname: PAnsiChar): Integer; cdecl; external libc name 'rename';
function px_isatty(fd: Integer): Integer; cdecl; external libc name 'isatty';
function px_fileno(f: PFILE): Integer; cdecl; external libc name 'fileno';

{ stdlib / errno / string }
function px_getenv(name: PAnsiChar): PAnsiChar; cdecl; external libc name 'getenv';
function px_system(command: PAnsiChar): Integer; cdecl; external libc name 'system';
procedure px_exit(code: Integer); cdecl; external libc name 'exit';
{$IFDEF DARWIN}
function px_errno_location: PInteger; cdecl; external libc name '__error';
{$ELSE}
function px_errno_location: PInteger; cdecl; external libc name '__errno_location';
{$ENDIF}
function px_strerror(e: Integer): PAnsiChar; cdecl; external libc name 'strerror';
function px_mkstemp(template: PAnsiChar): Integer; cdecl; external libc name 'mkstemp';
function px_close(fd: Integer): Integer; cdecl; external libc name 'close';
function px_rand: Integer; cdecl; external libc name 'rand';
procedure px_srand(seed: Cardinal); cdecl; external libc name 'srand';

{ time }
function px_time(t: Ptime_t): time_t; cdecl; external libc name 'time';
function px_clock: clock_t; cdecl; external libc name 'clock';
function px_localtime_r(t: Ptime_t; res: Ptm): Ptm; cdecl; external libc name 'localtime_r';
function px_gmtime_r(t: Ptime_t; res: Ptm): Ptm; cdecl; external libc name 'gmtime_r';
function px_mktime(tm: Ptm): time_t; cdecl; external libc name 'mktime';
function px_strftime(s: PAnsiChar; max: NativeUInt; format: PAnsiChar; tm: Ptm): NativeUInt; cdecl; external libc name 'strftime';
function px_setlocale(category: Integer; locale: PAnsiChar): PAnsiChar; cdecl; external libc name 'setlocale';

{ dynamic libraries }
function px_dlopen(filename: PAnsiChar; flags: Integer): Pointer; cdecl; external libdl name 'dlopen';
function px_dlsym(handle: Pointer; symbol: PAnsiChar): Pointer; cdecl; external libdl name 'dlsym';
function px_dlclose(handle: Pointer): Integer; cdecl; external libdl name 'dlclose';
function px_dlerror: PAnsiChar; cdecl; external libdl name 'dlerror';

{ libm }
function px_sin(x: Double): Double; cdecl; external libm name 'sin';
function px_cos(x: Double): Double; cdecl; external libm name 'cos';
function px_tan(x: Double): Double; cdecl; external libm name 'tan';
function px_asin(x: Double): Double; cdecl; external libm name 'asin';
function px_acos(x: Double): Double; cdecl; external libm name 'acos';
function px_atan(x: Double): Double; cdecl; external libm name 'atan';
function px_atan2(y, x: Double): Double; cdecl; external libm name 'atan2';
function px_sinh(x: Double): Double; cdecl; external libm name 'sinh';
function px_cosh(x: Double): Double; cdecl; external libm name 'cosh';
function px_tanh(x: Double): Double; cdecl; external libm name 'tanh';
function px_exp(x: Double): Double; cdecl; external libm name 'exp';
function px_log(x: Double): Double; cdecl; external libm name 'log';
function px_log10(x: Double): Double; cdecl; external libm name 'log10';
function px_pow(x, y: Double): Double; cdecl; external libm name 'pow';
function px_sqrt(x: Double): Double; cdecl; external libm name 'sqrt';
function px_fmod(x, y: Double): Double; cdecl; external libm name 'fmod';
function px_floor(x: Double): Double; cdecl; external libm name 'floor';
function px_ceil(x: Double): Double; cdecl; external libm name 'ceil';
function px_frexp(x: Double; e: PInteger): Double; cdecl; external libm name 'frexp';
function px_ldexp(x: Double; e: Integer): Double; cdecl; external libm name 'ldexp';
function px_modf(x: Double; ip: PDouble): Double; cdecl; external libm name 'modf';

const
  RTLD_LAZY = 1;
  RTLD_NOW = 2;
  RTLD_GLOBAL = $100;

{ the C library's stdin/stdout/stderr (the FILE* variables, looked up
  with dlsym so no compiler-specific external-variable syntax is needed) }
function libc_stdin: PFILE;
function libc_stdout: PFILE;
function libc_stderr: PFILE;

{$ENDIF}

implementation

{$IFDEF LUA_POSIX}
function stdvar(name: PAnsiChar): PFILE;
var p: ^PFILE;
begin
{$IFDEF DARWIN}
  p := px_dlsym(Pointer(-2), name);   { RTLD_DEFAULT on macOS }
{$ELSE}
  p := px_dlsym(nil, name);   { RTLD_DEFAULT }
{$ENDIF}
  if p <> nil then Result := p^ else Result := nil;
end;

{$IFDEF DARWIN}
function libc_stdin: PFILE; begin Result := stdvar('__stdinp'); end;
function libc_stdout: PFILE; begin Result := stdvar('__stdoutp'); end;
function libc_stderr: PFILE; begin Result := stdvar('__stderrp'); end;
{$ELSE}
function libc_stdin: PFILE; begin Result := stdvar('stdin'); end;
function libc_stdout: PFILE; begin Result := stdvar('stdout'); end;
function libc_stderr: PFILE; begin Result := stdvar('stderr'); end;
{$ENDIF}
{$ENDIF}

end.
