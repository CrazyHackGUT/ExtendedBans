static char g_szLogFile[PMP];

#define LogEvent(%0,%1)    __LogEvent(__LINE__, __FILE__, %0, %1)

enum EventType {
    Event_FatalError    = 0,
    Event_Error         = 1,
    Event_Warning       = 2,
    Event_Info          = 3,
    Event_Debug         = 4
}

void Logger_Start() {
  BuildPath(Path_SM, SZFS(g_szLogFile), "logs/ExtendedBans.log");
}

void __LogEvent(int iLineNumber, const char[] szFilePath, const EventType eEType, const char[] szFormatRules, any ...) {
  if (view_as<int>(eEType) > g_iLoggerLevel) {
    return; // we don't log this. current log level don't allows this action.
  }

  char szLogEntry[2560];
  int iStartPos = FormatEx(SZFS(szLogEntry), "[%s / %s:%d] ", __GetLogEventTypeName(eEType), szFilePath, iLineNumber);
  VFormat(szLogEntry[iStartPos], (sizeof(szLogEntry)-iStartPos), szFormatRules, 5);
  LogToFileEx(g_szLogFile, "%s", szLogEntry);
}

char __GetLogEventTypeName(const EventType eEType) {
  char szEventName[12];
  switch (eEType) {
    case Event_FatalError:  strcopy(SZFS(szEventName), "FATAL ERROR");
    case Event_Error:       strcopy(SZFS(szEventName), "ERROR");
    case Event_Warning:     strcopy(SZFS(szEventName), "WARNING");
    case Event_Info:        strcopy(SZFS(szEventName), "INFORMATION");
    case Event_Debug:       strcopy(SZFS(szEventName), "DEBUG");
  }
  return szEventName;
}
