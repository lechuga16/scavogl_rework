#include <sourcemod>
#include <colors>

public Plugin:myinfo =
{
    name = "Block Trolls",
    description = "Prevents calling votes while others are loading",
    author = "ProdigySim, CanadaRox, darkid",
    version = "2.0.1.1",
    url = "https://github.com/jacob404/Pro-Mod-4.0/releases/latest"
};
new bool:g_bBlockCallvote;
new loadedPlayers = 0;

static ConVar g_hCvar_VoteTime;
static float  g_fCvar_VoteTime;
static bool g_bConfigLoaded;

enum L4D2Team
{
    L4D2Team_None = 0,
    L4D2Team_Spectator,
    L4D2Team_Survivor,
    L4D2Team_Infected
}

public OnPluginStart()
{
    g_hCvar_VoteTime = CreateConVar("sm_votetime", "60.0", "waiting time to start voting");

    g_hCvar_VoteTime.AddChangeHook(Event_ConVarChanged);

    //AutoExecConfig(true, "blocktrolls");

    AddCommandListener(Vote_Listener, "callvote");
    AddCommandListener(Vote_Listener, "vote");
    HookEvent("player_team", OnPlayerJoin);
}

public OnMapStart()
{
    g_bBlockCallvote = true;
    loadedPlayers = 0;
}

public void OnConfigsExecuted()
{
    GetCvars();

    g_bConfigLoaded = true;

    CreateTimer(g_fCvar_VoteTime, EnableCallvoteTimer);
}

public void Event_ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    GetCvars();
}

public void GetCvars()
{
    g_fCvar_VoteTime = g_hCvar_VoteTime.FloatValue;
}

public OnPlayerJoin(Handle:event, String:name[], bool:dontBroadcast)
{
    if (GetEventInt(event, "oldteam") == 0) {
        loadedPlayers++;
        if (loadedPlayers == 6) g_bBlockCallvote = false;
    }
}

public Action:Vote_Listener(client, const String:command[], argc)
{
    if (!g_bConfigLoaded)
        return Plugin_Handled;

    if (g_bBlockCallvote)
    {
		CPrintToChat(client, "{blue}[{default}SM{blue}] {default}Voting is not enabled until{olive} %i{default}s into the round",GetConVarInt(g_hCvar_VoteTime));
		return Plugin_Handled;
    }
    new L4D2Team:team = L4D2Team:GetClientTeam(client);
    if (client && IsClientInGame(client) &&
            (team == L4D2Team_Survivor || team == L4D2Team_Infected))
    {
        return Plugin_Continue;
    }
    return Plugin_Handled;
}

public Action:EnableCallvoteTimer(Handle:timer)
{
    g_bBlockCallvote = false;
    return Plugin_Stop;
}