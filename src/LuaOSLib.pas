{
  Lua 5.1.4 - Pascal port of loslib.c
  Standard Operating System library

  time()/localtime()/gmtime()/mktime()/strftime()/clock() are emulated the
  way the Microsoft C runtime implements them (64-bit time_t, "C" locale
  names, time zone from the Windows settings, dates before 1970 or after
  3000 are rejected).
}
unit LuaOSLib;

{$I lua.inc}

interface

uses
  LuaTypes;

function luaopen_os(L: Plua_State): Integer; cdecl;

implementation

uses
  LuaCRT, LuaAPI, LuaAuxLib, LuaStdio,
  {$IFDEF LUA_POSIX} LuaPosix {$ELSE} LuaWin {$ENDIF};

{$IFDEF LUA_POSIX}
type
  Ttm = LuaPosix.Ttm;   { the C library's struct tm }
{$ELSE}
const
  LOCALE_USER_DEFAULT = $0400;
  LOCALE_SENGLANGUAGE = $1001;
  LOCALE_SENGCOUNTRY = $1002;

function GetLocaleInfoA(Locale: DWORD; LCType: DWORD; lpLCData: PAnsiChar; cchData: Integer): Integer; stdcall; external kernel32;
function GetACP: Cardinal; stdcall; external kernel32;
function WideCharToMultiByte(CodePage: Cardinal; dwFlags: DWORD; lpWideCharStr: PWideChar; cchWideChar: Integer;
  lpMultiByteStr: PAnsiChar; cbMultiByte: Integer; lpDefaultChar: PAnsiChar; lpUsedDefaultChar: Pointer): Integer; stdcall; external kernel32;

type
  Ttm = record
    tm_sec, tm_min, tm_hour, tm_mday, tm_mon, tm_year, tm_wday, tm_yday, tm_isdst: Integer;
  end;
  Ptm = ^Ttm;

const
  MAX_TIME64 = Int64(32535215999);   { 3000-12-31 23:59:59 UTC }
{$ENDIF}

function os_pushresult(L: Plua_State; i: Boolean; filename: PAnsiChar): Integer;
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
    lua_pushfstringf(L, '%s: %s', [filename, c_strerror(en)]);
    lua_pushinteger(L, en);
    Result := 3;
  end;
end;

function os_execute(L: Plua_State): Integer; cdecl;
begin
  lua_pushinteger(L, c_system(luaL_optstring(L, 1, nil)));
  Result := 1;
end;

function os_remove(L: Plua_State): Integer; cdecl;
var filename: PAnsiChar;
begin
  filename := luaL_checkstring(L, 1);
  Result := os_pushresult(L, c_remove(filename) = 0, filename);
end;

function os_rename(L: Plua_State): Integer; cdecl;
var fromname, toname: PAnsiChar;
begin
  fromname := luaL_checkstring(L, 1);
  toname := luaL_checkstring(L, 2);
  Result := os_pushresult(L, c_rename(fromname, toname) = 0, fromname);
end;

function os_tmpname(L: Plua_State): Integer; cdecl;
var buff: array[0..259] of AnsiChar;
begin
  if c_tmpnam(@buff[0]) = nil then
    Exit(luaL_errorf(L, 'unable to generate a unique filename', []));
  lua_pushstring(L, @buff[0]);
  Result := 1;
end;

function os_getenv(L: Plua_State): Integer; cdecl;
begin
  lua_pushstring(L, c_getenv(luaL_checkstring(L, 1)));  { if NULL push nil }
  Result := 1;
end;

{$IFDEF LUA_POSIX}
const
  CLOCKS_PER_SEC = 1000000;

function c_clock: Int64;
begin
  Result := px_clock;
end;
{$ELSE}
const
  CLOCKS_PER_SEC = 1000;

{ clock(): the MS C runtime returns the wall-clock time elapsed since the
  process started, in milliseconds (CLOCKS_PER_SEC = 1000) }
function c_clock: Int64;
var creation, dummy1, dummy2, dummy3, now: TFileTime; c, n: Int64;
begin
  if not GetProcessTimes(GetCurrentProcess, @creation, @dummy1, @dummy2, @dummy3) then
    Exit(-1);
  GetSystemTimeAsFileTime(@now);
  c := (Int64(creation.dwHighDateTime) shl 32) or creation.dwLowDateTime;
  n := (Int64(now.dwHighDateTime) shl 32) or now.dwLowDateTime;
  Result := (n - c) div 10000;
end;

{$ENDIF}

function os_clock(L: Plua_State): Integer; cdecl;
begin
  lua_pushnumber(L, c_clock / CLOCKS_PER_SEC);
  Result := 1;
end;
{$IFDEF LUA_POSIX}
{ ======================================================
  Time/Date operations: the C library's time, localtime, gmtime, mktime,
  strftime (TZ and the zoneinfo database apply, as in the C build)
  ======================================================= }

function c_time: Int64;
begin
  Result := px_time(nil);
end;

function c_gmtime(t: Int64; var tm: Ttm): Boolean;
begin
  Result := px_gmtime_r(@t, @tm) <> nil;
end;

function c_localtime(t: Int64; var tm: Ttm): Boolean;
begin
  Result := px_localtime_r(@t, @tm) <> nil;
end;

function c_mktime(var tm: Ttm): Int64;
begin
  Result := px_mktime(@tm);
end;

{ strftime(buff, 200, "%<conv>", tm) }
function strftime1(conv: AnsiChar; alt: Boolean; var tm: Ttm): AnsiString;
var cc: array[0..2] of AnsiChar; buff: array[0..199] of AnsiChar; n: NativeUInt;
begin
  cc[0] := '%'; cc[1] := conv; cc[2] := #0;
  n := px_strftime(@buff[0], SizeOf(buff), @cc[0], @tm);
  SetString(Result, PAnsiChar(@buff[0]), n);
end;

{$ELSE}

{ ======================================================
  Time/Date operations
  ======================================================= }

const
  EPOCH_DIFF = Int64(116444736000000000);  { 1601 -> 1970 in 100ns units }

function c_time: Int64;
var ft: TFileTime; v: Int64;
begin
  GetSystemTimeAsFileTime(@ft);
  v := (Int64(ft.dwHighDateTime) shl 32) or ft.dwLowDateTime;
  Result := (v - EPOCH_DIFF) div 10000000;
end;

function floordiv(a, b: Int64): Int64;
begin
  Result := a div b;
  if ((a mod b) <> 0) and ((a < 0) <> (b < 0)) then Dec(Result);
end;

{ days since 1970-01-01 of a proleptic Gregorian date (month 1..12) }
function days_from_civil(y, m, d: Int64): Int64;
var era, yoe, doy, doe: Int64;
begin
  if m <= 2 then y := y - 1;
  era := floordiv(y, 400);
  yoe := y - era * 400;
  if m > 2 then doy := (153 * (m - 3) + 2) div 5 + d - 1
  else doy := (153 * (m + 9) + 2) div 5 + d - 1;
  doe := yoe * 365 + yoe div 4 - yoe div 100 + doy;
  Result := era * 146097 + doe - 719468;
end;

function is_leap(y: Integer): Boolean;
begin
  Result := ((y mod 4 = 0) and (y mod 100 <> 0)) or (y mod 400 = 0);
end;

{ broken-down time of t seconds since the epoch (as UTC) }
procedure secs_to_tm(t: Int64; var tm: Ttm);
var days, secs, z, era, doe, yoe, y, doy, mp, d, m: Int64;
begin
  days := floordiv(t, 86400);
  secs := t - days * 86400;
  tm.tm_hour := Integer(secs div 3600);
  tm.tm_min := Integer((secs mod 3600) div 60);
  tm.tm_sec := Integer(secs mod 60);
  tm.tm_wday := Integer((days + 4) mod 7);  { 1970-01-01 was a Thursday }
  if tm.tm_wday < 0 then Inc(tm.tm_wday, 7);
  z := days + 719468;
  era := floordiv(z, 146097);
  doe := z - era * 146097;
  yoe := (doe - doe div 1460 + doe div 36524 - doe div 146096) div 365;
  y := yoe + era * 400;
  doy := doe - (365 * yoe + yoe div 4 - yoe div 100);
  mp := (5 * doy + 2) div 153;
  d := doy - (153 * mp + 2) div 5 + 1;
  if mp < 10 then m := mp + 3 else m := mp - 9;
  if m <= 2 then y := y + 1;
  tm.tm_year := Integer(y - 1900);
  tm.tm_mon := Integer(m - 1);
  tm.tm_mday := Integer(d);
  tm.tm_yday := Integer(days - days_from_civil(y, 1, 1));
  tm.tm_isdst := 0;
end;

{ ---- time zone (from the Windows settings, as the MS C runtime does) ---- }

var
  tz_loaded: Boolean = False;
  tz_info: TTimeZoneInformation;
  tz_timezone: Integer;   { seconds west of UTC (standard time) }
  tz_dstbias: Integer;    { seconds; usually -3600 }
  tz_hasdst: Boolean;
  tz_names: array[0..1] of AnsiString;

procedure load_tz;
var r: DWORD; buf: array[0..127] of AnsiChar; n: Integer;
begin
  if tz_loaded then Exit;
  tz_loaded := True;
  FillChar(tz_info, SizeOf(tz_info), 0);
  r := GetTimeZoneInformation(@tz_info);
  if r = TIME_ZONE_ID_INVALID then
  begin
    tz_timezone := 0;
    tz_dstbias := 0;
    tz_hasdst := False;
    tz_names[0] := '';
    tz_names[1] := '';
    Exit;
  end;
  tz_timezone := (tz_info.Bias + tz_info.StandardBias) * 60;
  tz_dstbias := (tz_info.DaylightBias - tz_info.StandardBias) * 60;
  tz_hasdst := (tz_info.DaylightDate.wMonth <> 0) and (tz_info.DaylightBias <> tz_info.StandardBias);
  n := WideCharToMultiByte(0, 0, @tz_info.StandardName[0], -1, @buf[0], SizeOf(buf), nil, nil);
  if n > 0 then tz_names[0] := PAnsiChar(@buf[0]) else tz_names[0] := '';
  n := WideCharToMultiByte(0, 0, @tz_info.DaylightName[0], -1, @buf[0], SizeOf(buf), nil, nil);
  if n > 0 then tz_names[1] := PAnsiChar(@buf[0]) else tz_names[1] := '';
end;

const
  days_in_month: array[0..11] of Integer = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);

{ day of year (0-based) and time in ms of a transition rule in a given year }
procedure transition(year: Integer; const st: TSystemTime; out yday: Integer; out ms: Int64);
var mon, dim, first_wday, day, jan1: Integer; days: Int64;
begin
  mon := st.wMonth - 1;
  if st.wYear = 0 then
  begin
    { day-in-month format: wDay = occurrence (5 = last) of wDayOfWeek }
    days := days_from_civil(year, mon + 1, 1);
    first_wday := Integer((days + 4) mod 7);
    if first_wday < 0 then Inc(first_wday, 7);
    day := 1 + ((st.wDayOfWeek - first_wday + 7) mod 7) + (st.wDay - 1) * 7;
    dim := days_in_month[mon];
    if (mon = 1) and is_leap(year) then dim := 29;
    while day > dim do Dec(day, 7);
  end
  else
    day := st.wDay;
  jan1 := 0;
  yday := Integer(days_from_civil(year, mon + 1, day) - days_from_civil(year, 1, 1)) + jan1;
  ms := ((Int64(st.wHour) * 60 + st.wMinute) * 60 + st.wSecond) * 1000 + st.wMilliseconds;
end;

{ is the given broken-down *standard* local time within daylight saving time? }
function isindst(const tm: Ttm): Boolean;
var syday, eyday: Integer; sms, ems, ms: Int64; year: Integer;
begin
  load_tz;
  if not tz_hasdst then Exit(False);
  year := tm.tm_year + 1900;
  transition(year, tz_info.DaylightDate, syday, sms);
  transition(year, tz_info.StandardDate, eyday, ems);
  { the end transition is expressed in daylight time: convert to standard }
  ems := ems + Int64(tz_dstbias) * 1000;
  while ems < 0 do
  begin
    Inc(ems, 86400000);
    Dec(eyday);
  end;
  while ems >= 86400000 do
  begin
    Dec(ems, 86400000);
    Inc(eyday);
  end;
  ms := ((Int64(tm.tm_hour) * 60 + tm.tm_min) * 60 + tm.tm_sec) * 1000;
  if (syday < eyday) or ((syday = eyday) and (sms < ems)) then
  begin  { northern hemisphere }
    if (tm.tm_yday < syday) or (tm.tm_yday > eyday) then Exit(False);
    if (tm.tm_yday > syday) and (tm.tm_yday < eyday) then Exit(True);
    if tm.tm_yday = syday then
    begin
      if tm.tm_yday = eyday then Exit((ms >= sms) and (ms < ems));
      Exit(ms >= sms);
    end;
    Exit(ms < ems);
  end
  else
  begin  { southern hemisphere: DST spans the new year }
    if (tm.tm_yday < eyday) or (tm.tm_yday > syday) then Exit(True);
    if (tm.tm_yday > eyday) and (tm.tm_yday < syday) then Exit(False);
    if tm.tm_yday = eyday then Exit(ms < ems);
    Exit(ms >= sms);
  end;
end;

function c_gmtime(t: Int64; var tm: Ttm): Boolean;
begin
  if (t < 0) or (t > MAX_TIME64) then Exit(False);
  secs_to_tm(t, tm);
  Result := True;
end;

function c_localtime(t: Int64; var tm: Ttm): Boolean;
var lt: Int64;
begin
  if (t < 0) or (t > MAX_TIME64) then Exit(False);
  load_tz;
  lt := t - tz_timezone;
  secs_to_tm(lt, tm);
  if isindst(tm) then
  begin
    lt := lt - tz_dstbias;
    secs_to_tm(lt, tm);
    tm.tm_isdst := 1;
  end
  else
    tm.tm_isdst := 0;
  Result := True;
end;

function c_mktime(var tm: Ttm): Int64;
var y, m, t, days: Int64; ntm: Ttm;
begin
  load_tz;
  { normalize month/year, then everything else through the seconds count }
  y := Int64(tm.tm_year) + 1900;
  m := tm.tm_mon;
  y := y + floordiv(m, 12);
  m := m - floordiv(m, 12) * 12;
  days := days_from_civil(y, m + 1, 1) + (tm.tm_mday - 1);
  t := days * 86400 + Int64(tm.tm_hour) * 3600 + Int64(tm.tm_min) * 60 + tm.tm_sec;
  { t is now the local (wall clock) time as if it were UTC }
  secs_to_tm(t, ntm);
  t := t + tz_timezone;
  if tm.tm_isdst > 0 then
    t := t + tz_dstbias
  else if (tm.tm_isdst < 0) and isindst(ntm) then
    t := t + tz_dstbias;
  if (t < 0) or (t > MAX_TIME64) then Exit(-1);
  c_localtime(t, tm);
  Result := t;
end;

{ ---- strftime, "C" locale ---- }

const
  wday_abbr: array[0..6] of AnsiString = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
  wday_full: array[0..6] of AnsiString = ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday');
  mon_abbr: array[0..11] of AnsiString = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
  mon_full: array[0..11] of AnsiString = ('January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December');

function num2(v: Integer; alt: Boolean): AnsiString;
begin
  if alt then
  begin
    Result := c_itoa(v);
    Exit;
  end;
  Result := AnsiChar(Ord('0') + (v div 10) mod 10) + AnsiChar(Ord('0') + v mod 10);
end;

function num3(v: Integer; alt: Boolean): AnsiString;
begin
  if alt then
  begin
    Result := c_itoa(v);
    Exit;
  end;
  Result := AnsiChar(Ord('0') + (v div 100) mod 10) + AnsiChar(Ord('0') + (v div 10) mod 10) +
            AnsiChar(Ord('0') + v mod 10);
end;

function strftime1(conv: AnsiChar; alt: Boolean; const tm: Ttm): AnsiString;
var h, wk: Integer; s: AnsiString;
begin
  case conv of
    'a': Result := wday_abbr[tm.tm_wday];
    'A': Result := wday_full[tm.tm_wday];
    'b': Result := mon_abbr[tm.tm_mon];
    'B': Result := mon_full[tm.tm_mon];
    'c':
      if alt then
        Result := strftime1('x', True, tm) + ' ' + strftime1('X', False, tm)
      else
        Result := strftime1('x', False, tm) + ' ' + strftime1('X', False, tm);
    'd': Result := num2(tm.tm_mday, alt);
    'H': Result := num2(tm.tm_hour, alt);
    'I':
      begin
        h := tm.tm_hour mod 12;
        if h = 0 then h := 12;
        Result := num2(h, alt);
      end;
    'j': Result := num3(tm.tm_yday + 1, alt);
    'm': Result := num2(tm.tm_mon + 1, alt);
    'M': Result := num2(tm.tm_min, alt);
    'p': if tm.tm_hour < 12 then Result := 'AM' else Result := 'PM';
    'S': Result := num2(tm.tm_sec, alt);
    'U':
      begin
        wk := (tm.tm_yday + 7 - tm.tm_wday) div 7;
        Result := num2(wk, alt);
      end;
    'w': begin s := c_itoa(tm.tm_wday); Result := s; end;
    'W':
      begin
        wk := (tm.tm_yday + 7 - ((tm.tm_wday + 6) mod 7)) div 7;
        Result := num2(wk, alt);
      end;
    'x':
      if alt then
      begin
        s := c_itoa(tm.tm_mday);
        Result := wday_full[tm.tm_wday] + ', ' + mon_full[tm.tm_mon] + ' ' + s + ', ';
        s := c_itoa(tm.tm_year + 1900);
        Result := Result + s;
      end
      else
        Result := num2(tm.tm_mon + 1, False) + '/' + num2(tm.tm_mday, False) + '/' +
                  num2((tm.tm_year + 1900) mod 100, False);
    'X': Result := num2(tm.tm_hour, alt) + ':' + num2(tm.tm_min, alt) + ':' + num2(tm.tm_sec, alt);
    'y': Result := num2((tm.tm_year + 1900) mod 100, alt);
    'Y': begin s := c_itoa(tm.tm_year + 1900); Result := s; end;
    'z', 'Z':
      begin
        load_tz;
        if tm.tm_isdst > 0 then Result := tz_names[1] else Result := tz_names[0];
      end;
    '%': Result := '%';
  else
    Result := '';  { invalid conversion: nothing }
  end;
end;

{ ---- os.date / os.time / os.difftime ---- }

{$ENDIF}

procedure setfield(L: Plua_State; key: PAnsiChar; value: Integer);
begin
  lua_pushinteger(L, value);
  lua_setfield(L, -2, key);
end;

procedure setboolfield(L: Plua_State; key: PAnsiChar; value: Integer);
begin
  if value < 0 then  { undefined? }
    Exit;  { does not set field }
  lua_pushboolean(L, value);
  lua_setfield(L, -2, key);
end;

function getboolfield(L: Plua_State; key: PAnsiChar): Integer;
var res: Integer;
begin
  lua_getfield(L, -1, key);
  if lua_isnil(L, -1) then res := -1 else res := lua_toboolean(L, -1);
  lua_pop(L, 1);
  Result := res;
end;

function getfield(L: Plua_State; key: PAnsiChar; d: Integer): Integer;
var res: Integer;
begin
  lua_getfield(L, -1, key);
  if lua_isnumber(L, -1) <> 0 then
    res := Integer(lua_tointeger(L, -1))
  else
  begin
    if d < 0 then
      Exit(luaL_errorf(L, 'field ''%s'' missing in date table', [key]));
    res := d;
  end;
  lua_pop(L, 1);
  Result := res;
end;

function double2time(d: lua_Number): Int64;
begin
  if luai_numisnan(d) or not ((d > -9223372036854775808.0) and (d < 9223372036854775808.0)) then
    Result := -9223372036854775807 - 1
  else
    Result := Trunc(d);
end;

function os_date(L: Plua_State): Integer; cdecl;
var s: PAnsiChar; t: Int64; stm: Ttm; ok, alt: Boolean; b: luaL_Buffer; res: AnsiString;
begin
  s := luaL_optstring(L, 1, '%c');
  if lua_isnoneornil(L, 2) then t := c_time
  else t := double2time(luaL_checknumber(L, 2));
  if s^ = '!' then
  begin  { UTC? }
    ok := c_gmtime(t, stm);
    Inc(s);  { skip `!' }
  end
  else
    ok := c_localtime(t, stm);
  if not ok then  { invalid date? }
    lua_pushnil(L)
  else if c_strcmp(s, '*t') = 0 then
  begin
    lua_createtable(L, 0, 9);  { 9 = number of fields }
    setfield(L, 'sec', stm.tm_sec);
    setfield(L, 'min', stm.tm_min);
    setfield(L, 'hour', stm.tm_hour);
    setfield(L, 'day', stm.tm_mday);
    setfield(L, 'month', stm.tm_mon + 1);
    setfield(L, 'year', stm.tm_year + 1900);
    setfield(L, 'wday', stm.tm_wday + 1);
    setfield(L, 'yday', stm.tm_yday + 1);
    setboolfield(L, 'isdst', stm.tm_isdst);
  end
  else
  begin
    luaL_buffinit(L, @b);
    while s^ <> #0 do
    begin
      if (s^ <> '%') or ((s + 1)^ = #0) then
        luaL_addchar(@b, s^)
      else
      begin
        Inc(s);
        alt := False;
{$IFDEF LUA_POSIX}
        res := strftime1(s^, alt, stm);
{$ELSE}
        if s^ = '#' then
        begin
          { cc = "%#": an incomplete specification produces nothing }
          res := '';
        end
        else
          res := strftime1(s^, alt, stm);
{$ENDIF}
        if Length(res) > 199 then SetLength(res, 0);  { buffer overflow -> 0 }
        if Length(res) > 0 then
          luaL_addlstring(@b, PAnsiChar(res), Length(res));
      end;
      Inc(s);
    end;
    luaL_pushresult(@b);
  end;
  Result := 1;
end;

function os_time(L: Plua_State): Integer; cdecl;
var t: Int64; ts: Ttm;
begin
  if lua_isnoneornil(L, 1) then  { called without args? }
    t := c_time  { get current time }
  else
  begin
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_settop(L, 1);  { make sure table is at the top }
    FillChar(ts, SizeOf(ts), 0);
    ts.tm_sec := getfield(L, 'sec', 0);
    ts.tm_min := getfield(L, 'min', 0);
    ts.tm_hour := getfield(L, 'hour', 12);
    ts.tm_mday := getfield(L, 'day', -1);
    ts.tm_mon := getfield(L, 'month', -1) - 1;
    ts.tm_year := getfield(L, 'year', -1) - 1900;
    ts.tm_isdst := getboolfield(L, 'isdst');
    t := c_mktime(ts);
  end;
  if t = -1 then
    lua_pushnil(L)
  else
    lua_pushnumber(L, t);
  Result := 1;
end;

function os_difftime(L: Plua_State): Integer; cdecl;
var t1, t2: Int64;
begin
  t1 := double2time(luaL_checknumber(L, 1));
  t2 := double2time(luaL_optnumber(L, 2, 0));
  lua_pushnumber(L, t1 - t2);
  Result := 1;
end;

{ ====================================================== }

{$IFDEF LUA_POSIX}
const
  catnames: array[0..6] of PAnsiChar = ('all', 'collate', 'ctype', 'monetary', 'numeric', 'time', nil);
  { LC_ALL, LC_COLLATE, LC_CTYPE, LC_MONETARY, LC_NUMERIC, LC_TIME }
{$IFDEF DARWIN}
  cat: array[0..5] of Integer = (0, 1, 2, 3, 4, 5);
{$ELSE}
  cat: array[0..5] of Integer = (6, 3, 0, 4, 1, 2);   { glibc }
{$ENDIF}

function c_setlocale(op: Integer; l: PAnsiChar): PAnsiChar;
begin
  Result := px_setlocale(cat[op], l);
end;

{$ELSE}
const
  LC_ALL = 0; LC_COLLATE = 1; LC_CTYPE = 2; LC_MONETARY = 3; LC_NUMERIC = 4; LC_TIME = 5;
  catnames: array[0..6] of PAnsiChar = ('all', 'collate', 'ctype', 'monetary', 'numeric', 'time', nil);
  lc_names: array[1..5] of AnsiString = ('LC_COLLATE', 'LC_CTYPE', 'LC_MONETARY', 'LC_NUMERIC', 'LC_TIME');

var
  cur_locale: array[1..5] of AnsiString;
  locale_result: AnsiString;

function native_locale_name: AnsiString;
var lang, country: array[0..127] of AnsiChar; cp: AnsiString;
begin
  if GetLocaleInfoA(LOCALE_USER_DEFAULT, LOCALE_SENGLANGUAGE, @lang[0], SizeOf(lang)) = 0 then
    lang[0] := #0;
  if GetLocaleInfoA(LOCALE_USER_DEFAULT, LOCALE_SENGCOUNTRY, @country[0], SizeOf(country)) = 0 then
    country[0] := #0;
  cp := c_itoa(GetACP);
  Result := AnsiString(PAnsiChar(@lang[0])) + '_' + AnsiString(PAnsiChar(@country[0])) + '.' + cp;
end;

{ Only the "C" locale is really implemented; "" (the user's locale) is
  accepted and reported by name, but character classification, collation
  and number formatting keep their "C" behaviour. }
function c_setlocale(cat: Integer; l: PAnsiChar): PAnsiChar;
var i: Integer; name: AnsiString; same: Boolean;
begin
  for i := 1 to 5 do
    if cur_locale[i] = '' then cur_locale[i] := 'C';
  if l <> nil then
  begin
    if l^ = #0 then name := native_locale_name
    else if c_strcmp(l, 'C') = 0 then name := 'C'
    else Exit(nil);
    if cat = LC_ALL then
      for i := 1 to 5 do cur_locale[i] := name
    else
      cur_locale[cat] := name;
  end;
  if cat = LC_ALL then
  begin
    same := True;
    for i := 2 to 5 do
      if cur_locale[i] <> cur_locale[1] then same := False;
    if same then locale_result := cur_locale[1]
    else
    begin
      locale_result := '';
      for i := 1 to 5 do
      begin
        if i > 1 then locale_result := locale_result + ';';
        locale_result := locale_result + lc_names[i] + '=' + cur_locale[i];
      end;
    end;
  end
  else
    locale_result := cur_locale[cat];
  Result := PAnsiChar(locale_result);
end;

{$ENDIF}

function os_setlocale(L: Plua_State): Integer; cdecl;
var l_: PAnsiChar; op: Integer;
begin
  l_ := luaL_optstring(L, 1, nil);
  op := luaL_checkoption(L, 2, 'all', @catnames[0]);
  lua_pushstring(L, c_setlocale(op, l_));
  Result := 1;
end;

function os_exit(L: Plua_State): Integer; cdecl;
begin
  c_exit(luaL_optint(L, 1, 0));
  Result := 0;
end;

const
  syslib: array[0..11] of luaL_Reg = (
    (name: 'clock'; func: os_clock),
    (name: 'date'; func: os_date),
    (name: 'difftime'; func: os_difftime),
    (name: 'execute'; func: os_execute),
    (name: 'exit'; func: os_exit),
    (name: 'getenv'; func: os_getenv),
    (name: 'remove'; func: os_remove),
    (name: 'rename'; func: os_rename),
    (name: 'setlocale'; func: os_setlocale),
    (name: 'time'; func: os_time),
    (name: 'tmpname'; func: os_tmpname),
    (name: nil; func: nil));

function luaopen_os(L: Plua_State): Integer; cdecl;
begin
  luaL_register(L, LUA_OSLIBNAME, @syslib[0]);
  Result := 1;
end;

end.
