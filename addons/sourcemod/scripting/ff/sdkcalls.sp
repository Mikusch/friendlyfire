/*
 * Copyright (C) 2022  Mikusch
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#pragma newdecls required
#pragma semicolon 1

static Handle g_SDKCallGetNextThink;
static Handle g_SDKCallGetPenetrateType;
static Handle g_SDKCallGetGlobalTeam;
static Handle g_SDKCallAddPlayer;
static Handle g_SDKCallRemovePlayer;
static Handle g_SDKCallChangeTeam;

void SDKCalls_Initialize(GameData gamedata)
{
	g_SDKCallGetNextThink = PrepSDKCall_GetNextThink(gamedata);
	g_SDKCallGetPenetrateType = PrepSDKCall_GetPenetrateType(gamedata);
	g_SDKCallGetGlobalTeam = PrepSDKCall_GetGlobalTeam(gamedata);
	g_SDKCallAddPlayer = PrepSDKCall_AddPlayer(gamedata);
	g_SDKCallRemovePlayer = PrepSDKCall_RemovePlayer(gamedata);
	g_SDKCallChangeTeam = PrepSDKCall_ChangeTeam(gamedata);
}

static Handle PrepSDKCall_GetNextThink(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CBaseEntity::GetNextThink");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CBaseEntity::GetNextThink");
	
	return call;
}

static Handle PrepSDKCall_GetPenetrateType(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTFSniperRifle::GetPenetrateType");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CTFSniperRifle::GetPenetrateType");
	
	return call;
}

static Handle PrepSDKCall_GetGlobalTeam(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "GetGlobalTeam");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: GetGlobalTeam");
	
	return call;
}

static Handle PrepSDKCall_AddPlayer(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTeam::AddPlayer");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: CTeam::AddPlayer");
	
	return call;
}

static Handle PrepSDKCall_RemovePlayer(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTeam::RemovePlayer");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create SDKCall: CTeam::RemovePlayer");
	
	return call;
}

static Handle PrepSDKCall_ChangeTeam(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseEntity::ChangeTeam");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CBaseEntity::ChangeTeam");
	
	return call;
}

float SDKCall_GetNextThink(int entity, const char[] context = "")
{
	if (g_SDKCallGetNextThink)
		return SDKCall(g_SDKCallGetNextThink, entity, context);
	
	return TICK_NEVER_THINK;
}

int SDKCall_GetPenetrateType(int weapon)
{
	if (g_SDKCallGetPenetrateType)
		return SDKCall(g_SDKCallGetPenetrateType, weapon);
	
	return TF_DMG_CUSTOM_NONE;
}

Address SDKCall_GetGlobalTeam(TFTeam team)
{
	if (g_SDKCallGetGlobalTeam)
		return SDKCall(g_SDKCallGetGlobalTeam, team);
	
	return Address_Null;
}

void SDKCall_AddPlayer(Address team, int client)
{
	if (g_SDKCallAddPlayer)
		SDKCall(g_SDKCallAddPlayer, team, client);
}

void SDKCall_RemovePlayer(Address team, int client)
{
	if (g_SDKCallRemovePlayer)
		SDKCall(g_SDKCallRemovePlayer, team, client);
}

void SDKCall_ChangeTeam(int entity, TFTeam team)
{
	if (g_SDKCallChangeTeam)
		SDKCall(g_SDKCallChangeTeam, entity, team);
}
