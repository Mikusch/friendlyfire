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

#define TICK_NEVER_THINK	(-1.0)

static Handle g_SDKCallGetNextThink;
static Handle g_SDKCallGetPenetrateType;

void SDKCalls_Initialize(GameData gamedata)
{
	g_SDKCallGetNextThink = PrepSDKCall_GetNextThink(gamedata);
	g_SDKCallGetPenetrateType = PrepSDKCall_GetPenetrateType(gamedata);
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
