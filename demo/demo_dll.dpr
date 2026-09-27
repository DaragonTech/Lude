{ Demo: host program using Lua through lua5.1.dll (LuaDLL). }
program demo_dll;

{$IFDEF MSWINDOWS}{$APPTYPE CONSOLE}{$ENDIF}
{$I lua.inc}

uses
  DemoApp in 'DemoApp.pas';

{$IF Declared(DEMO_LINKS_STATIC)}
  {$MESSAGE FATAL 'DemoApp was compiled with LUA_STATIC: remove the define (or use a separate unit output folder)'}
{$IFEND}

begin
  RunDemo;
end.
