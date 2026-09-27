{
  Lua 5.1.4 - Pascal port
  Minimal kernel32 imports.  Declared here (instead of using the Windows /
  Winapi.Windows unit) so that the exact same code compiles with Delphi and
  Free Pascal, whose Windows units differ in parameter types.
}
unit LuaWin;

{$I lua.inc}

interface

{$IFDEF MSWINDOWS}  { the whole unit is empty on other systems }

type
  DWORD = Cardinal;
  PDWORD = ^DWORD;
  BOOL = LongBool;
  HANDLE = NativeUInt;
  PHANDLE = ^HANDLE;
  HMODULE = NativeUInt;

  TFileTime = record
    dwLowDateTime: DWORD;
    dwHighDateTime: DWORD;
  end;
  PFileTime = ^TFileTime;

  TSystemTime = record
    wYear, wMonth, wDayOfWeek, wDay, wHour, wMinute, wSecond, wMilliseconds: Word;
  end;
  PSystemTime = ^TSystemTime;

  TTimeZoneInformation = record
    Bias: Longint;
    StandardName: array[0..31] of WideChar;
    StandardDate: TSystemTime;
    StandardBias: Longint;
    DaylightName: array[0..31] of WideChar;
    DaylightDate: TSystemTime;
    DaylightBias: Longint;
  end;
  PTimeZoneInformation = ^TTimeZoneInformation;

  TSecurityAttributes = record
    nLength: DWORD;
    lpSecurityDescriptor: Pointer;
    bInheritHandle: BOOL;
  end;
  PSecurityAttributes = ^TSecurityAttributes;

  TStartupInfoA = record
    cb: DWORD;
    lpReserved: PAnsiChar;
    lpDesktop: PAnsiChar;
    lpTitle: PAnsiChar;
    dwX, dwY, dwXSize, dwYSize: DWORD;
    dwXCountChars, dwYCountChars: DWORD;
    dwFillAttribute: DWORD;
    dwFlags: DWORD;
    wShowWindow: Word;
    cbReserved2: Word;
    lpReserved2: Pointer;
    hStdInput: HANDLE;
    hStdOutput: HANDLE;
    hStdError: HANDLE;
  end;
  PStartupInfoA = ^TStartupInfoA;

  TProcessInformation = record
    hProcess: HANDLE;
    hThread: HANDLE;
    dwProcessId: DWORD;
    dwThreadId: DWORD;
  end;
  PProcessInformation = ^TProcessInformation;

const
  kernel32 = 'kernel32.dll';

  INVALID_HANDLE_VALUE = HANDLE(-1);
  STD_INPUT_HANDLE  = DWORD(-10);
  STD_OUTPUT_HANDLE = DWORD(-11);
  STD_ERROR_HANDLE  = DWORD(-12);

  GENERIC_READ  = DWORD($80000000);
  GENERIC_WRITE = $40000000;
  FILE_SHARE_READ  = 1;
  FILE_SHARE_WRITE = 2;
  CREATE_NEW = 1;
  CREATE_ALWAYS = 2;
  OPEN_EXISTING = 3;
  OPEN_ALWAYS = 4;
  FILE_ATTRIBUTE_NORMAL = $80;
  FILE_ATTRIBUTE_TEMPORARY = $100;
  FILE_FLAG_DELETE_ON_CLOSE = $04000000;
  INVALID_FILE_ATTRIBUTES = DWORD(-1);
  FILE_ATTRIBUTE_DIRECTORY = $10;

  FILE_BEGIN = 0;
  FILE_CURRENT = 1;
  FILE_END = 2;
  INVALID_SET_FILE_POINTER = DWORD(-1);

  FILE_TYPE_UNKNOWN = 0;
  FILE_TYPE_DISK = 1;
  FILE_TYPE_CHAR = 2;
  FILE_TYPE_PIPE = 3;

  STARTF_USESTDHANDLES = $100;
  HANDLE_FLAG_INHERIT = 1;
  INFINITE = DWORD($FFFFFFFF);
  WAIT_FAILED = DWORD($FFFFFFFF);
  NO_ERROR = 0;
  ERROR_BROKEN_PIPE = 109;
  ERROR_NO_DATA = 232;
  TIME_ZONE_ID_INVALID = DWORD($FFFFFFFF);
  TIME_ZONE_ID_DAYLIGHT = 2;
  HEAP_NONE = 0;
  FORMAT_MESSAGE_IGNORE_INSERTS = $200;
  FORMAT_MESSAGE_FROM_SYSTEM = $1000;
  LOAD_WITH_ALTERED_SEARCH_PATH = 8;

function CreateFileA(lpFileName: PAnsiChar; dwDesiredAccess, dwShareMode: DWORD;
  lpSecurityAttributes: Pointer; dwCreationDisposition, dwFlagsAndAttributes: DWORD;
  hTemplateFile: HANDLE): HANDLE; stdcall; external kernel32;
function ReadFile(hFile: HANDLE; lpBuffer: Pointer; nNumberOfBytesToRead: DWORD;
  lpNumberOfBytesRead: PDWORD; lpOverlapped: Pointer): BOOL; stdcall; external kernel32;
function WriteFile(hFile: HANDLE; lpBuffer: Pointer; nNumberOfBytesToWrite: DWORD;
  lpNumberOfBytesWritten: PDWORD; lpOverlapped: Pointer): BOOL; stdcall; external kernel32;
function CloseHandle(hObject: HANDLE): BOOL; stdcall; external kernel32;
function GetStdHandle(nStdHandle: DWORD): HANDLE; stdcall; external kernel32;
function GetFileType(hFile: HANDLE): DWORD; stdcall; external kernel32;
function SetFilePointer(hFile: HANDLE; lDistanceToMove: Longint; lpDistanceToMoveHigh: PLongint;
  dwMoveMethod: DWORD): DWORD; stdcall; external kernel32;
function GetLastError: DWORD; stdcall; external kernel32;
procedure SetLastError(dwErrCode: DWORD); stdcall; external kernel32;
function CreatePipe(hReadPipe, hWritePipe: PHANDLE; lpPipeAttributes: PSecurityAttributes;
  nSize: DWORD): BOOL; stdcall; external kernel32;
function SetHandleInformation(hObject: HANDLE; dwMask, dwFlags: DWORD): BOOL; stdcall; external kernel32;
function CreateProcessA(lpApplicationName, lpCommandLine: PAnsiChar;
  lpProcessAttributes, lpThreadAttributes: Pointer; bInheritHandles: BOOL;
  dwCreationFlags: DWORD; lpEnvironment: Pointer; lpCurrentDirectory: PAnsiChar;
  lpStartupInfo: PStartupInfoA; lpProcessInformation: PProcessInformation): BOOL; stdcall; external kernel32;
function WaitForSingleObject(hHandle: HANDLE; dwMilliseconds: DWORD): DWORD; stdcall; external kernel32;
function GetExitCodeProcess(hProcess: HANDLE; lpExitCode: PDWORD): BOOL; stdcall; external kernel32;
function GetEnvironmentVariableA(lpName: PAnsiChar; lpBuffer: PAnsiChar; nSize: DWORD): DWORD; stdcall; external kernel32;
function DeleteFileA(lpFileName: PAnsiChar): BOOL; stdcall; external kernel32;
function MoveFileA(lpExistingFileName, lpNewFileName: PAnsiChar): BOOL; stdcall; external kernel32;
function GetFileAttributesA(lpFileName: PAnsiChar): DWORD; stdcall; external kernel32;
function GetTempPathA(nBufferLength: DWORD; lpBuffer: PAnsiChar): DWORD; stdcall; external kernel32;
function GetTempFileNameA(lpPathName, lpPrefixString: PAnsiChar; uUnique: Cardinal;
  lpTempFileName: PAnsiChar): Cardinal; stdcall; external kernel32;
procedure ExitProcess(uExitCode: Cardinal); stdcall; external kernel32;
function GetCurrentProcess: HANDLE; stdcall; external kernel32;
function GetCurrentProcessId: DWORD; stdcall; external kernel32;
procedure GetSystemTimeAsFileTime(lpSystemTimeAsFileTime: PFileTime); stdcall; external kernel32;
function GetProcessTimes(hProcess: HANDLE; lpCreationTime, lpExitTime, lpKernelTime,
  lpUserTime: PFileTime): BOOL; stdcall; external kernel32;
function FileTimeToSystemTime(lpFileTime: PFileTime; lpSystemTime: PSystemTime): BOOL; stdcall; external kernel32;
function SystemTimeToFileTime(lpSystemTime: PSystemTime; lpFileTime: PFileTime): BOOL; stdcall; external kernel32;
function GetTimeZoneInformation(lpTimeZoneInformation: PTimeZoneInformation): DWORD; stdcall; external kernel32;
function SystemTimeToTzSpecificLocalTime(lpTimeZoneInformation: PTimeZoneInformation;
  lpUniversalTime, lpLocalTime: PSystemTime): BOOL; stdcall; external kernel32;
function TzSpecificLocalTimeToSystemTime(lpTimeZoneInformation: PTimeZoneInformation;
  lpLocalTime, lpUniversalTime: PSystemTime): BOOL; stdcall; external kernel32;
function LoadLibraryA(lpLibFileName: PAnsiChar): HMODULE; stdcall; external kernel32;
function LoadLibraryExA(lpLibFileName: PAnsiChar; hFile: HANDLE; dwFlags: DWORD): HMODULE; stdcall; external kernel32;
function GetProcAddress(hModule: HMODULE; lpProcName: PAnsiChar): Pointer; stdcall; external kernel32;
function FreeLibrary(hLibModule: HMODULE): BOOL; stdcall; external kernel32;
function GetModuleFileNameA(hModule: HMODULE; lpFilename: PAnsiChar; nSize: DWORD): DWORD; stdcall; external kernel32;
function FormatMessageA(dwFlags: DWORD; lpSource: Pointer; dwMessageId: DWORD; dwLanguageId: DWORD;
  lpBuffer: PAnsiChar; nSize: DWORD; Arguments: Pointer): DWORD; stdcall; external kernel32;
function GetProcessHeap: HANDLE; stdcall; external kernel32;
function HeapAlloc(hHeap: HANDLE; dwFlags: DWORD; dwBytes: NativeUInt): Pointer; stdcall; external kernel32;
function HeapReAlloc(hHeap: HANDLE; dwFlags: DWORD; lpMem: Pointer; dwBytes: NativeUInt): Pointer; stdcall; external kernel32;
function HeapFree(hHeap: HANDLE; dwFlags: DWORD; lpMem: Pointer): BOOL; stdcall; external kernel32;
function QueryPerformanceCounter(lpPerformanceCount: PInt64): BOOL; stdcall; external kernel32;
function QueryPerformanceFrequency(lpFrequency: PInt64): BOOL; stdcall; external kernel32;
function GetConsoleMode(hConsoleHandle: HANDLE; lpMode: PDWORD): BOOL; stdcall; external kernel32;

{$ENDIF}

implementation

end.
