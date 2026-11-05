#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <sdktools>
#include <collisionhook> 
#include <csgo_colors>

#define VOTE_NO 	"###no###"
#define VOTE_YES 	"###yes###"

Handle				g_hVoteCooldownTimer;
ConVar 				g_hCvar[4];
MoveType 			g_MTData[MAXPLAYERS + 1];
char 				g_szPrefix[64],
					g_szFJTime[64];
bool				g_bNoCollision[MAXPLAYERS + 1]
					, g_bGod[MAXPLAYERS + 1];
float 				g_fVoteCooldown
					, g_fVoteThreshold
					, g_fPosData[MAXPLAYERS + 1][3]
					, g_fAngData[MAXPLAYERS + 1][3]
					, g_fVelData[MAXPLAYERS + 1][3];
					


public Plugin myinfo = 
{
	name	= "FunJumps",
	author	= "tampon",
	version = "1.0",
	url = "fakecrime.bio/tampon"
};


public void OnPluginStart()
{
	RegConsoleCmd("sm_fj", MenuFJ_Cmd);
	RegConsoleCmd("sm_votefj", VoteMenuFJ_Cmd);
	RegAdminCmd("sm_setfj", ADMSetFJ_Cmd, ADMFLAG_GENERIC);
	
	g_hCvar[0] = CreateConVar("sm_fj_chat_prefix", "{PURPLE}FunJumps {DEFAULT}| ", "Plugin prefix in chat");
	g_hCvar[1] = CreateConVar("sm_fj_time", "99999999999999999999999", "How long will the FunJumps last (seconds)?");
	g_hCvar[2] = CreateConVar("sm_fj_vote_cooldown", "60", "Voting cooldown (seconds)");
	g_hCvar[3] = CreateConVar("sm_fj_vote_threshold", "0.60", "Vote threshold for triggering fun jumps (float)");
	
	AutoExecConfig(true, "funjumps");
	LoadTranslations("funjumps.phrases");
	LoadTranslations("common.phrases");
	LoadTranslations("basevotes.phrases");
}

public void OnConfigsExecuted()
{
	GetConVarString(g_hCvar[0], g_szPrefix, sizeof(g_szPrefix));
	GetConVarString(g_hCvar[1], g_szFJTime, sizeof(g_szFJTime));
	g_fVoteCooldown = GetConVarFloat(g_hCvar[2]);
	g_fVoteThreshold = GetConVarFloat(g_hCvar[3]);
}

public void OnClientPutInServer(int iClient)
{
	SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int iClient) 
{ 
	resetData(iClient); 
}

public void OnMapEnd()
{
	for (int i = 0; i < MAXPLAYERS + 1; i++) resetData(i);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (IsValidClient(victim) && g_bGod[victim])
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}


public Action CH_PassFilter(int iClient, int iTarget, bool &bResult)
{
	if (IsValidClient(iClient) && IsValidClient(iTarget))
	{
		if (g_bNoCollision[iClient] || g_bNoCollision[iTarget])
		{
			bResult = false;
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
} 

public void Event_PlayerSpawn(Event hEvent, const char[] sEvName, bool bDontBroadcast) 
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	
	if (IsValidClient(iClient))
	{		
		if (g_bNoCollision[iClient])
		{
			if (IsFJ())
			{
				SetEntProp(iClient, Prop_Send, "m_CollisionGroup", 11);
				SetEntityRenderMode(iClient, RENDER_TRANSCOLOR);
				SetEntityRenderColor(iClient, 93, 255, 43, 55);
			}
			else
			{
				SetEntProp(iClient, Prop_Send, "m_CollisionGroup", 5);
				SetEntityRenderMode(iClient, RENDER_TRANSCOLOR); 
				SetEntityRenderColor(iClient, 255, 255, 255, 255);
				g_bNoCollision[iClient] = false;
			}
		}
		
		if (g_bGod[iClient] && !IsFJ())
		{
			g_bGod[iClient] = false;
		}
	}
}

public Action MenuFJ_Cmd(int iClient, int iArgs)
{
    if (IsValidClient(iClient) && IsFJ())
        OpenFjMenu(iClient);
		
    return Plugin_Handled;
}

public Action VoteMenuFJ_Cmd(int iClient, int iArgs)
{
	if (!IsValidClient(iClient)) return Plugin_Continue;
	if (IsVoteInProgress()) return Plugin_Handled;
	if (g_hVoteCooldownTimer) 
	{
		CGOPrintToChat(iClient, "%t", "Vote_OnCooldown", g_szPrefix);
		return Plugin_Continue;
	}
	
	Menu menu = new Menu(Handler_VoteMenuFJ);
	menu.SetTitle("%T", IsFJ() ? "Menu_DisableFJ" : "Menu_EnableFJ", iClient);
	menu.AddItem(VOTE_YES, "Yes");
	menu.AddItem(VOTE_NO, "No");
	menu.ExitButton = false;
	menu.DisplayVoteToAll(20);
	
	g_hVoteCooldownTimer = CreateTimer(g_fVoteCooldown, TimerCooldownVote);
	
	return Plugin_Handled;
}

int Handler_VoteMenuFJ(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_VoteCancel && param1 == VoteCancel_NoVotes)
	{
		CGOPrintToChatAll("%s%t", g_szPrefix, "No Votes Cast");
	}   
	else if (action == MenuAction_VoteEnd)
	{
		char item[32];
		int votes, totalVotes;
		GetMenuVoteInfo(param2, votes, totalVotes);
		menu.GetItem(param1, item, sizeof(item));
		if (strcmp(item, VOTE_NO) == 0 && param1 == 1)
			votes = totalVotes - votes; 
		
		float percent = float(votes) / float(totalVotes);
		
		if (strcmp(item, VOTE_YES) == 0 && percent >= g_fVoteThreshold && param1 == 0)
		{
			CGOPrintToChatAll("%s%t", g_szPrefix, "Vote Successful", RoundToNearest(100.0*percent), totalVotes);
			ToggleFunJumps();
		}
		else
		{
			CGOPrintToChatAll("%s%t", g_szPrefix, "Vote Failed", RoundToNearest(100.0*g_fVoteThreshold), RoundToNearest(100.0*percent), totalVotes);
		}
	}
	return 0;
}


public Action ADMSetFJ_Cmd(int iClient, int iArgs)
{
	ToggleFunJumps();
	return Plugin_Handled;
}

Menu OpenFjMenu(int iClient)
{
	Menu menu = new Menu(FJMenu_Handler);
	menu.SetTitle("FJ menu");
	menu.AddItem("0", "Save point");
	menu.AddItem("1", "Tp");
	menu.AddItem("2", "Noclip");
	menu.AddItem("4", g_bGod[iClient] ? "God [+]" : "God [-]");
	menu.AddItem("5", g_bNoCollision[iClient] ? "Body [+]" : "Body [-]");
	menu.Display(iClient, 0);

	return menu;
}

int FJMenu_Handler(Menu menu, MenuAction action, int iClient, int iItem)
{
	if (!IsValidClient(iClient) || !IsFJ()) return 0;
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (iItem)
			{
				case 0:
				{
					GetClientAbsOrigin(iClient, g_fPosData[iClient]);
					GetClientEyeAngles(iClient, g_fAngData[iClient]);
					GetClientVelocity(iClient, g_fVelData[iClient]);
					g_MTData[iClient] = GetEntityMoveType(iClient);
					
					CGOPrintToChat(iClient, "%t", "FJ_PointSaved", g_szPrefix);
					OpenFjMenu(iClient);
				}
				case 1:
				{
					if (GetVectorDistance(g_fPosData[iClient], NULL_VECTOR, false) > 0.0 && GetVectorDistance(g_fAngData[iClient], NULL_VECTOR, false) > 0.0)
					{
						TeleportEntity(iClient, g_fPosData[iClient], g_fAngData[iClient], g_fVelData[iClient]);
						SetEntityMoveType(iClient, g_MTData[iClient]);
					}
					else
						CGOPrintToChat(iClient, "%t", "FJ_EmptyPoint", g_szPrefix);
						
					OpenFjMenu(iClient);
				}
				case 2:
				{
					MoveType movetype = GetEntityMoveType(iClient);
					if (movetype != MOVETYPE_NOCLIP)
						SetEntityMoveType(iClient, MOVETYPE_NOCLIP);
					else if (movetype == MOVETYPE_NOCLIP)
						SetEntityMoveType(iClient, MOVETYPE_WALK);
						
					OpenFjMenu(iClient);
				}
				case 3:
				{
					g_bGod[iClient] = !g_bGod[iClient];
					OpenFjMenu(iClient);
				}
				case 4:
				{
					if (!g_bNoCollision[iClient])
					{
						SetEntProp(iClient, Prop_Send, "m_CollisionGroup", 11);
						SetEntityRenderMode(iClient, RENDER_TRANSCOLOR);
						SetEntityRenderColor(iClient, 93, 255, 43, 55);
					}
					else
					{
						SetEntProp(iClient, Prop_Send, "m_CollisionGroup", 5); 
						SetEntityRenderMode(iClient, RENDER_TRANSCOLOR); 
						SetEntityRenderColor(iClient, 255, 255, 255, 255); 
					}	
					g_bNoCollision[iClient] = !g_bNoCollision[iClient];
					OpenFjMenu(iClient);
				}
			}
		}
			
		case MenuAction_End: delete menu;
	}

	return 0;
}

void ToggleFunJumps()
{
	if (!IsFJ())
	{
		ServerCommand("mp_warmuptime %s", g_szFJTime);
		ServerCommand("mp_warmup_start");
		CGOPrintToChatAll("%t", "FJ_Enabled", g_szPrefix);
	}
	else
	{
		ServerCommand("mp_warmuptime 0");
		ServerCommand("mp_warmup_end");
		CGOPrintToChatAll("%t", "FJ_Disabled", g_szPrefix);
	}
}

public Action TimerCooldownVote(Handle timer)
{
	KillTimer(g_hVoteCooldownTimer);
	g_hVoteCooldownTimer = null;
	return Plugin_Handled;
}

void GetClientVelocity(int iClient, float vel[3])
{
	vel[0] = GetEntPropFloat(iClient, Prop_Send, "m_vecVelocity[0]", 0);
	vel[1] = GetEntPropFloat(iClient, Prop_Send, "m_vecVelocity[1]", 0);
	vel[2] = GetEntPropFloat(iClient, Prop_Send, "m_vecVelocity[2]", 0);
}

void resetData(int iClient)
{
	g_fPosData[iClient] = NULL_VECTOR;
	g_fAngData[iClient] = NULL_VECTOR;
	g_fVelData[iClient] = NULL_VECTOR;
	g_MTData[iClient] = MOVETYPE_WALK;
	g_bGod[iClient] = false;
	g_bNoCollision[iClient] = false;
}

bool IsValidClient(int iClient)
{
	if(iClient >= 1 && iClient <= MaxClients 
	&& IsValidEntity(iClient) 
	&& IsClientConnected(iClient) 
	&& IsClientInGame(iClient) 
	&& IsClientAuthorized(iClient) 
	&& !IsClientInKickQueue(iClient)
	&& !IsFakeClient(iClient))
		return true; 
		
	return false;
}

bool IsFJ()
{
	return GameRules_GetProp("m_bWarmupPeriod") == 1;
}