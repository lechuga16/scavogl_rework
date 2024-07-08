#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <colors>
#include <builtinvotes>
#include <left4dhooks>
#undef REQUIRE_PLUGIN
#include <confogl>
#include <readyup>
#define REQUIRE_PLUGIN

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

#define PLUGIN_VERSION "1.0.1"
#define CFG_VERSION	   "v2.3.2"
#define CONSOLE		   0

ConVar
	g_cvarDebug,
	g_cvarEnable,
	g_cvarPrintCvar,
	g_cvarCFGName,

	z_versus_hunter_limit,
	z_versus_boomer_limit,
	z_versus_smoker_limit,
	z_versus_jockey_limit,
	z_versus_charger_limit,
	z_versus_spitter_limit;

char
	g_sConfigName[16];

Handle
	g_hVote;

enum Mode
{
	mode_none = 0,
	mode_1v1  = 1,
	mode_2v2  = 2,
	mode_3v3  = 3,
	mode_4v4  = 4,

	mode_size = 5
}

stock const char sScavMode[mode_size][] = {
	"scav_none",
	"scav1v1",
	"scav2v2",
	"scav3v3",
	"scavogl"
};

stock const char sHunterMode[mode_size][] = {
	"scavh_none",
	"scavh1v1",
	"scavh2v2",
	"scavh3v3",
	"scavhunters"
};

stock const char sScavName[mode_size][] = {
	"scav_none",
	"1v1 ScavOgl",
	"2v2 ScavOgl",
	"3v3 ScavOgl",
	"ScavOgl"
};

stock const char sHunterName[mode_size][] = {
	"scavh_none",
	"1v1 ScavHunters",
	"2v2 ScavHunters",
	"2v2 ScavHunters",
	"ScavHunters"
};

enum struct GameMode
{
	Mode mode;
	bool ishunter;
}

GameMode
	g_gmVote;

/*****************************************************************
			P L U G I N   I N F O
*****************************************************************/

public Plugin myinfo =
{
	name		= "Scavenge GameMode",
	author		= "Lechuga",
	description = "Manages cvar related to the game mode and allows changing it",
	version		= PLUGIN_VERSION,
	url			= "https://github.com/lechuga16/scavogl_rework"
};

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (!L4D_IsEngineLeft4Dead2())
		SetFailState("Plugin supports Left 4 dead 2 only!");

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslation("scavenge_gamemode.phrases");
	CreateConVar("sm_scavenge_gamemode_version", PLUGIN_VERSION, "Scavenge Rounds version", FCVAR_NOTIFY, true, 0.0);

	g_cvarDebug			   = CreateConVar("sm_scavenge_gamemode_debug", "0", "Enable debug", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarEnable		   = CreateConVar("sm_scavenge_gamemode_enable", "1", "Enable Scavenge Rounds", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarPrintCvar		   = CreateConVar("sm_scavenge_gamemode_printcvar", "1", "Print cvar changes", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarCFGName		   = CreateConVar("sm_scavenge_gamemode_forcename", "0", "Force the convar l4d_ready_cfg_name according to the game mode.", FCVAR_NOTIFY, true, 0.0, true, 1.0);	

	z_versus_hunter_limit  = FindConVar("z_versus_hunter_limit");
	z_versus_boomer_limit  = FindConVar("z_versus_boomer_limit");
	z_versus_smoker_limit  = FindConVar("z_versus_smoker_limit");
	z_versus_jockey_limit  = FindConVar("z_versus_jockey_limit");
	z_versus_charger_limit = FindConVar("z_versus_charger_limit");
	z_versus_spitter_limit = FindConVar("z_versus_spitter_limit");

	z_versus_hunter_limit.AddChangeHook(OnVersusLimitChange);
	z_versus_boomer_limit.AddChangeHook(OnVersusLimitChange);
	z_versus_smoker_limit.AddChangeHook(OnVersusLimitChange);
	z_versus_jockey_limit.AddChangeHook(OnVersusLimitChange);
	z_versus_charger_limit.AddChangeHook(OnVersusLimitChange);
	z_versus_spitter_limit.AddChangeHook(OnVersusLimitChange);

	RegConsoleCmd("sm_scavmode", ModeRequest);
	RegServerCmd("z_scavogl_infected_limit", InfectedLimit);
}

public void OnVersusLimitChange(ConVar Convar, const char[] sOldValue, const char[] sNewValue)
{
	if (!g_cvarEnable.BoolValue || !L4D2_IsScavengeMode() || !g_cvarPrintCvar.BoolValue)
		return;

	char sCvarName[32];
	Convar.GetName(sCvarName, sizeof(sCvarName));
	CPrintToChatAll("[ScavOgl] Server CVar '%s' changed from '%s' to '%s'", sCvarName, sOldValue, sNewValue);
}

public Action ModeRequest(int iClient, int iArgs)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "Disabled");
		return Plugin_Handled;
	}

	if (!L4D2_IsScavengeMode())
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "GameMode");
		return Plugin_Handled;
	}

	if (iArgs > 0)
	{
		if (!CheckCommandAccess(iClient, "sm_kick", ADMFLAG_KICK))
		{
			CReplyToCommand(iClient, "%t %t", "Tag", "NoAccess");
			return Plugin_Handled;
		}

		char sGamemode[32];
		GetCmdArg(1, sGamemode, sizeof(sGamemode));
		CurrentConfigName();

		GameMode
			gmArg,
			gmCurrent;

		bool bArgGameMode	  = GetGamemode(sGamemode, gmArg);
		bool bCurrentGameMode = GetGamemode(g_sConfigName, gmCurrent);

		if (!bCurrentGameMode)
		{
			CReplyToCommand(iClient, "%t %t", "Tag", "ModeNoSupported");
			return Plugin_Handled;
		}

		char sCorrectMode[16];
		Format(sCorrectMode, sizeof(sCorrectMode), "%s", gmCurrent.ishunter ? sScavMode[gmCurrent.mode] : sHunterMode[gmCurrent.mode]);

		if (!bArgGameMode || !StrEqual(sGamemode, sCorrectMode))
		{
			CReplyToCommand(iClient, "%t %t sm_scavmode %s", "Tag", "Usage", sCorrectMode);
			return Plugin_Handled;
		}

		ChangeGameMode(gmArg);
		return Plugin_Handled;
	}

	ModeMenu(iClient);
	return Plugin_Handled;
}

public Action InfectedLimit(int iArgs)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(CONSOLE, "%t %t", "Tag", "Disabled");
		return Plugin_Handled;
	}

	if (!L4D2_IsScavengeMode())
	{
		CReplyToCommand(CONSOLE, "%t %t", "Tag", "GameMode");
		return Plugin_Handled;
	}

	char sGamemode[32];
	GetCmdArg(1, sGamemode, sizeof(sGamemode));

	GameMode gmArg;
	bool	 bArgGameMode = GetGamemode(sGamemode, gmArg);

	if (!bArgGameMode)
	{
		CReplyToCommand(CONSOLE, "%t %t z_scavogl_infected_limit <scav1v1|scav2v2|scav3v3|scavogl>", "Tag", "Usage");
		return Plugin_Handled;
	}

	g_cvarPrintCvar.SetInt(0);
	ChangeGameMode(gmArg, false);
	g_cvarPrintCvar.SetInt(1);
	return Plugin_Handled;
}

public void OnPluginEnd()
{
	z_versus_hunter_limit.RestoreDefault();
	z_versus_boomer_limit.RestoreDefault();
	z_versus_smoker_limit.RestoreDefault();
	z_versus_jockey_limit.RestoreDefault();
	z_versus_charger_limit.RestoreDefault();
	z_versus_spitter_limit.RestoreDefault();

	if (g_cvarCFGName.BoolValue)
		FindConVar("l4d_ready_cfg_name").RestoreDefault();
}

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

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
 * Prints a debug message to the server console.
 *
 * @param sMessage The message to be printed.
 * @param ... Additional arguments to be formatted into the message.
 */
void PrintDebug(const char[] sMessage, any...)
{
	if (!g_cvarDebug.BoolValue)
		return;

	static char sFormat[512];
	VFormat(sFormat, sizeof(sFormat), sMessage, 2);

	PrintToServer("[Scavenge] %s", sFormat);
}

/**
 * Displays the mode menu to the specified client.
 *
 * @param iClient The client index.
 */
void ModeMenu(int iClient)
{
	CurrentConfigName();

	GameMode gm;
	if (!GetGamemode(g_sConfigName, gm))
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "ModeNoSupported");
		return;
	}

	if (gm.mode == mode_none)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "Error_InvalidMode");
		return;
	}

	char sGamemode[32];
	Format(sGamemode, sizeof(sGamemode), "%s", gm.ishunter ? sScavMode[gm.mode] : sHunterMode[gm.mode]);

	Menu hMenu = new Menu(MenuHandler, MENU_ACTIONS_ALL);
	hMenu.SetTitle("%t", "MenuTitle");
	hMenu.AddItem(sGamemode, sGamemode);

	hMenu.Display(iClient, 20);
}

public int MenuHandler(Menu menu, MenuAction action, int iParam, int iParam2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			int	 iClient = iParam;
			char sInfo[32];
			menu.GetItem(iParam2, sInfo, sizeof(sInfo));
			GameMode gm;

			GetGamemode(sInfo, gm);

			if (gm.mode == mode_none)
			{
				CPrintToChat(iClient, "%t %t", "Tag", "Error_InvalidMode");
				return 0;
			}

			if (CreateVote(iClient, gm) && !g_cvarDebug.BoolValue)
				FakeClientCommand(iParam, "Vote Yes");
		}
		case MenuAction_End: delete menu;
	}

	return 0;
}

/**
 * Creates a vote for the specified client and game mode.
 *
 * @param iClient The client index initiating the vote.
 * @param gm The game mode to be voted on.
 */
bool CreateVote(int iClient, GameMode gm)
{
	if (L4D_GetClientTeam(iClient) <= L4DTeam_Spectator)
	{
		CPrintToChat(iClient, "%t %t", "Tag", "VoteSpect");
		return false;
	}

	if (IsBuiltinVoteInProgress())
	{
		CPrintToChat(iClient, "%t %t", "Tag", "VoteInProgress");
		return false;
	}

	if (!IsInReady())
	{
		CPrintToChat(iClient, "%t %t", "Tag", "MatchInProgress");
		return false;
	}

	int iNumPlayers = 0;
	int[] iPlayers	= new int[MaxClients];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || L4D_GetClientTeam(i) <= L4DTeam_Spectator)
			continue;

		iPlayers[iNumPlayers++] = i;
	}

	char sBuffer[64];
	Format(sBuffer, sizeof(sBuffer), "%t", "Question", gm.ishunter ? sHunterName[gm.mode] : sScavName[gm.mode]);
	g_gmVote = gm;

	g_hVote	 = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
	SetBuiltinVoteArgument(g_hVote, sBuffer);
	SetBuiltinVoteInitiator(g_hVote, iClient);
	SetBuiltinVoteResultCallback(g_hVote, MatchVoteResultHandler);
	DisplayBuiltinVote(g_hVote, iPlayers, iNumPlayers, 20);

	return true;
}

public void VoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			delete vote;
			g_hVote			  = null;
			g_gmVote.mode	  = mode_none;
			g_gmVote.ishunter = false;
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
		}
	}
}

public void MatchVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				DisplayBuiltinVotePass2(vote, "VotePassed");

				g_cvarPrintCvar.SetInt(0);
				ChangeGameMode(g_gmVote);
				g_cvarPrintCvar.SetInt(1);

				g_gmVote.mode	  = mode_none;
				g_gmVote.ishunter = false;
				return;
			}
		}
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

/**
 * Determines the game mode based on the provided gamemode string.
 *
 * @param sGamemode The gamemode string to check.
 * @param gm The GameMode struct to store the result.
 * @return True if the gamemode was found, false otherwise.
 */
bool GetGamemode(const char[] sGamemode, GameMode gm)
{
	bool bFound = false;
	gm.mode		= mode_none;
	for (Mode i = mode_none; i <= mode_4v4; i++)
	{
		bool
			bScav = StrEqual(sScavMode[i], sGamemode),
			bHunt = StrEqual(sHunterMode[i], sGamemode);

		PrintDebug("Gamemode: %s | %s: %d | %s: %d", sGamemode, sScavMode[i], view_as<int>(bScav), sHunterMode[i], view_as<int>(bHunt));
		if (bScav || bHunt)
		{
			gm.ishunter = bHunt;
			gm.mode		= i;
			bFound		= true;
		}
	}
	return bFound;
}

/**
 * Changes the configuration name based on the game mode.
 *
 * @param gm The GameMode struct containing information about the game mode.
 */
void ChangeCFGName(GameMode gm)
{
	char sConfigName[32];

	if (gm.ishunter)
	{
		Format(sConfigName, sizeof(sConfigName), "%s %s", sHunterName[gm.mode], CFG_VERSION);
		strcopy(g_sConfigName, sizeof(g_sConfigName), sHunterMode[gm.mode]);
	}
	else
	{
		Format(sConfigName, sizeof(sConfigName), "%s %s", sScavName[gm.mode], CFG_VERSION);
		strcopy(g_sConfigName, sizeof(g_sConfigName), sScavMode[gm.mode]);
	}

	if (g_cvarCFGName.BoolValue)
	{
		PrintDebug("CFG Name: %s | Mode Name: %s", sConfigName, g_sConfigName);
		FindConVar("l4d_ready_cfg_name").SetString(sConfigName);
	}
}

/**
 * Changes the game mode and updates the corresponding configuration values.
 *
 * @param gm The new game mode to be set.
 */
void ChangeGameMode(GameMode gm, bool bAnnounce = true)
{
	ChangeCFGName(gm);

	if (bAnnounce)
		CPrintToChatAll("%T %t %s", "Tag", LANG_SERVER, "ChangeMode", gm.ishunter ? sHunterName[gm.mode] : sScavName[gm.mode]);

	switch (gm.mode)
	{
		case mode_1v1:
		{
			if (gm.ishunter)
				z_versus_jockey_limit.SetInt(0);
			else
				z_versus_jockey_limit.SetInt(1);

			z_versus_charger_limit.SetInt(0);
			z_versus_smoker_limit.SetInt(0);
			z_versus_boomer_limit.SetInt(0);
			z_versus_spitter_limit.SetInt(0);
		}
		case mode_2v2:
		{
			if (gm.ishunter)
			{
				z_versus_hunter_limit.SetInt(2);
				z_versus_jockey_limit.SetInt(0);
				z_versus_charger_limit.SetInt(0);
			}
			else
			{
				z_versus_hunter_limit.SetInt(1);
				z_versus_jockey_limit.SetInt(1);
				z_versus_charger_limit.SetInt(1);
			}

			z_versus_smoker_limit.SetInt(0);
			z_versus_boomer_limit.SetInt(0);
			z_versus_spitter_limit.SetInt(0);
		}
		case mode_3v3:
		{
			if (gm.ishunter)
			{
				z_versus_hunter_limit.SetInt(3);
				z_versus_smoker_limit.SetInt(0);
				z_versus_jockey_limit.SetInt(0);
				z_versus_charger_limit.SetInt(0);
			}
			else
			{
				z_versus_hunter_limit.SetInt(1);
				z_versus_smoker_limit.SetInt(1);
				z_versus_jockey_limit.SetInt(1);
				z_versus_charger_limit.SetInt(1);
			}

			z_versus_boomer_limit.SetInt(0);
			z_versus_spitter_limit.SetInt(0);
		}
		case mode_4v4:
		{
			if (gm.ishunter)
			{
				z_versus_hunter_limit.SetInt(4);
				z_versus_boomer_limit.SetInt(0);
				z_versus_smoker_limit.SetInt(0);
				z_versus_jockey_limit.SetInt(0);
				z_versus_charger_limit.SetInt(0);
				z_versus_spitter_limit.SetInt(0);
			}
			else
			{
				z_versus_hunter_limit.SetInt(1);
				z_versus_boomer_limit.SetInt(1);
				z_versus_smoker_limit.SetInt(1);
				z_versus_jockey_limit.SetInt(1);
				z_versus_charger_limit.SetInt(1);
				z_versus_spitter_limit.SetInt(1);
			}
		}
	}
}

/**
 * Retrieves the current configuration name.
 * If the global variable `g_sConfigName` is empty, it calls `LGO_GetConfigName` to get the configuration name
 * and copies it to `g_sConfigName`.
 */
void CurrentConfigName()
{
	if (StrEqual(g_sConfigName, ""))
	{
		char sConfigName[16];
		LGO_GetConfigName(sConfigName, sizeof(sConfigName));

		strcopy(g_sConfigName, sizeof(g_sConfigName), sConfigName);
	}
}