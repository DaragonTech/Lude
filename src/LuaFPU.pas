{
  Lua 5.1.4 - Pascal port
  Puts the FPU/SSE control registers in the state a Microsoft C program
  starts with: all floating point exceptions masked, round to nearest and
  (x87) 53-bit precision.  Pascal programs start with some exceptions
  unmasked, which would make 0/0 or 1/0 raise instead of producing NaN/inf.
  Used by lua.exe / luac.exe; the DLLs leave the host's settings alone,
  exactly like the C lua5.1.dll does.
}
unit LuaFPU;

{$I lua.inc}

interface

procedure lua_set_c_fpu_mode;

implementation

{$IFDEF CPUAARCH64}
{ AArch64: clear the FPCR trap-enable bits (IOE, DZE, OFE, UFE, IXE, IDE).
  Free Pascal programs start with IOE/DZE/OFE set; most ARM cores ignore
  them, but Apple Silicon traps (SIGILL) on 0/0 or 1/0. }
procedure clear_fp_traps; assembler; nostackframe;
asm
  mrs x0, fpcr
  movz x1, #40704         { $9F00: the trap-enable bits }
  mvn x1, x1
  and x0, x0, x1
  msr fpcr, x0
end;
{$ENDIF}

procedure lua_set_c_fpu_mode;
begin
{$IFDEF LUA_X86}
  Set8087CW($027F);   { MSVC default: _PC_53 | _RC_NEAR | all exceptions masked }
{$ENDIF}
{$IFDEF LUA_64}{$IFNDEF CPUAARCH64}
  SetMXCSR($1F80);    { all SSE exceptions masked, round to nearest }
{$ENDIF}{$ENDIF}
{$IFDEF CPUAARCH64}
  clear_fp_traps;
{$IFDEF FPC}
  softfloat_exception_mask := [exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision];
{$ENDIF}
{$ENDIF}
end;

end.
