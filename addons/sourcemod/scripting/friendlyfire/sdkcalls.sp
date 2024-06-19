/**
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

static Handle g_sdkCall_CBaseEntity_GetNextThink;
static Handle g_sdkCall_CTFSniperRifle_GetPenetrateType;
static Handle g_sdkCall_GetGlobalTeam;
static Handle g_sdkCall_CTeam_AddPlayer;
static Handle g_sdkCall_CTeam_RemovePlayer;
static Handle g_sdkCall_CTeam_AddObject;
static Handle g_sdkCall_CTeam_RemoveObject;
static Handle g_sdkCall_CBaseEntity_ChangeTeam;

void SDKCalls_Init(GameData gamedata)
{
	g_sdkCall_CBaseEntity_GetNextThink = PrepSDKCall_CBaseEntity_GetNextThink(gamedata);
	g_sdkCall_CTFSniperRifle_GetPenetrateType = PrepSDKCall_CTFSniperRifle_GetPenetrateType(gamedata);
	g_sdkCall_GetGlobalTeam = PrepSDKCall_GetGlobalTeam(gamedata);
	g_sdkCall_CTeam_AddPlayer = PrepSDKCall_CTeam_AddPlayer(gamedata);
	g_sdkCall_CTeam_RemovePlayer = PrepSDKCall_CTeam_RemovePlayer(gamedata);
	g_sdkCall_CTeam_AddObject = PrepSDKCall_CTeam_AddObject(gamedata);
	g_sdkCall_CTeam_RemoveObject = PrepSDKCall_CTeam_RemoveObject(gamedata);
	g_sdkCall_CBaseEntity_ChangeTeam = PrepSDKCall_CBaseEntity_ChangeTeam(gamedata);
}

static Handle PrepSDKCall_CBaseEntity_GetNextThink(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CBaseEntity::GetNextThink");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		ThrowError("Failed to create SDKCall: CBaseEntity::GetNextThink");
	
	return call;
}

static Handle PrepSDKCall_CTFSniperRifle_GetPenetrateType(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTFSniperRifle::GetPenetrateType");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		ThrowError("Failed to create SDKCall: CTFSniperRifle::GetPenetrateType");
	
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
		ThrowError("Failed to create SDKCall: GetGlobalTeam");
	
	return call;
}

static Handle PrepSDKCall_CTeam_AddPlayer(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTeam::AddPlayer");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		ThrowError("Failed to create SDKCall: CTeam::AddPlayer");
	
	return call;
}

static Handle PrepSDKCall_CTeam_RemovePlayer(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTeam::RemovePlayer");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		ThrowError("Failed to create SDKCall: CTeam::RemovePlayer");
	
	return call;
}

static Handle PrepSDKCall_CTeam_AddObject(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFTeam::AddObject");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		ThrowError("Failed to create SDKCall: CTFTeam::AddObject");
	
	return call;
}

static Handle PrepSDKCall_CTeam_RemoveObject(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFTeam::RemoveObject");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		ThrowError("Failed to create SDKCall: CTFTeam::RemoveObject");
	
	return call;
}

static Handle PrepSDKCall_CBaseEntity_ChangeTeam(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseEntity::ChangeTeam");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		ThrowError("Failed to create SDKCall: CBaseEntity::ChangeTeam");
	
	return call;
}

float SDKCall_CBaseEntity_GetNextThink(int entity, const char[] context = "")
{
	if (g_sdkCall_CBaseEntity_GetNextThink)
		return SDKCall(g_sdkCall_CBaseEntity_GetNextThink, entity, context);
	
	return TICK_NEVER_THINK;
}

int SDKCall_CTFSniperRifle_GetPenetrateType(int weapon)
{
	if (g_sdkCall_CTFSniperRifle_GetPenetrateType)
		return SDKCall(g_sdkCall_CTFSniperRifle_GetPenetrateType, weapon);
	
	return TF_CUSTOM_NONE;
}

Address SDKCall_GetGlobalTeam(TFTeam team)
{
	if (g_sdkCall_GetGlobalTeam)
		return SDKCall(g_sdkCall_GetGlobalTeam, team);
	
	return Address_Null;
}

void SDKCall_CTeam_AddPlayer(Address team, int client)
{
	if (g_sdkCall_CTeam_AddPlayer)
		SDKCall(g_sdkCall_CTeam_AddPlayer, team, client);
}

void SDKCall_CTeam_RemovePlayer(Address team, int client)
{
	if (g_sdkCall_CTeam_RemovePlayer)
		SDKCall(g_sdkCall_CTeam_RemovePlayer, team, client);
}

void SDKCall_CTeam_AddObject(Address team, int obj)
{
	if (g_sdkCall_CTeam_AddObject)
		SDKCall(g_sdkCall_CTeam_AddObject, team, obj);
}

void SDKCall_CTeam_RemoveObject(Address team, int obj)
{
	if (g_sdkCall_CTeam_RemoveObject)
		SDKCall(g_sdkCall_CTeam_RemoveObject, team, obj);
}

void SDKCall_CBaseEntity_ChangeTeam(int entity, TFTeam team)
{
	if (g_sdkCall_CBaseEntity_ChangeTeam)
		SDKCall(g_sdkCall_CBaseEntity_ChangeTeam, entity, team);
}
