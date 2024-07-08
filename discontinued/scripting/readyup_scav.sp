#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <readyup>
#include <left4dhooks>

ConVar
	g_cvarScavRestart,
	g_cvarScavRounds;

public Plugin myinfo =
{
	name		= "Readyup_Scav",
	author		= "Lechuga",
	description = "fix some bugs and allow to select the number of rounds",
	version		= "1.1",
	url			= "https://github.com/lechuga16/Readyup_Scav"
};

public void OnPluginStart()
{
	g_cvarScavRestart = CreateConVar("sm_readyup_scav_restart", "1", "Mark the first raund for a double reset.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarScavRounds  = CreateConVar("sm_readyup_scav_rounds", "5", "Set the number of rounds", FCVAR_NOTIFY, true, 1.0, true, 5.0);
}

public void OnRoundIsLive()
{
	if (!L4D2_IsScavengeMode())
		return;
		
	if (!ShouldResetRoundTwiceToGoLive())
		return;

	GameRules_SetProp("m_nRoundLimit", g_cvarScavRounds.IntValue);
	PrintHintTextToAll("Match will be live\nafter 2 round restarts.");
	RestartCampaignAny();
}

/**
 * Determines whether the round should be reset twice before going live.
 *
 * @return True if the round should be reset twice, false otherwise.
 */
bool ShouldResetRoundTwiceToGoLive()
{
	if (g_cvarScavRestart.BoolValue || GameRules_GetProp("m_nRoundNumber") != 1)
		return false;

	return true;
}

/**
 * Restarts the campaign in the game.
 */
void RestartCampaignAny()
{
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(LoadGameConfigFile("left4dhooks.l4d2"), SDKConf_Signature, "CTerrorGameRules_ResetRoundNumber");
	Handle func = EndPrepSDKCall();

	if (func == INVALID_HANDLE)
		ThrowError("Failed to end prep sdk call");

	SDKCall(func);
	CloseHandle(func);
	CreateTimer(2.0, RestartCampaignAny1);
}

public Action RestartCampaignAny1(Handle timer)
{
	char sCurrentMap[128];
	GetCurrentMap(sCurrentMap, sizeof(sCurrentMap));

	Call_StartForward(CreateGlobalForward("OnReadyRoundRestarted", ET_Event));
	Call_Finish();

	L4D_RestartScenarioFromVote(sCurrentMap);
	CreateTimer(2.0, RestartCampaignAny2);

	return Plugin_Stop;
}

public Action RestartCampaignAny2(Handle timer)
{
	char sCurrentMap[128];
	GetCurrentMap(sCurrentMap, sizeof(sCurrentMap));

	Call_StartForward(CreateGlobalForward("OnReadyRoundRestarted", ET_Event));
	Call_Finish();

	L4D_RestartScenarioFromVote(sCurrentMap);
	g_cvarScavRestart.SetBool(false);

	return Plugin_Stop;
}