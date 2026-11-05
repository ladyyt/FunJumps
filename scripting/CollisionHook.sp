#pragma semicolon 1

#include <sdktools>
#include <dhooks>
#include <collisionhook>

#pragma newdecls required

public Plugin myinfo =
{
	name = "CollisionHook",
	author = "xstage",
	version = "1.0.0",
	url = "https://steamcommunity.com/id/XST4G3/"
};

#define Assert(%0,%1); if (%0) { \
	SetFailState(%1); \
	return; \
}

Handle g_hGetBaseEntity;
GlobalForward g_hGlobalForward_OnShouldCollide, g_hGlobalForward_OnPassFilter;

public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] sError, int iErrorSize)
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		strcopy(sError, iErrorSize, "This plugin works only on CS:GO!");
		
		return APLRes_SilentFailure;
	}

	g_hGlobalForward_OnShouldCollide = new GlobalForward("CH_ShouldCollide", ET_Hook /* Action */, Param_Cell /* ent1 */, Param_Cell /* ent2 */, Param_CellByRef /* &result */);
	g_hGlobalForward_OnPassFilter =	new GlobalForward("CH_PassFilter", ET_Hook /* Action */, Param_Cell /* ent1 */, Param_Cell /* ent2 */, Param_CellByRef /* &result */);
	
	RegPluginLibrary("collisionhook");
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	GameData hGameData = LoadGameConfigFile("CollisionHook.games");
	
	Assert(!hGameData, "Failed to load CollisionHook gamedata.");

	DynamicDetour hCTraceFilterSimple_ShouldHitEntity = DynamicDetour.FromConf(hGameData, "CTraceFilterSimple::ShouldHitEntity");
	
	Assert(!hCTraceFilterSimple_ShouldHitEntity, "Failed to setup detour for CTraceFilterSimple::ShouldHitEntity.");
	Assert(!hCTraceFilterSimple_ShouldHitEntity.Enable(Hook_Pre, Detour_ShouldHitEntity), \
	"Failed to detour CTraceFilterSimple::ShouldHitEntity.");
	
	DynamicDetour hCCollisionEvent_ShouldCollide = DynamicDetour.FromConf(hGameData, "CCollisionEvent::ShouldCollide");
	
	Assert(!hCCollisionEvent_ShouldCollide, "Failed to setup detour for CCollisionEvent::ShouldCollide.");
	Assert(!hCCollisionEvent_ShouldCollide.Enable(Hook_Pre, Detour_ShouldCollide), \
	"Failed to detour CCollisionEvent::ShouldCollide.");
	
	StartPrepSDKCall(SDKCall_Raw);
	
	PrepSDKCall_SetVirtual(hGameData.GetOffset("CBaseEntity::GetBaseEntity"));
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_ByRef);
	
	g_hGetBaseEntity = EndPrepSDKCall();
}

static MRESReturn Detour_ShouldCollide(DHookReturn hReturn, DHookParam hParams)
{
	if (hParams == null)
		return MRES_Ignored;
	int iParamCount = DHookGetParam(hParams, 0);
	if (iParamCount < 2)
		return MRES_Ignored; 
	int iEnt1 = DHookGetParam(hParams, iParamCount - 1);
	int iEnt2 = DHookGetParam(hParams, iParamCount);
	
	if (iEnt1 != 0 && iEnt2 != 0)
	{
		bool bValue;
		Action iResult = Plugin_Continue;
		
		Call_StartForward(g_hGlobalForward_OnShouldCollide);
		Call_PushCell(iEnt1);
		Call_PushCell(iEnt2);
		Call_PushCellRef(bValue);
		Call_Finish(iResult);
		
		if (iResult != Plugin_Continue)
		{
			hReturn.Value = bValue;
			
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn Detour_ShouldHitEntity(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	if (hParams == null)
	{
		return MRES_Ignored;
	}
	int iEntity1 = DHookGetParam(hParams, 1);
	int iEntity2 = LoadFromAddress(view_as<Address>(pThis + 4), NumberType_Int32);
	
	if (iEntity1 != 0 && iEntity2 != 0 && iEntity2 != iEntity1)
	{
		int iTarget = SDKCall(g_hGetBaseEntity, iEntity1);
		int iClient = SDKCall(g_hGetBaseEntity, iEntity2);
		
		if (IsValidClient(iClient) && iTarget != 1)
		{
			bool bValue;
			Action iResult = Plugin_Continue;
		
			Call_StartForward(g_hGlobalForward_OnPassFilter);
			Call_PushCell(iClient);
			Call_PushCell(iTarget);
			Call_PushCellRef(bValue);
			Call_Finish(iResult);
			
			if (iResult != Plugin_Continue)
			{
				hReturn.Value = bValue;
				
				return MRES_Supercede;
			}
		}
	}
	
	return MRES_Ignored;
}