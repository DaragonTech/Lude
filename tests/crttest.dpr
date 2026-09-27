program crttest;
{$I ../src/lua.inc}
{$APPTYPE CONSOLE}
uses LuaTypes, LuaCRT;
var line, cmd, arg1, arg2: AnsiString; d: Double; p: Integer; ep: PAnsiChar; u: UInt64;
    buf: array[0..63] of AnsiChar; s: AnsiString;
function HexToU64(const h: AnsiString): UInt64;
var i: Integer; c: AnsiChar;
begin
  Result := 0;
  for i := 1 to Length(h) do
  begin
    c := h[i];
    if c <= '9' then Result := Result * 16 + UInt64(Ord(c) - 48)
    else Result := Result * 16 + UInt64(Ord(c) - 87);
  end;
end;
begin
  while not Eof(Input) do
  begin
    ReadLn(line);
    p := Pos(' ', line); cmd := Copy(line, 1, p - 1); Delete(line, 1, p);
    if cmd = 'p' then
    begin
      p := Pos(' ', line); arg1 := Copy(line, 1, p - 1); arg2 := Copy(line, p + 1, 100);
      u := HexToU64(arg1); Move(u, d, 8);
      if arg2 = 'N' then begin lua_number2str(buf, d); WriteLn(PAnsiChar(@buf[0])); end
      else WriteLn(c_fmt_double(PAnsiChar(arg2), d));
    end
    else if cmd = 's' then
    begin
      d := c_strtod(PAnsiChar(line), @ep);
      Move(d, u, 8);
      s := '';
      for p := 15 downto 0 do s := s + AnsiChar(PAnsiChar('0123456789abcdef')[(u shr (p*4)) and 15]);
      WriteLn(s, ' ', ep - PAnsiChar(line));
    end;
  end;
end.
