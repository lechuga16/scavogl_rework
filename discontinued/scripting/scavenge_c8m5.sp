#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>

#define PLUGIN_VERSION "2.0"

Handle
	g_hTimerH = null;
	
ConVar
	g_cvarAnnouncer = null;

public Plugin myinfo =
{
	name		= "Scavenge No Mercy Rooftop",
	author		= "Ratchet, lechuga",
	description = "Burn the cans that are out of reach.",
	version		= PLUGIN_VERSION,
	url			= ""
}

public void OnPluginStart()
{
	LoadTranslation("scavenge_c8m5.phrases");
	g_cvarAnnouncer = CreateConVar("sm_scavenge_c8m5_announcer", "1", "Enable/Disable the announcer", FCVAR_NONE, true, 0.0, true, 1.0);
}

public void OnPluginEnd()
{
	if (g_hTimerH != null)
		delete g_hTimerH;
}

public void OnMapEnd()
{
	/*
	 * Sometimes the event 'round_start' is called before OnMapStart()
	 * and the timer handle is not reset, so it's better to do it here.
	 */
	if (g_hTimerH != null)
		delete g_hTimerH;
}

public void OnMapStart()
{
	if (!IsScavengeGameMode() || !CurrentMap())
		return;

	if (g_hTimerH != null)
		delete g_hTimerH;

	g_hTimerH = CreateTimer(15.0, Scavg_hTimerH, _, TIMER_REPEAT);
}

public Action Scavg_hTimerH(Handle Timer, any Client)
{
	FindMisplacedCans();
	return Plugin_Continue;
}

/**
 * Finds misplaced gas cans and ignites them.
 */
void FindMisplacedCans()
{
	int iEnt = -1;

	while ((iEnt = FindEntityByClassname(iEnt, "weapon_gascan")) != -1)
	{
		if (!IsValidEntity(iEnt))
			continue;

		float fPosition[3];
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fPosition);

		if ((fPosition[2] <= 500.0) && (fPosition[0] > 0.0 && fPosition[1] > 0.0 && fPosition[2]))
			IgniteGascan(iEnt);
	}
}

/**
 * Ignites a gas can entity.
 *
 * @param iEntity The entity index of the gas can to ignite.
 */
void IgniteGascan(int iEntity)
{
	AcceptEntityInput(iEntity, "ignite");
	if (g_cvarAnnouncer.BoolValue)
		CPrintToChatAll("%t %t", "Tag", "BurnGascan");
}

/**
 * Check if the translation file exists
 *
 * @param translation	Translation name.
 * @noreturn
 */
stock void LoadTranslation(const char[] translation)
{
	char
		sPath[PLATFORM_MAX_PATH],
		sName[64];

	Format(sName, sizeof(sName), "translations/%s.txt", translation);
	BuildPath(Path_SM, sPath, sizeof(sPath), sName);
	if (!FileExists(sPath))
		SetFailState("Missing translation file %s.txt", translation);

	LoadTranslations(translation);
}

/**
 * Determines if the current map is "c8m5_rooftop".
 *
 * @return True if the current map is "c8m5_rooftop", false otherwise.
 */
bool CurrentMap()
{
	char sMapName[128];
	GetCurrentMap(sMapName, sizeof(sMapName));

	if (StrEqual(sMapName, "c8m5_rooftop", false))
		return true;

	return false;
}

/**
 * Checks if the current game mode is "scavenge".
 *
 * @return True if the game mode is "scavenge", false otherwise.
 */
bool IsScavengeGameMode()
{
	char sGameMode[32];
	FindConVar("mp_gamemode").GetString(sGameMode, sizeof(sGameMode));

	if (StrEqual(sGameMode, "scavenge", false))
		return true;
	
	return false;
}