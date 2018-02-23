/**
 * @section Private module variables
 */
static int        g_iConnectSequence;
static ArrayStack g_hDBQueue;

enum QueueArgType {
  QueueArg_Cell,
  QueueArg_String,
  QueueArg_Array
}

enum DatabaseType {
  Unknown = -1,
  SQLite  = 0,
  MySQL   = 1
}

void DB_MakeQueue() {
  if (g_hDBQueue) {
    return; // queue already created
  }

  g_hDBQueue = new ArrayStack(4);
}

void DB_KilQueue() {
  if (g_hDBQueue == null) {
    return; // queue already killed
  }

  delete g_hDBQueue;
  g_hDBQueue = null;
}

void DB_Start() {
  if (g_hDB) {
    return; // we already connected.
  }

  int iSequence = ++g_iConnectSequence;
  LogEvent(Event_Debug, "DB_Start(): Sequence for connection: %d", iSequence);

  if (SQL_CheckConfig(g_szDbConfig))
    Database.Connect(DB_OnConnected, g_szDbConfig, iSequence);
  else {
    LogEvent(Event_Info, "Not found config in \"databases.cfg\". Connecting to SQLite local database...");
    char szError[256];
    Handle hDb = SQLite_UseDatabase(g_szDbConfig, szError, sizeof(szError));
    DB_OnConnected(hDb, szError, iSequence);
  }
}

void DB_Kill() {
  if (g_hDB == null) {
      return; // database connection already killed.
  }

  LogEvent(Event_Debug, "DB_Kill()");
  delete g_hDB;
  g_hDB = null;
  g_bDBReady = false;
}

void DB_DetectType(DBDriver hDriver) {
  char szIdent[16];
  hDriver.GetIdentifier(szIdent, sizeof(szIdent));

  if (strcmp(szIdent, "mysql") == 0) {
    g_iDBType = MySQL;
  } else if (strcmp(szIdent, "sqlite") == 0) {
    g_iDBType = SQLite;
  } else {
    g_iDBType = Unknown;
  }
}

void DB_MakeTables() {
  Transaction hTxn = new Transaction();

  switch (g_iDBType) {
    case SQLite:  {
      hTxn.AddQuery("...");
    }

    case MySQL:   {
      hTxn.AddQuery("...");
    }
  }

  DB_ExecTxn(hTxn, DB_TablesOk, DB_TablesFail, DBPrio_High, 0);
}

/**
 * @section Database helpers
 */
bool DB_IsAlive() {
  return (g_hDB != null);
}

int DB_ProcessQueue(int iTaskCount = 1) {
  if (!DB_IsAlive())
    return 0;

  int iProcessTaskCount;
  DataPack hTask;

  ArrayList hTypes, hValues;
  int iArgsLength, iCurrentValuePos;

  while (!g_hDBQueue.Empty || iTaskCount == 0 || iProcessTaskCount < iTaskCount) {
    // get task
    hTask = g_hDBQueue.Pop();
    hTask.Reset();

    // start executing task...
    Call_StartFunction(null, hTask.ReadCell());

    // get all arg values and types, and handle him.
    hTypes  = hTask.ReadCell();
    hValues = hTask.ReadCell();

    iArgsLength = hTypes.Length;
    for (int iCurrentTypePos; iCurrentTypePos < iArgsLength; ++iCurrentTypePos) {
      switch (view_as<QueueArgType>(hTypes.Get(iCurrentTypePos))) {
        case QueueArg_String: {
          int iStrLen = hValues.Get(iCurrentValuePos++) + 1;
          char[] szBuffer = new char[iStrLen];

          hValues.GetString(iCurrentValuePos++, szBuffer, iStrLen);
          Call_PushString(szBuffer);
        }

        case QueueArg_Array:  {
          int iArrLength = hValues.Get(iCurrentValuePos++) + 1;
          any[] arr = new any[iArrLength];

          hValues.GetArray(iCurrentValuePos++, arr, iArrLength);
          Call_PushArray(arr, iArrLength);
        }

        case QueueArg_Cell:   Call_PushCell(hValues.Get(iCurrentValuePos++));
      }
    }

    // finish call.
    Call_Finish();

    // clean memory
    delete hTask;
    delete hTypes;
    delete hValues;

    // increment executed tasks count.
    iProcessTaskCount++;
  }

  return iProcessTaskCount;
}

void DB_AddToQueue(Function ptrFunction, ArrayList &hArgTypes, ArrayList &hArgValues) {
  DataPack hPack  = new DataPack();
  hArgTypes       = new ArrayList();
  hArgValues      = new ArrayList();

  LogEvent(Event_Info, "Adding DB Queue task...");
  LogEvent(Event_Debug, "DB Queue Task pointers: %x %x %x %x", ptrFunction, hPack, hArgTypes, hArgValues);

  hPack.WriteCell(ptrFunction);
  hPack.WriteCell(hArgTypes);
  hPack.WriteCell(hArgValues);

  g_hDBQueue.Push(hPack);
}

void DB_ExecTxn(Transaction hTxn, SQLTxnSuccess ptrSuccess, SQLTxnFailure ptrFailure, DBPriority ePriority = DBPrio_Normal, any data = 0) {
  if (!DB_IsAlive()) {
    if (!g_bUseDBQueue)
      return;

    ArrayList hQueueArgTypes, hQueueArgValues;
    DB_AddToQueue(DB_ExecTxn, hQueueArgTypes, hQueueArgValues);

    for (int i; i < 5; ++i)
      hQueueArgTypes.Push(QueueArg_Cell);

    hQueueArgValues.Push(hTxn);
    hQueueArgValues.Push(ptrSuccess);
    hQueueArgValues.Push(ptrFailure);
    hQueueArgValues.Push(ePriority);
    hQueueArgValues.Push(data);
    return;
  }

  g_hDB.Execute(hTxn, ptrSuccess, ptrFailure, data, ePriority);
}

void DB_ExecQuery(const char[] szQuery, SQLQueryCallback ptrCallback, DBPriority ePrio = DBPrio_Normal, any data = 0) {
  if (!DB_IsAlive()) {
    if (!g_bUseDBQueue)
      return;

    ArrayList hQueueArgTypes, hQueueArgValues;
    DB_AddToQueue(DB_ExecQuery, hQueueArgTypes, hQueueArgValues);

    hQueueArgTypes.Push(QueueArg_String);
    for (int i; i < 3; ++i)
      hQueueArgTypes.Push(QueueArg_Cell);

    hQueueArgValues.Push(strlen(szQuery));
    hQueueArgValues.PushString(szQuery);
    hQueueArgValues.Push(ptrCallback);
    hQueueArgValues.Push(ePriority);
    hQueueArgValues.Push(data);
  }

  g_hDB.Query(ptrCallback, szQuery, data, ePriority);
}

/**
 * @section Database callbacks
 */
public void DB_OnConnected(Database hDb, const char[] szError, int iSeqId) {
  if (szError[0] != 0) {
    LogEvent(Event_Error, "Couldn't connect to database: %s. Sequence ID: %d", szError, iSeqId);
    LogEvent(Event_Info, "Attempt to connect to the database in 30 seconds.");

    CreateTimer(30.0, DB_RetryConnect);
    return;
  }

  if (iSeqId != g_iConnectSequence) {
    LogEvent(Event_Error, "Invalid connection sequence (received %d, expected %d). Killing this connection...", iSeqId, g_iConnectSequence);
    delete hDb;
    return;
  }

  LogEvent(Event_Info, "Connection with database installed.");
  DB_DetectType(hDB.Driver);

  if (g_iDBType == Unknown) {
    LogEvent(Event_Error, "Unknown database type.");
    LogEvent(Event_Info, "Database connection will be killed.");

    // DB_Kill();
    delete hDB;

    LogEvent(Event_Info, "Waiting 300 seconds before new connection...");
    CreateTimer(300.0, DB_RetryConnect);
    return;
  }

  // all ok. save handle.
  g_hDB = hDb;
  LogEvent(Event_Info, "Detected database type: %d", g_iDBType);
  DB_MakeTables();
}

public void DB_TablesOk(Database hDb, any data, int iNumQueries, DBResultSet[] hResponses, any[] queryData) {
  g_bDBReady = true;
  LogEvent(Event_Info, "Database is ready. All tables created.");
}

public void DB_TablesFail(Database hDb, any data, int iNumQueries, const char[] szError, int iFailIndex, any[] queryData) {
  LogEvent(Event_FatalError, "Couldn't create database tables: %s", szError);
  SetFailState("Couldn't create database tables. See more information in ExtendedBans log flle.");
}

public void DB_GenericCallback(Database hDb, DBResultSet hRsponse, const char[] szError, DataPack hPack) {
  if (szError[0] != 0) {
    hPack.Reset();
    int iLength = hPack.ReadCell() + 1;
    char[] szBuffer = new char[iLength];
    hPack.ReadString(szBuffer, sizeof(szBuffer));

    LogEvent(Event_Error, "Query failure: %s. SQL Query Dump: %s", szError, szBuffer);
  }

  delete hPack;
}
