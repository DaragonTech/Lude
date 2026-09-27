{
  Lua 5.1.4 - Pascal port of llex.c
  Lexical Analyzer
}
unit LuaLex;

{$I lua.inc}

interface

uses
  LuaTypes;

const
  luaX_tokens: array[0..NUM_RESERVED + 10] of PAnsiChar = (
    'and', 'break', 'do', 'else', 'elseif',
    'end', 'false', 'for', 'function', 'if',
    'in', 'local', 'nil', 'not', 'or', 'repeat',
    'return', 'then', 'true', 'until', 'while',
    '..', '...', '==', '>=', '<=', '~=',
    '<number>', '<name>', '<string>', '<eof>',
    nil);

procedure luaX_init(L: Plua_State);
procedure luaX_setinput(L: Plua_State; ls: PLexState; z: PZIO; source: PTString);
function luaX_newstring(ls: PLexState; str: PAnsiChar; slen: size_t): PTString;
procedure luaX_next(ls: PLexState);
procedure luaX_lookahead(ls: PLexState);
procedure luaX_lexerror(ls: PLexState; msg: PAnsiChar; token: Integer);
procedure luaX_syntaxerror(ls: PLexState; msg: PAnsiChar);
function luaX_token2str(ls: PLexState; token: Integer): PAnsiChar;

implementation

uses
  LuaCRT, LuaObject, LuaString, LuaTable, LuaDo, LuaZIO;

const
  MAXSRC = 80;

procedure next_(ls: PLexState); inline;
begin
  ls^.current := zgetc(ls^.z);
end;

function currIsNewline(ls: PLexState): Boolean; inline;
begin
  Result := (ls^.current = 10) or (ls^.current = 13);
end;

procedure save(ls: PLexState; c: Integer);
var b: PMbuffer; newsize: size_t;
begin
  b := ls^.buff;
  if b^.n + 1 > b^.buffsize then
  begin
    if b^.buffsize >= MAX_SIZET div 2 then
      luaX_lexerror(ls, 'lexical element too long', 0);
    newsize := b^.buffsize * 2;
    luaZ_resizebuffer(ls^.L, b, newsize);
  end;
  b^.buffer[b^.n] := AnsiChar(Byte(c));
  Inc(b^.n);
end;

procedure save_and_next(ls: PLexState); inline;
begin
  save(ls, ls^.current);
  next_(ls);
end;

procedure luaX_init(L: Plua_State);
var i: Integer; ts: PTString;
begin
  for i := 0 to NUM_RESERVED - 1 do
  begin
    ts := luaS_new(L, luaX_tokens[i]);
    luaS_fix(ts);  { reserved words are never collected }
    ts^.reserved := lu_byte(i + 1);  { reserved word }
  end;
end;

function luaX_token2str(ls: PLexState; token: Integer): PAnsiChar;
begin
  if token < FIRST_RESERVED then
  begin
    if c_iscntrl(token) then
      Result := luaO_pushfstring(ls^.L, 'char(%d)', [token])
    else
      Result := luaO_pushfstring(ls^.L, '%c', [token]);
  end
  else
    Result := luaX_tokens[token - FIRST_RESERVED];
end;

function txtToken(ls: PLexState; token: Integer): PAnsiChar;
begin
  case token of
    TK_NAME, TK_STRING, TK_NUMBER:
      begin
        save(ls, 0);
        Result := ls^.buff^.buffer;
      end;
  else
    Result := luaX_token2str(ls, token);
  end;
end;

procedure luaX_lexerror(ls: PLexState; msg: PAnsiChar; token: Integer);
var buff: array[0..MAXSRC - 1] of AnsiChar;
begin
  luaO_chunkid(@buff[0], getstr(ls^.source), MAXSRC);
  msg := luaO_pushfstring(ls^.L, '%s:%d: %s', [PAnsiChar(@buff[0]), ls^.linenumber, msg]);
  if token <> 0 then
    luaO_pushfstring(ls^.L, '%s near ''%s''', [msg, txtToken(ls, token)]);
  luaD_throw(ls^.L, LUA_ERRSYNTAX);
end;

procedure luaX_syntaxerror(ls: PLexState; msg: PAnsiChar);
begin
  luaX_lexerror(ls, msg, ls^.t.token);
end;

function luaX_newstring(ls: PLexState; str: PAnsiChar; slen: size_t): PTString;
var L: Plua_State; ts: PTString; o: PTValue;
begin
  L := ls^.L;
  ts := luaS_newlstr(L, str, slen);
  o := luaH_setstr(L, ls^.fs^.h, ts);  { entry for `str' }
  if ttisnil(o) then
    setbvalue(o, 1);  { make sure `str' will not be collected }
  Result := ts;
end;

procedure inclinenumber(ls: PLexState);
var old: Integer;
begin
  old := ls^.current;
  next_(ls);  { skip `\n' or `\r' }
  if currIsNewline(ls) and (ls^.current <> old) then
    next_(ls);  { skip `\n\r' or `\r\n' }
  Inc(ls^.linenumber);
  if ls^.linenumber >= MAX_INT then
    luaX_syntaxerror(ls, 'chunk has too many lines');
end;

procedure luaX_setinput(L: Plua_State; ls: PLexState; z: PZIO; source: PTString);
begin
  ls^.decpoint := '.';
  ls^.L := L;
  ls^.lookahead.token := TK_EOS;  { no look-ahead token }
  ls^.z := z;
  ls^.fs := nil;
  ls^.linenumber := 1;
  ls^.lastline := 1;
  ls^.source := source;
  luaZ_resizebuffer(ls^.L, ls^.buff, LUA_MINBUFFER);  { initialize buffer }
  next_(ls);  { read first char }
end;

{ =======================================================
  LEXICAL ANALYZER
  ======================================================= }

function check_next(ls: PLexState; set_: PAnsiChar): Boolean;
begin
  if c_strchr(set_, ls^.current) = nil then
    Exit(False);
  save_and_next(ls);
  Result := True;
end;

procedure buffreplace(ls: PLexState; from, to_: AnsiChar);
var n: size_t; p: PAnsiChar;
begin
  n := ls^.buff^.n;
  p := ls^.buff^.buffer;
  while n > 0 do
  begin
    Dec(n);
    if p[n] = from then p[n] := to_;
  end;
end;

procedure trydecpoint(ls: PLexState; seminfo: PSemInfo);
var old: AnsiChar;
begin
  { format error: try to update decimal point separator }
  old := ls^.decpoint;
  ls^.decpoint := '.';  { "C" locale }
  buffreplace(ls, old, ls^.decpoint);  { try updated decimal separator }
  if luaO_str2d(ls^.buff^.buffer, seminfo^.r) = 0 then
  begin
    { format error with correct decimal point: no more options }
    buffreplace(ls, ls^.decpoint, '.');  { undo change (for error message) }
    luaX_lexerror(ls, 'malformed number', TK_NUMBER);
  end;
end;

procedure read_numeral(ls: PLexState; seminfo: PSemInfo);
begin
  repeat
    save_and_next(ls);
  until not (c_isdigit(ls^.current) or (ls^.current = Ord('.')));
  if check_next(ls, 'Ee') then  { `E'? }
    check_next(ls, '+-');  { optional exponent sign }
  while c_isalnum(ls^.current) or (ls^.current = Ord('_')) do
    save_and_next(ls);
  save(ls, 0);
  buffreplace(ls, '.', ls^.decpoint);  { follow locale for decimal point }
  if luaO_str2d(ls^.buff^.buffer, seminfo^.r) = 0 then  { format error? }
    trydecpoint(ls, seminfo);  { try to update decimal point separator }
end;

function skip_sep(ls: PLexState): Integer;
var count, s: Integer;
begin
  count := 0;
  s := ls^.current;
  save_and_next(ls);
  while ls^.current = Ord('=') do
  begin
    save_and_next(ls);
    Inc(count);
  end;
  if ls^.current = s then Result := count else Result := (-count) - 1;
end;

procedure read_long_string(ls: PLexState; seminfo: PSemInfo; sep: Integer);
label
  endloop;
begin
  save_and_next(ls);  { skip 2nd `[' }
  if currIsNewline(ls) then  { string starts with a newline? }
    inclinenumber(ls);  { skip it }
  while True do
  begin
    case ls^.current of
      EOZ:
        if seminfo <> nil then
          luaX_lexerror(ls, 'unfinished long string', TK_EOS)
        else
          luaX_lexerror(ls, 'unfinished long comment', TK_EOS);
      Ord('['):
        begin
          if skip_sep(ls) = sep then
          begin
            save_and_next(ls);  { skip 2nd `[' }
            if sep = 0 then
              luaX_lexerror(ls, 'nesting of [[...]] is deprecated', Ord('['));
          end;
        end;
      Ord(']'):
        begin
          if skip_sep(ls) = sep then
          begin
            save_and_next(ls);  { skip 2nd `]' }
            goto endloop;
          end;
        end;
      10, 13:
        begin
          save(ls, 10);
          inclinenumber(ls);
          if seminfo = nil then luaZ_resetbuffer(ls^.buff);  { avoid wasting space }
        end;
    else
      begin
        if seminfo <> nil then save_and_next(ls)
        else next_(ls);
      end;
    end;
  end;
endloop:
  if seminfo <> nil then
    seminfo^.ts := luaX_newstring(ls, ls^.buff^.buffer + (2 + sep),
                                  ls^.buff^.n - size_t(2 * (2 + sep)));
end;

procedure read_string(ls: PLexState; del: Integer; seminfo: PSemInfo);
var c, i: Integer;
begin
  save_and_next(ls);
  while ls^.current <> del do
  begin
    case ls^.current of
      EOZ:
        begin
          luaX_lexerror(ls, 'unfinished string', TK_EOS);
          Continue;  { to avoid warnings }
        end;
      10, 13:
        begin
          luaX_lexerror(ls, 'unfinished string', TK_STRING);
          Continue;  { to avoid warnings }
        end;
      Ord('\'):
        begin
          next_(ls);  { do not save the `\' }
          case ls^.current of
            Ord('a'): c := 7;
            Ord('b'): c := 8;
            Ord('f'): c := 12;
            Ord('n'): c := 10;
            Ord('r'): c := 13;
            Ord('t'): c := 9;
            Ord('v'): c := 11;
            10, 13:
              begin
                save(ls, 10);
                inclinenumber(ls);
                Continue;
              end;
            EOZ:
              Continue;  { will raise an error next loop }
          else
            begin
              if not c_isdigit(ls^.current) then
                save_and_next(ls)  { handles \\, \", \', and \? }
              else
              begin  { \xxx }
                i := 0;
                c := 0;
                repeat
                  c := 10 * c + (ls^.current - Ord('0'));
                  next_(ls);
                  Inc(i);
                until not ((i < 3) and c_isdigit(ls^.current));
                if c > 255 then
                  luaX_lexerror(ls, 'escape sequence too large', TK_STRING);
                save(ls, c);
              end;
              Continue;
            end;
          end;
          save(ls, c);
          next_(ls);
          Continue;
        end;
    else
      save_and_next(ls);
    end;
  end;
  save_and_next(ls);  { skip delimiter }
  seminfo^.ts := luaX_newstring(ls, ls^.buff^.buffer + 1, ls^.buff^.n - 2);
end;

function llex(ls: PLexState; seminfo: PSemInfo): Integer;
var sep, c: Integer; ts: PTString;
begin
  luaZ_resetbuffer(ls^.buff);
  while True do
  begin
    case ls^.current of
      10, 13:
        begin
          inclinenumber(ls);
          Continue;
        end;
      Ord('-'):
        begin
          next_(ls);
          if ls^.current <> Ord('-') then Exit(Ord('-'));
          { else is a comment }
          next_(ls);
          if ls^.current = Ord('[') then
          begin
            sep := skip_sep(ls);
            luaZ_resetbuffer(ls^.buff);  { `skip_sep' may dirty the buffer }
            if sep >= 0 then
            begin
              read_long_string(ls, nil, sep);  { long comment }
              luaZ_resetbuffer(ls^.buff);
              Continue;
            end;
          end;
          { else short comment }
          while (not currIsNewline(ls)) and (ls^.current <> EOZ) do
            next_(ls);
          Continue;
        end;
      Ord('['):
        begin
          sep := skip_sep(ls);
          if sep >= 0 then
          begin
            read_long_string(ls, seminfo, sep);
            Exit(TK_STRING);
          end
          else if sep = -1 then Exit(Ord('['))
          else luaX_lexerror(ls, 'invalid long string delimiter', TK_STRING);
        end;
      Ord('='):
        begin
          next_(ls);
          if ls^.current <> Ord('=') then Exit(Ord('='))
          else begin next_(ls); Exit(TK_EQ); end;
        end;
      Ord('<'):
        begin
          next_(ls);
          if ls^.current <> Ord('=') then Exit(Ord('<'))
          else begin next_(ls); Exit(TK_LE); end;
        end;
      Ord('>'):
        begin
          next_(ls);
          if ls^.current <> Ord('=') then Exit(Ord('>'))
          else begin next_(ls); Exit(TK_GE); end;
        end;
      Ord('~'):
        begin
          next_(ls);
          if ls^.current <> Ord('=') then Exit(Ord('~'))
          else begin next_(ls); Exit(TK_NE); end;
        end;
      Ord('"'), Ord(''''):
        begin
          read_string(ls, ls^.current, seminfo);
          Exit(TK_STRING);
        end;
      Ord('.'):
        begin
          save_and_next(ls);
          if check_next(ls, '.') then
          begin
            if check_next(ls, '.') then
              Exit(TK_DOTS)  { ... }
            else
              Exit(TK_CONCAT);  { .. }
          end
          else if not c_isdigit(ls^.current) then Exit(Ord('.'))
          else
          begin
            read_numeral(ls, seminfo);
            Exit(TK_NUMBER);
          end;
        end;
      EOZ:
        Exit(TK_EOS);
    else
      begin
        if c_isspace(ls^.current) then
        begin
          next_(ls);
          Continue;
        end
        else if c_isdigit(ls^.current) then
        begin
          read_numeral(ls, seminfo);
          Exit(TK_NUMBER);
        end
        else if c_isalpha(ls^.current) or (ls^.current = Ord('_')) then
        begin
          { identifier or reserved word }
          repeat
            save_and_next(ls);
          until not (c_isalnum(ls^.current) or (ls^.current = Ord('_')));
          ts := luaX_newstring(ls, ls^.buff^.buffer, ls^.buff^.n);
          if ts^.reserved > 0 then  { reserved word? }
            Exit(ts^.reserved - 1 + FIRST_RESERVED)
          else
          begin
            seminfo^.ts := ts;
            Exit(TK_NAME);
          end;
        end
        else
        begin
          c := ls^.current;
          next_(ls);
          Exit(c);  { single-char tokens (+ - / ...) }
        end;
      end;
    end;
  end;
end;

procedure luaX_next(ls: PLexState);
begin
  ls^.lastline := ls^.linenumber;
  if ls^.lookahead.token <> TK_EOS then
  begin  { is there a look-ahead token? }
    ls^.t := ls^.lookahead;  { use this one }
    ls^.lookahead.token := TK_EOS;  { and discharge it }
  end
  else
    ls^.t.token := llex(ls, @ls^.t.seminfo);  { read next token }
end;

procedure luaX_lookahead(ls: PLexState);
begin
  ls^.lookahead.token := llex(ls, @ls^.lookahead.seminfo);
end;

end.
