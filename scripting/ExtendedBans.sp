#include <sourcemod>
#include <dbi>

#pragma newdecls  required
#pragma semicolon 1

public Plugin myinfo = {
  description = "Simple ban system with support MySQL, SQLite",
  version     = "0.0.0.0",
  author      = "CrazyHackGUT aka Kruzya",
  name        = "Extended Bans",
  url         = "https://kruzefag.ru/"
};

/**
 * @section Global Variables
 */
Database        g_hDB;
DatabaseType    g_iDBType = Unknown;
bool            g_bDBReady;
bool            g_bUseDBQueue;

/**
 * @section Includes
 */
#include "ExtendedBans/Defines.sp"
#include "ExtendedBans/Logger.sp"
#include "ExtendedBans/Conf.sp"
#include "ExtendedBans/DB.sp"

// #include "ExtendedBans/AdminMenu.sp"
// #include "ExtendedBans/Comms.sp"
// #include "ExtendedBans/Ban.sp"

/**
 * @section Generic SM events
 */
public void OnPluginStart() {
  /**
   * TODO: implement this methods and add calling here:
   * * AdminMenu_Start();
   * * Comms_Start();
   * * Ban_Start();
   */

  // We should init logger firstly.
  Logger_Start();

  // Read config.
  Conf_Start();
  Conf_Read();

  // Prepare DB queue.
  DB_MakeQueue();
}

public void OnAllPluginsLoaded() {
  // start connection with database.
  DB_Start();
}

public void OnPluginEnd() {
  // TODO: Unmute, ungag all clients.
}
