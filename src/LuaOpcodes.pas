{
  Lua 5.1.4 - Pascal port of lopcodes.c
}
unit LuaOpcodes;

{$I lua.inc}

interface

uses
  LuaTypes;

const
  luaP_opnames: array[0..NUM_OPCODES] of PAnsiChar = (
    'MOVE', 'LOADK', 'LOADBOOL', 'LOADNIL', 'GETUPVAL', 'GETGLOBAL',
    'GETTABLE', 'SETGLOBAL', 'SETUPVAL', 'SETTABLE', 'NEWTABLE', 'SELF',
    'ADD', 'SUB', 'MUL', 'DIV', 'MOD', 'POW', 'UNM', 'NOT', 'LEN', 'CONCAT',
    'JMP', 'EQ', 'LT', 'LE', 'TEST', 'TESTSET', 'CALL', 'TAILCALL', 'RETURN',
    'FORLOOP', 'FORPREP', 'TFORLOOP', 'SETLIST', 'CLOSE', 'CLOSURE', 'VARARG',
    nil);

  { opmode(t,a,b,c,m) = (t shl 7) or (a shl 6) or (b shl 4) or (c shl 2) or m }
  luaP_opmodes: array[0..NUM_OPCODES - 1] of lu_byte = (
    (0 shl 7) or (1 shl 6) or (OpArgR shl 4) or (OpArgN shl 2) or iABC,   { OP_MOVE }
    (0 shl 7) or (1 shl 6) or (OpArgK shl 4) or (OpArgN shl 2) or iABx,   { OP_LOADK }
    (0 shl 7) or (1 shl 6) or (OpArgU shl 4) or (OpArgU shl 2) or iABC,   { OP_LOADBOOL }
    (0 shl 7) or (1 shl 6) or (OpArgR shl 4) or (OpArgN shl 2) or iABC,   { OP_LOADNIL }
    (0 shl 7) or (1 shl 6) or (OpArgU shl 4) or (OpArgN shl 2) or iABC,   { OP_GETUPVAL }
    (0 shl 7) or (1 shl 6) or (OpArgK shl 4) or (OpArgN shl 2) or iABx,   { OP_GETGLOBAL }
    (0 shl 7) or (1 shl 6) or (OpArgR shl 4) or (OpArgK shl 2) or iABC,   { OP_GETTABLE }
    (0 shl 7) or (0 shl 6) or (OpArgK shl 4) or (OpArgN shl 2) or iABx,   { OP_SETGLOBAL }
    (0 shl 7) or (0 shl 6) or (OpArgU shl 4) or (OpArgN shl 2) or iABC,   { OP_SETUPVAL }
    (0 shl 7) or (0 shl 6) or (OpArgK shl 4) or (OpArgK shl 2) or iABC,   { OP_SETTABLE }
    (0 shl 7) or (1 shl 6) or (OpArgU shl 4) or (OpArgU shl 2) or iABC,   { OP_NEWTABLE }
    (0 shl 7) or (1 shl 6) or (OpArgR shl 4) or (OpArgK shl 2) or iABC,   { OP_SELF }
    (0 shl 7) or (1 shl 6) or (OpArgK shl 4) or (OpArgK shl 2) or iABC,   { OP_ADD }
    (0 shl 7) or (1 shl 6) or (OpArgK shl 4) or (OpArgK shl 2) or iABC,   { OP_SUB }
    (0 shl 7) or (1 shl 6) or (OpArgK shl 4) or (OpArgK shl 2) or iABC,   { OP_MUL }
    (0 shl 7) or (1 shl 6) or (OpArgK shl 4) or (OpArgK shl 2) or iABC,   { OP_DIV }
    (0 shl 7) or (1 shl 6) or (OpArgK shl 4) or (OpArgK shl 2) or iABC,   { OP_MOD }
    (0 shl 7) or (1 shl 6) or (OpArgK shl 4) or (OpArgK shl 2) or iABC,   { OP_POW }
    (0 shl 7) or (1 shl 6) or (OpArgR shl 4) or (OpArgN shl 2) or iABC,   { OP_UNM }
    (0 shl 7) or (1 shl 6) or (OpArgR shl 4) or (OpArgN shl 2) or iABC,   { OP_NOT }
    (0 shl 7) or (1 shl 6) or (OpArgR shl 4) or (OpArgN shl 2) or iABC,   { OP_LEN }
    (0 shl 7) or (1 shl 6) or (OpArgR shl 4) or (OpArgR shl 2) or iABC,   { OP_CONCAT }
    (0 shl 7) or (0 shl 6) or (OpArgR shl 4) or (OpArgN shl 2) or iAsBx,  { OP_JMP }
    (1 shl 7) or (0 shl 6) or (OpArgK shl 4) or (OpArgK shl 2) or iABC,   { OP_EQ }
    (1 shl 7) or (0 shl 6) or (OpArgK shl 4) or (OpArgK shl 2) or iABC,   { OP_LT }
    (1 shl 7) or (0 shl 6) or (OpArgK shl 4) or (OpArgK shl 2) or iABC,   { OP_LE }
    (1 shl 7) or (1 shl 6) or (OpArgR shl 4) or (OpArgU shl 2) or iABC,   { OP_TEST }
    (1 shl 7) or (1 shl 6) or (OpArgR shl 4) or (OpArgU shl 2) or iABC,   { OP_TESTSET }
    (0 shl 7) or (1 shl 6) or (OpArgU shl 4) or (OpArgU shl 2) or iABC,   { OP_CALL }
    (0 shl 7) or (1 shl 6) or (OpArgU shl 4) or (OpArgU shl 2) or iABC,   { OP_TAILCALL }
    (0 shl 7) or (0 shl 6) or (OpArgU shl 4) or (OpArgN shl 2) or iABC,   { OP_RETURN }
    (0 shl 7) or (1 shl 6) or (OpArgR shl 4) or (OpArgN shl 2) or iAsBx,  { OP_FORLOOP }
    (0 shl 7) or (1 shl 6) or (OpArgR shl 4) or (OpArgN shl 2) or iAsBx,  { OP_FORPREP }
    (1 shl 7) or (0 shl 6) or (OpArgN shl 4) or (OpArgU shl 2) or iABC,   { OP_TFORLOOP }
    (0 shl 7) or (0 shl 6) or (OpArgU shl 4) or (OpArgU shl 2) or iABC,   { OP_SETLIST }
    (0 shl 7) or (0 shl 6) or (OpArgN shl 4) or (OpArgN shl 2) or iABC,   { OP_CLOSE }
    (0 shl 7) or (1 shl 6) or (OpArgU shl 4) or (OpArgN shl 2) or iABx,   { OP_CLOSURE }
    (0 shl 7) or (1 shl 6) or (OpArgU shl 4) or (OpArgN shl 2) or iABC);  { OP_VARARG }

function getOpMode(m: Integer): Integer; inline;
function getBMode(m: Integer): Integer; inline;
function getCMode(m: Integer): Integer; inline;
function testAMode(m: Integer): Boolean; inline;
function testTMode(m: Integer): Boolean; inline;

implementation

function getOpMode(m: Integer): Integer; begin Result := luaP_opmodes[m] and 3; end;
function getBMode(m: Integer): Integer; begin Result := (luaP_opmodes[m] shr 4) and 3; end;
function getCMode(m: Integer): Integer; begin Result := (luaP_opmodes[m] shr 2) and 3; end;
function testAMode(m: Integer): Boolean; begin Result := (luaP_opmodes[m] and (1 shl 6)) <> 0; end;
function testTMode(m: Integer): Boolean; begin Result := (luaP_opmodes[m] and (1 shl 7)) <> 0; end;

end.
