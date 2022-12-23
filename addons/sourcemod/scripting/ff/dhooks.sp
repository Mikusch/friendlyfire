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

enum ThinkFunction
{
	ThinkFunction_None,
	ThinkFunction_DispenseThink,
	ThinkFunction_SentryThink,
	ThinkFunction_SapperThink,
}

static DynamicHook g_DHookCanCollideWithTeammates;
static DynamicHook g_DHookGetCustomDamageType;
static DynamicHook g_DHookBaseGrenadeExplode;
static DynamicHook g_DHookBaseRocketExplode;
static DynamicHook g_DHookEventKilled;
static DynamicHook g_DHookSmack;
static DynamicHook g_DHookSecondaryAttack;
static DynamicHook g_DHookVPhysicsUpdate;

static ThinkFunction g_ThinkFunction;

void DHooks_Initialize(GameData gamedata)
{
	CreateDynamicDetour(gamedata, "CBaseEntity::InSameTeam", DHook_InSameTeam_Pre, _);
	CreateDynamicDetour(gamedata, "CBaseEntity::PhysicsDispatchThink", DHookCallback_PhysicsDispatchThink_Pre, DHookCallback_PhysicsDispatchThink_Post);
	
	g_DHookCanCollideWithTeammates = CreateDynamicHook(gamedata, "CBaseProjectile::CanCollideWithTeammates");
	g_DHookGetCustomDamageType = CreateDynamicHook(gamedata, "CTFSniperRifle::GetCustomDamageType");
	g_DHookBaseGrenadeExplode = CreateDynamicHook(gamedata, "CBaseGrenade::Explode");
	g_DHookBaseRocketExplode = CreateDynamicHook(gamedata, "CTFBaseRocket::Explode");
	g_DHookEventKilled = CreateDynamicHook(gamedata, "CBasePlayer::Event_Killed");
	g_DHookSmack = CreateDynamicHook(gamedata, "CTFWeaponBaseMelee::Smack");
	g_DHookSecondaryAttack = CreateDynamicHook(gamedata, "CTFWeaponBase::SecondaryAttack");
	g_DHookVPhysicsUpdate = CreateDynamicHook(gamedata, "CBaseEntity::VPhysicsUpdate");
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
		// Fixes jars not applying effects to teammates when hitting the world
		if (strncmp(classname, "tf_projectile_jar", 17) == 0)
		{
			g_DHookBaseGrenadeExplode.HookEntity(Hook_Pre, entity, DHookCallback_BaseGrenadeExplode_Pre);
			g_DHookBaseGrenadeExplode.HookEntity(Hook_Post, entity, DHookCallback_BaseGrenadeExplode_Post);
		}
		
		// Fixes Scorch Shot knockback on teammates
		if (StrEqual(classname, "tf_projectile_flare"))
		{
			g_DHookBaseRocketExplode.HookEntity(Hook_Pre, entity, DHookCallback_BaseRocketExplode_Pre);
			g_DHookBaseRocketExplode.HookEntity(Hook_Post, entity, DHookCallback_BaseRocketExplode_Post);
		}
		
		// Fixes grenades rarely bouncing off friendly objects
		if (IsProjectileCTFWeaponBaseGrenade(entity))
		{
			g_DHookVPhysicsUpdate.HookEntity(Hook_Pre, entity, DHookCallback_VPhysicsUpdate_Pre);
			g_DHookVPhysicsUpdate.HookEntity(Hook_Post, entity, DHookCallback_VPhysicsUpdate_Post);
		}
		
		// Fixes projectiles sometimes not colliding with teammates
		g_DHookCanCollideWithTeammates.HookEntity(Hook_Post, entity, DHookCallback_CanCollideWithTeammates_Post);
	}
	
	// Fixes Sniper Rifles dealing no damage to teammates
	if (strncmp(classname, "tf_weapon_sniperrifle", 21) == 0)
	{
		g_DHookGetCustomDamageType.HookEntity(Hook_Post, entity, DHookCallback_GetCustomDamageType_Post);
	}
	
	// Fixes pipebomb launchers not being able to knock around friendly pipebombs
	if (TF2Util_IsEntityWeapon(entity) && TF2Util_GetWeaponID(entity) == TF_WEAPON_PIPEBOMBLAUNCHER)
	{
		g_DHookSecondaryAttack.HookEntity(Hook_Pre, entity, DHookCallback_SecondaryAttack_Pre);
		g_DHookSecondaryAttack.HookEntity(Hook_Post, entity, DHookCallback_SecondaryAttack_Post);
	}
	
	// Fixes wrenches not being able to upgrade friendly objects and a few other melee weapons
	if (IsWeaponBaseMelee(entity))
	{
		g_DHookSmack.HookEntity(Hook_Pre, entity, DHookCallback_Smack_Pre);
		g_DHookSmack.HookEntity(Hook_Post, entity, DHookCallback_Smack_Post);
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

MRESReturn DHookCallback_BaseGrenadeExplode_Pre(int entity, DHookParam params)
{
	int thrower = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (thrower != -1)
	{
		Entity(thrower).ChangeToSpectator();
		Entity(entity).ChangeToSpectator();
	}
	
	return MRES_Ignored;
}

MRESReturn DHookCallback_BaseGrenadeExplode_Post(int entity, DHookParam params)
{
	int thrower = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (thrower != -1)
	{
		Entity(thrower).ResetTeam();
		Entity(entity).ResetTeam();
	}
	
	return MRES_Ignored;
}

MRESReturn DHookCallback_BaseRocketExplode_Pre(int entity, DHookParam params)
{
	int other = params.Get(2);
	
	Entity(other).ChangeToSpectator();
	
	return MRES_Ignored;
}

MRESReturn DHookCallback_BaseRocketExplode_Post(int entity, DHookParam params)
{
	int other = params.Get(2);
	
	Entity(other).ResetTeam();
	
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
	int penetrateType = SDKCall_GetPenetrateType(entity);
	if (penetrateType == TF_DMG_CUSTOM_NONE)
	{
		ret.Value = TF_DMG_CUSTOM_NONE;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

MRESReturn DHookCallback_Smack_Pre(int entity)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (owner != -1)
	{
		Entity(owner).ChangeToSpectator();
		
		if (TF2Util_GetWeaponID(entity) == TF_WEAPON_WRENCH)
		{
			// Move all our buildings to spectator to allow them to be repaired by us
			int obj = -1;
			while ((obj = FindEntityByClassname(obj, "obj_*")) != -1)
			{
				if (!TF2_IsObjectFriendly(obj, owner))
					continue;
				
				Entity(obj).ChangeToSpectator();
			}
		}
	}
	
	return MRES_Ignored;
}

MRESReturn DHookCallback_Smack_Post(int entity)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (owner != -1)
	{
		Entity(owner).ResetTeam();
		
		if (TF2Util_GetWeaponID(entity) == TF_WEAPON_WRENCH)
		{
			int obj = -1;
			while ((obj = FindEntityByClassname(obj, "obj_*")) != -1)
			{
				if (!TF2_IsObjectFriendly(obj, owner))
					continue;
				
				Entity(obj).ResetTeam();
			}
		}
	}
	
	return MRES_Ignored;
}

MRESReturn DHook_InSameTeam_Pre(int entity, DHookReturn ret, DHookParam param)
{
	char classname[64];
	if (!GetEntityClassname(entity, classname, sizeof(classname)))
		return MRES_Ignored;
	
	// Respawn rooms should still work normally, for local testing
	if (StrEqual(classname, "func_respawnroom"))
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
	if (!GetEntityClassname(entity, classname, sizeof(classname)))
		return MRES_Ignored;
	
	if (StrEqual(classname, "obj_sentrygun"))
	{
		// CObjectSentrygun::SentryThink
		if (SDKCall_GetNextThink(entity, "SentryThink") != TICK_NEVER_THINK)
			return MRES_Ignored;
		
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
				
				// Sentry Guns don't shoot spies disguised as the same team, spoof the disguise team
				if (!friendly)
				{
					Entity(client).m_preHookDisguiseTeam = view_as<TFTeam>(GetEntProp(client, Prop_Send, "m_nDisguiseTeam"));
					SetEntProp(client, Prop_Send, "m_nDisguiseTeam", TFTeam_Spectator);
				}
			}
		}
		
		// Buildings work in a similar way.
		// NOTE: Previously, we would use CBaseObject::ChangeTeam, but we switched to AddObject/RemoveObject calls,
		// due to ChangeTeam recreating the build points, causing issues with sapper placement.
		int obj = -1;
		while ((obj = FindEntityByClassname(obj, "obj_*")) != -1)
		{
			if (!GetEntProp(obj, Prop_Send, "m_bPlacing"))
			{
				TFTeam team = TF2_GetTeam(obj);
				Entity(obj).m_preHookTeam = team;
				bool friendly = TF2_IsObjectFriendly(entity, obj);
				
				if (friendly && team == enemyTeam)
				{
					SDKCall_RemoveObject(pEnemyTeam, obj);
				}
				else if (!friendly && team != enemyTeam)
				{
					SDKCall_AddObject(pEnemyTeam, obj);
				}
			}
		}
	}
	else if (StrEqual(classname, "obj_dispenser") || StrEqual(classname, "pd_dispenser"))
	{
		// CObjectDispenser::DispenseThink
		if (SDKCall_GetNextThink(entity, "DispenseThink") != TICK_NEVER_THINK)
			return MRES_Ignored;
		
		if (!GetEntProp(entity, Prop_Send, "m_bPlacing") && !GetEntProp(entity, Prop_Send, "m_bBuilding"))
		{
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
	else if (StrEqual(classname, "obj_attachment_sapper"))
	{
		// CBaseObject::BaseObjectThink
		if (SDKCall_GetNextThink(entity, "BaseObjectThink") != TICK_NEVER_THINK)
			return MRES_Ignored;
		
		g_ThinkFunction = ThinkFunction_SapperThink;
		
		// Always set team to spectator so we can place sappers on buildings of both teams
		SDKCall_ChangeTeam(entity, TFTeam_Spectator);
	}
	
	return MRES_Ignored;
}

MRESReturn DHookCallback_PhysicsDispatchThink_Post(int entity)
{
	switch (g_ThinkFunction)
	{
		case ThinkFunction_SentryThink:
		{
			TFTeam myTeam = TF2_GetTeam(entity);
			TFTeam enemyTeam = GetEnemyTeam(myTeam);
			Address pEnemyTeam = SDKCall_GetGlobalTeam(enemyTeam);
			
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					TFTeam team = Entity(client).m_preHookTeam;
					Entity(client).m_preHookTeam = TFTeam_Unassigned;
					bool friendly = TF2_IsObjectFriendly(entity, client);
					
					if (friendly && team == enemyTeam)
					{
						SDKCall_AddPlayer(pEnemyTeam, client);
					}
					else if (!friendly && team != enemyTeam)
					{
						SDKCall_RemovePlayer(pEnemyTeam, client);
					}
					
					if (!friendly)
					{
						SetEntProp(client, Prop_Send, "m_nDisguiseTeam", Entity(client).m_preHookDisguiseTeam);
						Entity(client).m_preHookDisguiseTeam = TFTeam_Unassigned;
					}
				}
			}
			
			int obj = -1;
			while ((obj = FindEntityByClassname(obj, "obj_*")) != -1)
			{
				if (!GetEntProp(obj, Prop_Send, "m_bPlacing"))
				{
					TFTeam team = Entity(obj).m_preHookTeam;
					bool friendly = TF2_IsObjectFriendly(entity, obj);
					
					if (friendly && team == enemyTeam)
					{
						SDKCall_AddObject(pEnemyTeam, obj);
					}
					else if (!friendly && team != enemyTeam)
					{
						SDKCall_RemoveObject(pEnemyTeam, obj);
					}
					
					Entity(obj).m_preHookTeam = TFTeam_Unassigned;
				}
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

MRESReturn DHookCallback_SecondaryAttack_Pre(int weapon)
{
	// Switch the weapon
	Entity(weapon).ChangeToSpectator();
	
	// Switch the weapon's owner
	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	if (owner != -1)
	{
		Entity(owner).ChangeToSpectator();
	}
	
	// Switch every pipebomb created by this weapon
	int pipe = -1;
	while ((pipe = FindEntityByClassname(pipe, "tf_projectile_pipe_remote")) != -1)
	{
		if (GetEntPropEnt(pipe, Prop_Send, "m_hLauncher") == weapon)
		{
			Entity(pipe).ChangeToSpectator();
		}
	}
	
	return MRES_Ignored;
}

MRESReturn DHookCallback_SecondaryAttack_Post(int weapon)
{
	Entity(weapon).ResetTeam();
	
	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	if (owner != -1)
	{
		Entity(owner).ResetTeam();
	}
	
	int pipe = -1;
	while ((pipe = FindEntityByClassname(pipe, "tf_projectile_pipe_remote")) != -1)
	{
		if (GetEntPropEnt(pipe, Prop_Send, "m_hLauncher") == weapon)
		{
			Entity(pipe).ResetTeam();
		}
	}
	
	return MRES_Ignored;
}

MRESReturn DHookCallback_VPhysicsUpdate_Pre(int entity, DHookParam params)
{
	int thrower = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	TFTeam enemyTeam = GetEnemyTeam(TF2_GetTeam(entity));
	
	// Not needed because of our CanCollideWithTeammates hook, but can't hurt
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		Entity(client).SetTeam(enemyTeam);
	}
	
	// Fix projectiles rarely bouncing off buildings
	int obj = -1;
	while ((obj = FindEntityByClassname(obj, "obj_*")) != -1)
	{
		if (!TF2_IsObjectFriendly(obj, thrower))
			continue;
		
		Entity(obj).SetTeam(enemyTeam);
	}
	
	return MRES_Ignored;
}

MRESReturn DHookCallback_VPhysicsUpdate_Post(int entity, DHookParam params)
{
	int thrower = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		Entity(client).ResetTeam();
	}
	
	int obj = -1;
	while ((obj = FindEntityByClassname(obj, "obj_*")) != -1)
	{
		if (!TF2_IsObjectFriendly(obj, thrower))
			continue;
		
		Entity(obj).ResetTeam();
	}
	
	return MRES_Ignored;
}
