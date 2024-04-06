#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <colors>
#include <left4dhooks>
#include <builtinvotes>
#undef REQUIRE_PLUGIN
#include <confogl>
#include <readyup>
#define REQUIRE_PLUGIN

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

#define PLUGIN_VERSION "1.0"

ConVar
	g_cvarDebug,
	g_cvarEnable,
	g_cvarRounds,
	g_cvarRestartRound;

Handle
	g_hVote;

bool
	g_bConfoglAvailable = false,
	g_bReadyupAvailable = false;

int
	g_iVoteRounds = 0,
	g_iTimerRestartMatch;

/*****************************************************************
			P L U G I N   I N F O
*****************************************************************/

public Plugin myinfo =
{
	name		= "Scavenge Rounds",
	author		= "Lechuga",
	description = "Allows you to adjust the number of rounds",
	version		= PLUGIN_VERSION,
	url			= "https://github.com/lechuga16/scavogl_rework"
};

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
		SetFailState("Plugin supports Left 4 dead 2 only!");

	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_bConfoglAvailable = LibraryExists("confogl");
}

public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, "confogl"))
		g_bConfoglAvailable = false;
}

public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, "confogl"))
		g_bConfoglAvailable = true;
}

public void OnPluginStart()
{
	LoadTranslation("scavenge_rounds.phrases");
	CreateConVar("sm_scavenge_rounds_version", PLUGIN_VERSION, "Scavenge Rounds version", FCVAR_NOTIFY, true, 0.0);

	g_cvarDebug		   = CreateConVar("sm_scavenge_rounds_debug", "0", "Enable debug", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarEnable	   = CreateConVar("sm_scavenge_rounds_enable", "1", "Enable Scavenge Rounds", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarRounds	   = CreateConVar("sm_scavenge_rounds", "5", "number of rounds (1, 3 and 5 allowed)", FCVAR_NOTIFY, true, 1.0, true, 5.0);
	g_cvarRestartRound = CreateConVar("sm_scavenge_restart_round", "1", "Restart round after finish match", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("scavenge_match_finished", Event_ScavMatchFinished, EventHookMode_Post);
	g_cvarRounds.AddChangeHook(OnRoundsChange);

	RegConsoleCmd("sm_scavrounds", RoundsRequest);
}

public Action RoundsRequest(int iClient, int iArgs)
{
	if (!g_cvarEnable.BoolValue)
	{
		CPrintToChat(iClient, "%t %t", "Tag", "Disabled");
		return Plugin_Handled;
	}

	if (!L4D2_IsScavengeMode())
	{
		CPrintToChat(iClient, "%t %t", "Tag", "GameMode");
		return Plugin_Handled;
	}

	if (iArgs < 1 || iArgs > 1)
	{
		CPrintToChat(iClient, "%t %t", "Tag", "InvalidRounds");
		return Plugin_Handled;
	}

	int iRounds = GetCmdArgInt(1);
	if (iRounds != 1 && iRounds != 3 && iRounds != 5)
	{
		CPrintToChat(iClient, "%t %t", "Tag", "InvalidRounds");
		return Plugin_Handled;
	}

	if (StartRoundVote(iClient, iRounds) && !g_cvarDebug.BoolValue)
		FakeClientCommand(iClient, "Vote Yes");

	return Plugin_Handled;
}

bool StartRoundVote(int iClient, int iRounds)
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

	if (g_bReadyupAvailable && !IsInReady())
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
	Format(sBuffer, sizeof(sBuffer), "%t", "Question", iRounds);
	g_iVoteRounds = iRounds;

	g_hVote		  = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
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
			g_hVote = null;
			g_iVoteRounds = 0;
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
				g_cvarRounds.SetInt(g_iVoteRounds);
				g_iVoteRounds = 0;
				return;
			}
		}
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public void OnPluginEnd()
{
	FindConVar("scavenge_match_finished_delay").RestoreDefault();
	if (!IsBuiltinVoteInProgress())
		return;

	CancelBuiltinVote();
	delete g_hVote;
	g_hVote = null;
}

public void OnRoundsChange(ConVar Convar, const char[] sOldValue, const char[] sNewValue)
{
	int iNewValue = StringToInt(sNewValue);

	switch (iNewValue)
	{
		case 1: ChangeRounds(iNewValue);
		case 3: ChangeRounds(iNewValue);
		case 5: ChangeRounds(iNewValue);
		default:
		{
			Convar.SetInt(StringToInt(sOldValue));
			CPrintToChatAll("%t %t", "Tag", "InvalidRounds");
		}
	}
}

/****************************************************************
			C A L L B A C K   F U N C T I O N S
****************************************************************/

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cvarEnable.BoolValue || !L4D2_IsScavengeMode())
		return;

	if (!g_bConfoglAvailable || !LGO_IsMatchModeLoaded())
		return;

	if (GameRules_GetProp("m_nRoundLimit") == g_cvarRounds.IntValue)
		return;

	GameRules_SetProp("m_nRoundLimit", g_cvarRounds.IntValue);
}

public void Event_ScavMatchFinished(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cvarEnable.BoolValue || !g_cvarRestartRound.BoolValue)
		return;

	FindConVar("scavenge_match_finished_delay").SetInt(30);
	g_iTimerRestartMatch = 10;
	CreateTimer(1.0, Timer_RestartMatch, _, TIMER_REPEAT);
}

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

Action Timer_RestartMatch(Handle Timer)
{
	if(g_iTimerRestartMatch == 0)
	{
		L4D2_Rematch();
		return Plugin_Stop;
	}
	else if(g_iTimerRestartMatch < 4)
		CPrintToChatAll("%t %t", "Tag", "MatchRestarted", g_iTimerRestartMatch);

	g_iTimerRestartMatch--;
	return Plugin_Continue;
}

/**
 * Changes the number of rounds in the game.
 *
 * @param iRounds The new number of rounds.
 */
void ChangeRounds(int iRounds)
{
	GameRules_SetProp("m_nRoundLimit", iRounds);

	ResetRoundNumber();
	PrintDebug("Rounds changed to %d", iRounds);
}

/**
 * Resets the round number in the game.
 */
void ResetRoundNumber()
{
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(LoadGameConfigFile("left4dhooks.l4d2"), SDKConf_Signature, "CTerrorGameRules_ResetRoundNumber");
	Handle func = EndPrepSDKCall();

	if (func == INVALID_HANDLE)
		ThrowError("Failed to end prep sdk call");

	SDKCall(func);
	CloseHandle(func);
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