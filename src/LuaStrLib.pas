{
  Lua 5.1.4 - Pascal port of lstrlib.c
  Standard library for string operations and pattern-matching
}
unit LuaStrLib;

{$I lua.inc}

interface

uses
  LuaTypes;

function luaopen_string(L: Plua_State): Integer; cdecl;

implementation

uses
  LuaCRT, LuaAPI, LuaAuxLib;

function str_len(L: Plua_State): Integer; cdecl;
var len: size_t;
begin
  luaL_checklstring(L, 1, @len);
  lua_pushinteger(L, lua_Integer(len));
  Result := 1;
end;

function posrelat(pos: ptrdiff_t; len: size_t): ptrdiff_t;
begin
  { relative string position: negative means back from end }
  if pos < 0 then pos := pos + ptrdiff_t(len) + 1;
  if pos >= 0 then Result := pos else Result := 0;
end;

function str_sub(L: Plua_State): Integer; cdecl;
var len: size_t; s: PAnsiChar; start, end_: ptrdiff_t;
begin
  s := luaL_checklstring(L, 1, @len);
  start := posrelat(luaL_checkinteger(L, 2), len);
  end_ := posrelat(luaL_optinteger(L, 3, -1), len);
  if start < 1 then start := 1;
  if end_ > ptrdiff_t(len) then end_ := ptrdiff_t(len);
  if start <= end_ then
    lua_pushlstring(L, s + start - 1, end_ - start + 1)
  else
    lua_pushlstring(L, '', 0);
  Result := 1;
end;

function str_reverse(L: Plua_State): Integer; cdecl;
var len: size_t; b: luaL_Buffer; s: PAnsiChar;
begin
  s := luaL_checklstring(L, 1, @len);
  luaL_buffinit(L, @b);
  while len > 0 do
  begin
    Dec(len);
    luaL_addchar(@b, s[len]);
  end;
  luaL_pushresult(@b);
  Result := 1;
end;

function str_lower(L: Plua_State): Integer; cdecl;
var len, i: size_t; b: luaL_Buffer; s: PAnsiChar;
begin
  s := luaL_checklstring(L, 1, @len);
  luaL_buffinit(L, @b);
  i := 0;
  while i < len do
  begin
    luaL_addchar(@b, AnsiChar(c_tolower(Byte(s[i]))));
    Inc(i);
  end;
  luaL_pushresult(@b);
  Result := 1;
end;

function str_upper(L: Plua_State): Integer; cdecl;
var len, i: size_t; b: luaL_Buffer; s: PAnsiChar;
begin
  s := luaL_checklstring(L, 1, @len);
  luaL_buffinit(L, @b);
  i := 0;
  while i < len do
  begin
    luaL_addchar(@b, AnsiChar(c_toupper(Byte(s[i]))));
    Inc(i);
  end;
  luaL_pushresult(@b);
  Result := 1;
end;

function str_rep(L: Plua_State): Integer; cdecl;
var len: size_t; b: luaL_Buffer; s: PAnsiChar; n: Integer;
begin
  s := luaL_checklstring(L, 1, @len);
  n := luaL_checkint(L, 2);
  luaL_buffinit(L, @b);
  while n > 0 do
  begin
    Dec(n);
    luaL_addlstring(@b, s, len);
  end;
  luaL_pushresult(@b);
  Result := 1;
end;

function str_byte(L: Plua_State): Integer; cdecl;
var len: size_t; s: PAnsiChar; posi, pose: ptrdiff_t; n, i: Integer;
begin
  s := luaL_checklstring(L, 1, @len);
  posi := posrelat(luaL_optinteger(L, 2, 1), len);
  pose := posrelat(luaL_optinteger(L, 3, posi), len);
  if posi <= 0 then posi := 1;
  if size_t(pose) > len then pose := ptrdiff_t(len);
  if posi > pose then Exit(0);  { empty interval; return no values }
  n := Integer(pose - posi + 1);
  if posi + n <= pose then  { overflow? }
    luaL_errorf(L, 'string slice too long', []);
  luaL_checkstack(L, n, 'string slice too long');
  for i := 0 to n - 1 do
    lua_pushinteger(L, Byte(s[posi + i - 1]));
  Result := n;
end;

function str_char(L: Plua_State): Integer; cdecl;
var n, i, c: Integer; b: luaL_Buffer;
begin
  n := lua_gettop(L);  { number of arguments }
  luaL_buffinit(L, @b);
  for i := 1 to n do
  begin
    c := luaL_checkint(L, i);
    luaL_argcheck(L, Byte(c) = c, i, 'invalid value');
    luaL_addchar(@b, AnsiChar(Byte(c)));
  end;
  luaL_pushresult(@b);
  Result := 1;
end;

function writer(L: Plua_State; b: Pointer; size: size_t; B_: Pointer): Integer; cdecl;
begin
  luaL_addlstring(PluaL_Buffer(B_), PAnsiChar(b), size);
  Result := 0;
end;

function str_dump(L: Plua_State): Integer; cdecl;
var b: luaL_Buffer;
begin
  luaL_checktype(L, 1, LUA_TFUNCTION);
  lua_settop(L, 1);
  luaL_buffinit(L, @b);
  if lua_dump(L, writer, @b) <> 0 then
    luaL_errorf(L, 'unable to dump given function', []);
  luaL_pushresult(@b);
  Result := 1;
end;

{ ======================================================
  PATTERN MATCHING
  ======================================================= }

const
  CAP_UNFINISHED = -1;
  CAP_POSITION = -2;
  L_ESC = '%';
  SPECIALS = '^$*+?.([%-';

type
  PMatchState = ^TMatchState;
  TMatchState = record
    src_init: PAnsiChar;  { init of source string }
    src_end: PAnsiChar;  { end (`\0') of source string }
    L: Plua_State;
    level: Integer;  { total number of captures (finished or unfinished) }
    capture: array[0..LUA_MAXCAPTURES - 1] of record
      init: PAnsiChar;
      len: ptrdiff_t;
    end;
  end;

function check_capture(ms: PMatchState; l: Integer): Integer;
begin
  l := l - Ord('1');
  if (l < 0) or (l >= ms^.level) or (ms^.capture[l].len = CAP_UNFINISHED) then
    Exit(luaL_errorf(ms^.L, 'invalid capture index', []));
  Result := l;
end;

function capture_to_close(ms: PMatchState): Integer;
var level: Integer;
begin
  level := ms^.level - 1;
  while level >= 0 do
  begin
    if ms^.capture[level].len = CAP_UNFINISHED then Exit(level);
    Dec(level);
  end;
  Result := luaL_errorf(ms^.L, 'invalid pattern capture', []);
end;

function classend(ms: PMatchState; p: PAnsiChar): PAnsiChar;
var c: AnsiChar;
begin
  c := p^;
  Inc(p);
  case c of
    L_ESC:
      begin
        if p^ = #0 then
          luaL_errorf(ms^.L, 'malformed pattern (ends with ''%%'')', []);
        Result := p + 1;
      end;
    '[':
      begin
        if p^ = '^' then Inc(p);
        repeat  { look for a `]' }
          if p^ = #0 then
            luaL_errorf(ms^.L, 'malformed pattern (missing '']'')', []);
          c := p^;
          Inc(p);
          if (c = L_ESC) and (p^ <> #0) then
            Inc(p);  { skip escapes (e.g. `%]') }
        until p^ = ']';
        Result := p + 1;
      end;
  else
    Result := p;
  end;
end;

function match_class(c, cl: Integer): Boolean;
var res: Boolean;
begin
  case c_tolower(cl) of
    Ord('a'): res := c_isalpha(c);
    Ord('c'): res := c_iscntrl(c);
    Ord('d'): res := c_isdigit(c);
    Ord('l'): res := c_islower(c);
    Ord('p'): res := c_ispunct(c);
    Ord('s'): res := c_isspace(c);
    Ord('u'): res := c_isupper(c);
    Ord('w'): res := c_isalnum(c);
    Ord('x'): res := c_isxdigit(c);
    Ord('z'): res := c = 0;
  else
    Exit(cl = c);
  end;
  if c_islower(cl) then Result := res else Result := not res;
end;

function matchbracketclass(c: Integer; p, ec: PAnsiChar): Boolean;
var sig: Boolean;
begin
  sig := True;
  if (p + 1)^ = '^' then
  begin
    sig := False;
    Inc(p);  { skip the `^' }
  end;
  while True do
  begin
    Inc(p);
    if not (p < ec) then Break;
    if p^ = L_ESC then
    begin
      Inc(p);
      if match_class(c, Byte(p^)) then
        Exit(sig);
    end
    else if ((p + 1)^ = '-') and (p + 2 < ec) then
    begin
      Inc(p, 2);
      if (Byte((p - 2)^) <= c) and (c <= Byte(p^)) then
        Exit(sig);
    end
    else if Byte(p^) = c then Exit(sig);
  end;
  Result := not sig;
end;

function singlematch(c: Integer; p, ep: PAnsiChar): Boolean;
begin
  case p^ of
    '.': Result := True;  { matches any char }
    L_ESC: Result := match_class(c, Byte((p + 1)^));
    '[': Result := matchbracketclass(c, p, ep - 1);
  else
    Result := Byte(p^) = c;
  end;
end;

function match(ms: PMatchState; s, p: PAnsiChar): PAnsiChar; forward;

function matchbalance(ms: PMatchState; s, p: PAnsiChar): PAnsiChar;
var b, e: AnsiChar; cont: Integer;
begin
  if (p^ = #0) or ((p + 1)^ = #0) then
    luaL_errorf(ms^.L, 'unbalanced pattern', []);
  if s^ <> p^ then Exit(nil)
  else
  begin
    b := p^;
    e := (p + 1)^;
    cont := 1;
    while True do
    begin
      Inc(s);
      if not (s < ms^.src_end) then Break;
      if s^ = e then
      begin
        Dec(cont);
        if cont = 0 then Exit(s + 1);
      end
      else if s^ = b then Inc(cont);
    end;
  end;
  Result := nil;  { string ends out of balance }
end;

function max_expand(ms: PMatchState; s, p, ep: PAnsiChar): PAnsiChar;
var i: ptrdiff_t; res: PAnsiChar;
begin
  i := 0;  { counts maximum expand for item }
  while (s + i < ms^.src_end) and singlematch(Byte((s + i)^), p, ep) do
    Inc(i);
  { keeps trying to match with the maximum repetitions }
  while i >= 0 do
  begin
    res := match(ms, s + i, ep + 1);
    if res <> nil then Exit(res);
    Dec(i);  { else didn't match; reduce 1 repetition to try again }
  end;
  Result := nil;
end;

function min_expand(ms: PMatchState; s, p, ep: PAnsiChar): PAnsiChar;
var res: PAnsiChar;
begin
  while True do
  begin
    res := match(ms, s, ep + 1);
    if res <> nil then
      Exit(res)
    else if (s < ms^.src_end) and singlematch(Byte(s^), p, ep) then
      Inc(s)  { try with one more repetition }
    else
      Exit(nil);
  end;
end;

function start_capture(ms: PMatchState; s, p: PAnsiChar; what: Integer): PAnsiChar;
var res: PAnsiChar; level: Integer;
begin
  level := ms^.level;
  if level >= LUA_MAXCAPTURES then luaL_errorf(ms^.L, 'too many captures', []);
  ms^.capture[level].init := s;
  ms^.capture[level].len := what;
  ms^.level := level + 1;
  res := match(ms, s, p);
  if res = nil then  { match failed? }
    Dec(ms^.level);  { undo capture }
  Result := res;
end;

function end_capture(ms: PMatchState; s, p: PAnsiChar): PAnsiChar;
var l: Integer; res: PAnsiChar;
begin
  l := capture_to_close(ms);
  ms^.capture[l].len := s - ms^.capture[l].init;  { close capture }
  res := match(ms, s, p);
  if res = nil then  { match failed? }
    ms^.capture[l].len := CAP_UNFINISHED;  { undo capture }
  Result := res;
end;

function match_capture(ms: PMatchState; s: PAnsiChar; l: Integer): PAnsiChar;
var len: size_t;
begin
  l := check_capture(ms, l);
  len := size_t(ms^.capture[l].len);
  if (size_t(ms^.src_end - s) >= len) and
     (c_memcmp(ms^.capture[l].init, s, len) = 0) then
    Result := s + len
  else
    Result := nil;
end;

function match(ms: PMatchState; s, p: PAnsiChar): PAnsiChar;
label
  init, dflt;
var ep, res: PAnsiChar; previous: AnsiChar; m: Boolean;
begin
init:  { using goto's to optimize tail recursion }
  case p^ of
    '(':
      begin  { start capture }
        if (p + 1)^ = ')' then  { position capture? }
          Exit(start_capture(ms, s, p + 2, CAP_POSITION))
        else
          Exit(start_capture(ms, s, p + 1, CAP_UNFINISHED));
      end;
    ')':
      Exit(end_capture(ms, s, p + 1));  { end capture }
    L_ESC:
      begin
        case (p + 1)^ of
          'b':
            begin  { balanced string? }
              s := matchbalance(ms, s, p + 2);
              if s = nil then Exit(nil);
              Inc(p, 4);
              goto init;  { else return match(ms, s, p+4); }
            end;
          'f':
            begin  { frontier? }
              Inc(p, 2);
              if p^ <> '[' then
                luaL_errorf(ms^.L, 'missing ''['' after ''%%f'' in pattern', []);
              ep := classend(ms, p);  { points to what is next }
              if s = ms^.src_init then previous := #0 else previous := (s - 1)^;
              if matchbracketclass(Byte(previous), p, ep - 1) or
                 not matchbracketclass(Byte(s^), p, ep - 1) then
                Exit(nil);
              p := ep;
              goto init;  { else return match(ms, s, ep); }
            end;
        else
          begin
            if c_isdigit(Byte((p + 1)^)) then
            begin  { capture results (%0-%9)? }
              s := match_capture(ms, s, Byte((p + 1)^));
              if s = nil then Exit(nil);
              Inc(p, 2);
              goto init;  { else return match(ms, s, p+2) }
            end;
            goto dflt;  { case default }
          end;
        end;
      end;
    #0:
      Exit(s);  { end of pattern; match succeeded }
    '$':
      begin
        if (p + 1)^ = #0 then  { is the `$' the last char in pattern? }
        begin
          if s = ms^.src_end then Exit(s) else Exit(nil);  { check end of string }
        end
        else
          goto dflt;
      end;
  else
    goto dflt;
  end;
dflt:  { it is a pattern item }
  ep := classend(ms, p);  { points to what is next }
  m := (s < ms^.src_end) and singlematch(Byte(s^), p, ep);
  case ep^ of
    '?':
      begin  { optional }
        if m then
        begin
          res := match(ms, s + 1, ep + 1);
          if res <> nil then Exit(res);
        end;
        p := ep + 1;
        goto init;  { else return match(ms, s, ep+1); }
      end;
    '*':
      Exit(max_expand(ms, s, p, ep));  { 0 or more repetitions }
    '+':
      begin  { 1 or more repetitions }
        if m then Exit(max_expand(ms, s + 1, p, ep)) else Exit(nil);
      end;
    '-':
      Exit(min_expand(ms, s, p, ep));  { 0 or more repetitions (minimum) }
  else
    begin
      if not m then Exit(nil);
      Inc(s);
      p := ep;
      goto init;  { else return match(ms, s+1, ep); }
    end;
  end;
end;

function lmemfind(s1: PAnsiChar; l1: size_t; s2: PAnsiChar; l2: size_t): PAnsiChar;
var init: PAnsiChar;
begin
  if l2 = 0 then Exit(s1)  { empty strings are everywhere }
  else if l2 > l1 then Exit(nil)  { avoids a negative `l1' }
  else
  begin
    Dec(l2);  { 1st char will be checked by `memchr' }
    l1 := l1 - l2;  { `s2' cannot be found after that }
    while l1 > 0 do
    begin
      init := c_memchr(s1, Byte(s2^), l1);
      if init = nil then Break;
      Inc(init);  { 1st char is already checked }
      if c_memcmp(init, s2 + 1, l2) = 0 then
        Exit(init - 1)
      else
      begin  { correct `l1' and `s1' to try again }
        l1 := l1 - size_t(init - s1);
        s1 := init;
      end;
    end;
    Result := nil;  { not found }
  end;
end;

procedure push_onecapture(ms: PMatchState; i: Integer; s, e: PAnsiChar);
var l: ptrdiff_t;
begin
  if i >= ms^.level then
  begin
    if i = 0 then  { ms->level == 0, too }
      lua_pushlstring(ms^.L, s, e - s)  { add whole match }
    else
      luaL_errorf(ms^.L, 'invalid capture index', []);
  end
  else
  begin
    l := ms^.capture[i].len;
    if l = CAP_UNFINISHED then luaL_errorf(ms^.L, 'unfinished capture', []);
    if l = CAP_POSITION then
      lua_pushinteger(ms^.L, ms^.capture[i].init - ms^.src_init + 1)
    else
      lua_pushlstring(ms^.L, ms^.capture[i].init, l);
  end;
end;

function push_captures(ms: PMatchState; s, e: PAnsiChar): Integer;
var i, nlevels: Integer;
begin
  if (ms^.level = 0) and (s <> nil) then nlevels := 1 else nlevels := ms^.level;
  luaL_checkstack(ms^.L, nlevels, 'too many captures');
  for i := 0 to nlevels - 1 do
    push_onecapture(ms, i, s, e);
  Result := nlevels;  { number of strings pushed }
end;

function str_find_aux(L: Plua_State; find: Boolean): Integer;
var l1, l2: size_t; s, p, s1, s2, res: PAnsiChar; init: ptrdiff_t; ms: TMatchState;
    anchor: Boolean;
begin
  s := luaL_checklstring(L, 1, @l1);
  p := luaL_checklstring(L, 2, @l2);
  init := posrelat(luaL_optinteger(L, 3, 1), l1) - 1;
  if init < 0 then init := 0
  else if size_t(init) > l1 then init := ptrdiff_t(l1);
  if find and ((lua_toboolean(L, 4) <> 0) or  { explicit request? }
     (c_strpbrk(p, SPECIALS) = nil)) then
  begin  { or no special characters? }
    { do a plain search }
    s2 := lmemfind(s + init, l1 - size_t(init), p, l2);
    if s2 <> nil then
    begin
      lua_pushinteger(L, s2 - s + 1);
      lua_pushinteger(L, lua_Integer(s2 - s) + lua_Integer(l2));
      Exit(2);
    end;
  end
  else
  begin
    anchor := p^ = '^';
    if anchor then Inc(p);  { skip anchor character }
    s1 := s + init;
    ms.L := L;
    ms.src_init := s;
    ms.src_end := s + l1;
    repeat
      ms.level := 0;
      res := match(@ms, s1, p);
      if res <> nil then
      begin
        if find then
        begin
          lua_pushinteger(L, s1 - s + 1);  { start }
          lua_pushinteger(L, res - s);  { end }
          Exit(push_captures(@ms, nil, nil) + 2);
        end
        else
          Exit(push_captures(@ms, s1, res));
      end;
      Inc(s1);
    until not ((s1 - 1 < ms.src_end) and not anchor);
  end;
  lua_pushnil(L);  { not found }
  Result := 1;
end;

function str_find(L: Plua_State): Integer; cdecl;
begin
  Result := str_find_aux(L, True);
end;

function str_match(L: Plua_State): Integer; cdecl;
begin
  Result := str_find_aux(L, False);
end;

function gmatch_aux(L: Plua_State): Integer; cdecl;
var ms: TMatchState; ls: size_t; s, p, src, e: PAnsiChar; newstart: lua_Integer;
begin
  s := lua_tolstring(L, lua_upvalueindex(1), @ls);
  p := lua_tostring(L, lua_upvalueindex(2));
  ms.L := L;
  ms.src_init := s;
  ms.src_end := s + ls;
  src := s + size_t(lua_tointeger(L, lua_upvalueindex(3)));
  while src <= ms.src_end do
  begin
    ms.level := 0;
    e := match(@ms, src, p);
    if e <> nil then
    begin
      newstart := e - s;
      if e = src then Inc(newstart);  { empty match? go at least one position }
      lua_pushinteger(L, newstart);
      lua_replace(L, lua_upvalueindex(3));
      Exit(push_captures(@ms, src, e));
    end;
    Inc(src);
  end;
  Result := 0;  { not found }
end;

function gmatch(L: Plua_State): Integer; cdecl;
begin
  luaL_checkstring(L, 1);
  luaL_checkstring(L, 2);
  lua_settop(L, 2);
  lua_pushinteger(L, 0);
  lua_pushcclosure(L, gmatch_aux, 3);
  Result := 1;
end;

function gfind_nodef(L: Plua_State): Integer; cdecl;
begin
  Result := luaL_errorf(L, '''string.gfind'' was renamed to ''string.gmatch''', []);
end;

procedure add_s(ms: PMatchState; b: PluaL_Buffer; s, e: PAnsiChar);
var l, i: size_t; news: PAnsiChar;
begin
  news := lua_tolstring(ms^.L, 3, @l);
  i := 0;
  while i < l do
  begin
    if news[i] <> L_ESC then
      luaL_addchar(b, news[i])
    else
    begin
      Inc(i);  { skip ESC }
      if not c_isdigit(Byte(news[i])) then
        luaL_addchar(b, news[i])
      else if news[i] = '0' then
        luaL_addlstring(b, s, e - s)
      else
      begin
        push_onecapture(ms, Ord(news[i]) - Ord('1'), s, e);
        luaL_addvalue(b);  { add capture to accumulated result }
      end;
    end;
    Inc(i);
  end;
end;

procedure add_value(ms: PMatchState; b: PluaL_Buffer; s, e: PAnsiChar);
var L: Plua_State; n: Integer;
begin
  L := ms^.L;
  case lua_type(L, 3) of
    LUA_TNUMBER, LUA_TSTRING:
      begin
        add_s(ms, b, s, e);
        Exit;
      end;
    LUA_TFUNCTION:
      begin
        lua_pushvalue(L, 3);
        n := push_captures(ms, s, e);
        lua_call(L, n, 1);
      end;
    LUA_TTABLE:
      begin
        push_onecapture(ms, 0, s, e);
        lua_gettable(L, 3);
      end;
  end;
  if lua_toboolean(L, -1) = 0 then
  begin  { nil or false? }
    lua_pop(L, 1);
    lua_pushlstring(L, s, e - s);  { keep original text }
  end
  else if lua_isstring(L, -1) = 0 then
    luaL_errorf(L, 'invalid replacement value (a %s)', [luaL_typename(L, -1)]);
  luaL_addvalue(b);  { add result to accumulator }
end;

function str_gsub(L: Plua_State): Integer; cdecl;
var srcl: size_t; src, p, e: PAnsiChar; tr, max_s, n: Integer; anchor: Boolean;
    ms: TMatchState; b: luaL_Buffer;
begin
  src := luaL_checklstring(L, 1, @srcl);
  p := luaL_checkstring(L, 2);
  tr := lua_type(L, 3);
  max_s := luaL_optint(L, 4, Integer(srcl + 1));
  anchor := p^ = '^';
  if anchor then Inc(p);
  n := 0;
  luaL_argcheck(L, (tr = LUA_TNUMBER) or (tr = LUA_TSTRING) or
                   (tr = LUA_TFUNCTION) or (tr = LUA_TTABLE), 3,
                   'string/function/table expected');
  luaL_buffinit(L, @b);
  ms.L := L;
  ms.src_init := src;
  ms.src_end := src + srcl;
  while n < max_s do
  begin
    ms.level := 0;
    e := match(@ms, src, p);
    if e <> nil then
    begin
      Inc(n);
      add_value(@ms, @b, src, e);
    end;
    if (e <> nil) and (e > src) then  { non empty match? }
      src := e  { skip it }
    else if src < ms.src_end then
    begin
      luaL_addchar(@b, src^);
      Inc(src);
    end
    else
      Break;
    if anchor then Break;
  end;
  luaL_addlstring(@b, src, ms.src_end - src);
  luaL_pushresult(@b);
  lua_pushinteger(L, n);  { number of substitutions }
  Result := 2;
end;

{ ====================================================== }

const
  FLAGS = '-+ #0';
  SIZEOF_FLAGS = 6;              { sizeof(FLAGS) }
  MAX_FORMAT = SIZEOF_FLAGS + 2 + 10;

procedure addquoted(L: Plua_State; b: PluaL_Buffer; arg: Integer);
var len: size_t; s: PAnsiChar;
begin
  s := luaL_checklstring(L, arg, @len);
  luaL_addchar(b, '"');
  while len > 0 do
  begin
    Dec(len);
    case s^ of
      '"', '\', #10:
        begin
          luaL_addchar(b, '\');
          luaL_addchar(b, s^);
        end;
      #13:
        luaL_addlstring(b, '\r', 2);
      #0:
        luaL_addlstring(b, '\000', 4);
    else
      luaL_addchar(b, s^);
    end;
    Inc(s);
  end;
  luaL_addchar(b, '"');
end;

function scanformat(L: Plua_State; strfrmt: PAnsiChar; form: PAnsiChar): PAnsiChar;
var p: PAnsiChar;
begin
  p := strfrmt;
  while (p^ <> #0) and (c_strchr(FLAGS, Ord(p^)) <> nil) do Inc(p);  { skip flags }
  if size_t(p - strfrmt) >= SIZEOF_FLAGS then
    luaL_errorf(L, 'invalid format (repeated flags)', []);
  if c_isdigit(Byte(p^)) then Inc(p);  { skip width }
  if c_isdigit(Byte(p^)) then Inc(p);  { (2 digits at most) }
  if p^ = '.' then
  begin
    Inc(p);
    if c_isdigit(Byte(p^)) then Inc(p);  { skip precision }
    if c_isdigit(Byte(p^)) then Inc(p);  { (2 digits at most) }
  end;
  if c_isdigit(Byte(p^)) then
    luaL_errorf(L, 'invalid format (width or precision too long)', []);
  form^ := '%';
  Inc(form);
  c_strncpy(form, strfrmt, p - strfrmt + 1);
  Inc(form, p - strfrmt + 1);
  form^ := #0;
  Result := p;
end;


function str_format(L: Plua_State): Integer; cdecl;
var arg: Integer; sfl, len: size_t; strfrmt, strfrmt_end, s: PAnsiChar; b: luaL_Buffer;
    form: array[0..MAX_FORMAT - 1] of AnsiChar; buff: AnsiString; c: AnsiChar;
begin
  arg := 1;
  strfrmt := luaL_checklstring(L, arg, @sfl);
  strfrmt_end := strfrmt + sfl;
  luaL_buffinit(L, @b);
  while strfrmt < strfrmt_end do
  begin
    if strfrmt^ <> L_ESC then
    begin
      luaL_addchar(@b, strfrmt^);
      Inc(strfrmt);
    end
    else
    begin
      Inc(strfrmt);
      if strfrmt^ = L_ESC then
      begin
        luaL_addchar(@b, strfrmt^);  { %% }
        Inc(strfrmt);
      end
      else
      begin  { format item }
        Inc(arg);
        strfrmt := scanformat(L, strfrmt, @form[0]);
        c := strfrmt^;
        Inc(strfrmt);
        case c of
          'c':
            buff := c_fmt_long(@form[0], c_double2long(luaL_checknumber(L, arg)));
          'd', 'i':
            buff := c_fmt_long(@form[0], c_double2long(luaL_checknumber(L, arg)));
          'o', 'u', 'x', 'X':
            buff := c_fmt_long(@form[0], c_long(c_double2ulong(luaL_checknumber(L, arg))));
          'e', 'E', 'f', 'g', 'G':
            buff := c_fmt_double(@form[0], luaL_checknumber(L, arg));
          'q':
            begin
              addquoted(L, @b, arg);
              Continue;  { skip the 'addsize' at the end }
            end;
          's':
            begin
              s := luaL_checklstring(L, arg, @len);
              if (c_strchr(@form[0], Ord('.')) = nil) and (len >= 100) then
              begin
                { no precision and string is too long to be formatted;
                  keep original string }
                lua_pushvalue(L, arg);
                luaL_addvalue(@b);
                Continue;  { skip the `addsize' at the end }
              end
              else
                buff := c_fmt_str(@form[0], s);
            end;
        else
          { also treat cases `pnLlh' }
          Exit(luaL_errorf(L, 'invalid option ''%%%c'' to ''format''', [(strfrmt - 1)^]));
        end;
        if Length(buff) > 0 then
          luaL_addlstring(@b, PAnsiChar(buff), c_strlen(PAnsiChar(buff)));
      end;
    end;
  end;
  luaL_pushresult(@b);
  Result := 1;
end;

const
  strlib: array[0..15] of luaL_Reg = (
    (name: 'byte'; func: str_byte),
    (name: 'char'; func: str_char),
    (name: 'dump'; func: str_dump),
    (name: 'find'; func: str_find),
    (name: 'format'; func: str_format),
    (name: 'gfind'; func: gfind_nodef),
    (name: 'gmatch'; func: gmatch),
    (name: 'gsub'; func: str_gsub),
    (name: 'len'; func: str_len),
    (name: 'lower'; func: str_lower),
    (name: 'match'; func: str_match),
    (name: 'rep'; func: str_rep),
    (name: 'reverse'; func: str_reverse),
    (name: 'sub'; func: str_sub),
    (name: 'upper'; func: str_upper),
    (name: nil; func: nil));

procedure createmetatable(L: Plua_State);
begin
  lua_createtable(L, 0, 1);  { create metatable for strings }
  lua_pushlstring(L, '', 0);  { dummy string }
  lua_pushvalue(L, -2);
  lua_setmetatable(L, -2);  { set string metatable }
  lua_pop(L, 1);  { pop dummy string }
  lua_pushvalue(L, -2);  { string library... }
  lua_setfield(L, -2, '__index');  { ...is the __index metamethod }
  lua_pop(L, 1);  { pop metatable }
end;

function luaopen_string(L: Plua_State): Integer; cdecl;
begin
  luaL_register(L, LUA_STRLIBNAME, @strlib[0]);
  lua_getfield(L, -1, 'gmatch');
  lua_setfield(L, -2, 'gfind');
  createmetatable(L);
  Result := 1;
end;

end.
