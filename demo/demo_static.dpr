{ Demo: the same host program with Lua compiled into the executable
  (LuaStatic).  Build with the project-wide define LUA_STATIC:
    Delphi: Project Options > Conditional defines, or  dcc32 -DLUA_STATIC
    FPC:    -dLUA_STATIC }
program demo_static;

{$IFDEF MSWINDOWS}{$APPTYPE CONSOLE}{$ENDIF}
{$I lua.inc}

uses
  DemoApp in 'DemoApp.pas';

{$IF not Declared(DEMO_LINKS_STATIC)}
  {$MESSAGE FATAL 'Build demo_static with the project define LUA_STATIC (Project Options > Conditional defines, or -DLUA_STATIC)'}
{$IFEND}

begin
  RunDemo;
end.
