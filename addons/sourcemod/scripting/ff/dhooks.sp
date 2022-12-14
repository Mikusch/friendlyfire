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

enum ThinkFunction
{
	ThinkFunction_None,
	ThinkFunction_DispenseThink,
	ThinkFunction_SentryThink,
}

static DynamicHook g_DHookCanCollideWithTeammates;
static DynamicHook g_DHookGetCustomDamageType;
static DynamicHook g_DHookExplode;
static DynamicHook g_DHookEventKilled;

static ThinkFunction g_ThinkFunction;

void DHooks_Initialize(GameData gamedata)
{
	CreateDynamicDetour(gamedata, "CBaseEntity::InSameTeam", DHook_InSameTeam_Pre, _);
	CreateDynamicDetour(gamedata, "CBaseEntity::PhysicsDispatchThink", DHookCallback_PhysicsDispatchThink_Pre, DHookCallback_PhysicsDispatchThink_Post);
	
	g_DHookCanCollideWithTeammates = CreateDynamicHook(gamedata, "CBaseProjectile::CanCollideWithTeammates");
	g_DHookGetCustomDamageType = CreateDynamicHook(gamedata, "CTFSniperRifle::GetCustomDamageType");
	g_DHookExplode = CreateDynamicHook(gamedata, "CBaseGrenade::Explode");
	g_DHookEventKilled = CreateDynamicHook(gamedata, "CBasePlayer::Event_Killed");
}

void DHooks_OnClientPutInServer(int client)
{
	g_DHookEventKilled.HookEntity(Hook_Pre, client, DHookCallback_EventKilled_Pre);
	g_DHookEventKilled.HookEntity(Hook_Post, client, DHookCallback_EventKilled_Post);
}

void DHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (strncmp(classname, "tf_projectile_", 14) == 0)
	{
		if (strncmp(classname, "tf_projectile_jar", 17) == 0)
		{
			g_DHookExplode.HookEntity(Hook_Pre, entity, DHookCallback_Explode_Pre);
			g_DHookExplode.HookEntity(Hook_Post, entity, DHookCallback_Explode_Post);
		}
		
		g_DHookCanCollideWithTeammates.HookEntity(Hook_Post, entity, DHookCallback_CanCollideWithTeammates_Post);
	}
	else if (strncmp(classname, "tf_weapon_sniperrifle", 21) == 0)
	{
		g_DHookGetCustomDamageType.HookEntity(Hook_Post, entity, DHookCallback_GetCustomDamageType_Post);
	}
}

static void CreateDynamicDetour(GameData gamedata, const char[] name, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	DynamicDetour detour = DynamicDetour.FromConf(gamedata, name);
	if (detour)
	{
		if (callbackPre != INVALID_FUNCTION)
			detour.Enable(Hook_Pre, callbackPre);
		
		if (callbackPost != INVALID_FUNCTION)
			detour.Enable(Hook_Post, callbackPost);
	}
	else
	{
		LogError("Failed to create detour: %s", name);
	}
}

static DynamicHook CreateDynamicHook(GameData gamedata, const char[] name)
{
	DynamicHook hook = DynamicHook.FromConf(gamedata, name);
	if (!hook)
		LogError("Failed to create hook setup handle for %s", name);
	
	return hook;
}

MRESReturn DHookCallback_EventKilled_Pre(int player, DHookParam params)
{
	// Switch back to the original team to force proper skin for ragdolls and other on-death effects
	Entity(player).ChangeToOriginalTeam();
	
	return MRES_Ignored;
}

MRESReturn DHookCallback_EventKilled_Post(int player, DHookParam params)
{
	Entity(player).ResetTeam();
	
	return MRES_Ignored;
}

MRESReturn DHookCallback_Explode_Pre(int entity, DHookParam params)
{
	int thrower = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (thrower != -1)
	{
		Entity(thrower).ChangeToSpectator();
		Entity(entity).ChangeToSpectator();
	}
	
	return MRES_Ignored;
}

MRESReturn DHookCallback_Explode_Post(int entity, DHookParam params)
{
	int thrower = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (thrower != -1)
	{
		Entity(thrower).ResetTeam();
		Entity(entity).ResetTeam();
	}
	
	return MRES_Ignored;
}

MRESReturn DHookCallback_CanCollideWithTeammates_Post(int entity, DHookReturn ret)
{
	// Always make projectiles collide with teammates
	ret.Value = true;
	
	return MRES_Supercede;
}

MRESReturn DHookCallback_GetCustomDamageType_Post(int entity, DHookReturn ret)
{
	// Allows Sniper Rifles to hit teammates, without breaking Machina penetration
	// https://github.com/Mentrillum/Slender-Fortress-Modified-Versions/blob/7c162f2a82eb1d1058c56fb23faf1be942b965d0/addons/sourcemod/scripting/sf2/pvp.sp#L982-L995
	int penetrateType = SDKCall_GetPenetrateType(entity);
	if (penetrateType == TF_DMG_CUSTOM_NONE)
	{
		ret.Value = TF_DMG_CUSTOM_NONE;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

MRESReturn DHook_InSameTeam_Pre(int entity, DHookReturn ret, DHookParam param)
{
	// Respawn rooms should still work normally, for local testing
	char classname[64];
	if (!GetEntityClassname(entity, classname, sizeof(classname)) || StrEqual(classname, "func_respawnroom"))
		return MRES_Ignored;
	
	if (param.IsNull(1))
	{
		ret.Value = false;
		return MRES_Supercede;
	}
	
	int other = param.Get(1);
	
	// Unless the top-most parent is us, assume every entity is not on the same team
	entity = FindParentOwnerEntity(entity);
	other = FindParentOwnerEntity(other);
	
	ret.Value = (entity == other);
	return MRES_Supercede;
}

MRESReturn DHookCallback_PhysicsDispatchThink_Pre(int entity)
{
	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));
	
	if (StrEqual(classname, "obj_sentrygun"))
	{
		// CObjectSentrygun::SentryThink
		g_ThinkFunction = ThinkFunction_SentryThink;
		
		TFTeam myTeam = TF2_GetTeam(entity);
		TFTeam enemyTeam = GetEnemyTeam(myTeam);
		Address pEnemyTeam = SDKCall_GetGlobalTeam(enemyTeam);
		
		// CObjectSentrygun::FindTarget uses CTFTeamManager to collect valid players.
		// Add all enemy players to the desired team.
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client))
			{
				TFTeam team = TF2_GetClientTeam(client);
				Entity(client).m_preHookTeam = team;
				bool friendly = TF2_IsObjectFriendly(entity, client);
				
				if (friendly && team == enemyTeam)
				{
					SDKCall_RemovePlayer(pEnemyTeam, client);
				}
				else if (!friendly && team != enemyTeam)
				{
					SDKCall_AddPlayer(pEnemyTeam, client);
				}
			}
		}
		
		// Buildings work in a similar manner, but we can change their team directly without side effects.
		int building = -1;
		while ((building = FindEntityByClassname(building, "obj_*")) != -1)
		{
			if (!GetEntProp(building, Prop_Send, "m_bPlacing"))
			{
				Entity(building).m_preHookTeam = TF2_GetTeam(building);
				
				if (TF2_IsObjectFriendly(entity, building))
				{
					SDKCall_ChangeTeam(building, myTeam);
				}
				else
				{
					SDKCall_ChangeTeam(building, enemyTeam);
				}
			}
		}
	}
	else if (StrEqual(classname, "obj_dispenser") || StrEqual(classname, "pd_dispenser"))
	{
		if (!GetEntProp(entity, Prop_Send, "m_bPlacing") && !GetEntProp(entity, Prop_Send, "m_bBuilding") && SDKCall_GetNextThink(entity, "DispenseThink") == TICK_NEVER_THINK)
		{
			// CObjectDispenser::DispenseThink
			g_ThinkFunction = ThinkFunction_DispenseThink;
			
			// Disallow players able to be healed from dispenser
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					if (!TF2_IsObjectFriendly(entity, client))
					{
						Entity(client).ChangeToSpectator();
					}
				}
			}
		}
	}
	
	return MRES_Ignored;
}

MRESReturn DHookCallback_PhysicsDispatchThink_Post(int entity)
{
	switch (g_ThinkFunction)
	{
		case ThinkFunction_SentryThink:
		{
			TFTeam enemyTeam = GetEnemyTeam(TF2_GetTeam(entity));
			Address pEnemyTeam = SDKCall_GetGlobalTeam(enemyTeam);
			
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					TFTeam team = Entity(client).m_preHookTeam;
					bool friendly = TF2_IsObjectFriendly(entity, client);
					
					if (friendly && team == enemyTeam)
					{
						SDKCall_AddPlayer(pEnemyTeam, client);
					}
					else if (!friendly && team != enemyTeam)
					{
						SDKCall_RemovePlayer(pEnemyTeam, client);
					}
					
					Entity(client).m_preHookTeam = TFTeam_Unassigned;
				}
			}
			
			int building = -1;
			while ((building = FindEntityByClassname(building, "obj_*")) != -1)
			{
				if (!GetEntProp(building, Prop_Send, "m_bPlacing"))
				{
					SDKCall_ChangeTeam(building, Entity(building).m_preHookTeam);
				}
				
				Entity(building).m_preHookTeam = TFTeam_Unassigned;
			}
		}
		case ThinkFunction_DispenseThink:
		{
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					if (!TF2_IsObjectFriendly(entity, client))
					{
						Entity(client).ResetTeam();
					}
				}
			}
		}
	}
	
	g_ThinkFunction = ThinkFunction_None;
	
	return MRES_Ignored;
}
