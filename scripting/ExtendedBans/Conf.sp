/**
 * @section Local File variables
 */
static SMCParser  g_hConfParser;
static char       g_szConfigPath[PMP];

/**
 * @section Functions
 */
void Conf_Start() {
  LogEvent(Event_Debug, "Conf_Start()");

  Conf_PrepareParser();
  Conf_PreparePath();
}

void Conf_Read() {
  LogEvent(Event_Debug, "Conf_Read()");
  int line, col;

  SMCError res = g_hConfParser.ParseFile(g_szConfigPath, line, col);

  if (res != SMCError_Okay)
    LogEvent(Event_FatalError, "Couldn't parse configuration file (%s, %d:%d). Error code %d.", g_szConfigPath, line, col, res);
}

/**
 * @section Local Functions
 */
static void Conf_PrepareParser() {
  LogEvent(Event_Debug, "Conf_PrepareParser()");

  g_hConfParser = new SMCParser();
}

static void Conf_PreparePath() {
  LogEvent(Event_Debug, "Conf_PreparePath()");

}
