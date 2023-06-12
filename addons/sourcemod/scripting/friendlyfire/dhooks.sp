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

enum struct DetourData
{
	DynamicDetour detour;
	DHookCallback callbackPre;
	DHookCallback callbackPost;
}

enum ThinkFunction
{
	ThinkFunction_None,
	ThinkFunction_DispenseThink,
	ThinkFunction_SentryThink,
	ThinkFunction_SapperThink,
}

static ArrayList g_dynamicDetours;
static ArrayList g_dynamicHookIds;

static DynamicHook g_dhook_CBaseProjectile_CanCollideWithTeammates;
static DynamicHook g_dhook_CTFSniperRifle_GetCustomDamageType;
static DynamicHook g_dhook_CBaseGrenade_Explode;
static DynamicHook g_dhook_CTFBaseRocket_Explode;
static DynamicHook g_dhook_CBasePlayer_Event_Killed;
static DynamicHook g_dhook_CTFWeaponBaseMelee_Smack;
static DynamicHook g_dhook_CTFWeaponBase_SecondaryAttack;
static DynamicHook g_dhook_CBaseEntity_VPhysicsUpdate;

static ThinkFunction g_thinkFunction = ThinkFunction_None;

void DHooks_Initialize(GameData gamedata)
{
	g_dynamicDetours = new ArrayList(sizeof(DetourData));
	g_dynamicHookIds = new ArrayList();
	
	DHooks_AddDynamicDetour(gamedata, "CBaseEntity::InSameTeam", DHookCallback_CBaseEntity_InSameTeam_Pre);
	DHooks_AddDynamicDetour(gamedata, "CBaseEntity::PhysicsDispatchThink", DHookCallback_CBaseEntity_PhysicsDispatchThink_Pre, DHookCallback_CBaseEntity_PhysicsDispatchThink_Post);
	
	g_dhook_CBaseProjectile_CanCollideWithTeammates = DHooks_AddDynamicHook(gamedata, "CBaseProjectile::CanCollideWithTeammates");
	g_dhook_CTFSniperRifle_GetCustomDamageType = DHooks_AddDynamicHook(gamedata, "CTFSniperRifle::GetCustomDamageType");
	g_dhook_CBaseGrenade_Explode = DHooks_AddDynamicHook(gamedata, "CBaseGrenade::Explode");
	g_dhook_CTFBaseRocket_Explode = DHooks_AddDynamicHook(gamedata, "CTFBaseRocket::Explode");
	g_dhook_CBasePlayer_Event_Killed = DHooks_AddDynamicHook(gamedata, "CBasePlayer::Event_Killed");
	g_dhook_CTFWeaponBaseMelee_Smack = DHooks_AddDynamicHook(gamedata, "CTFWeaponBaseMelee::Smack");
	g_dhook_CTFWeaponBase_SecondaryAttack = DHooks_AddDynamicHook(gamedata, "CTFWeaponBase::SecondaryAttack");
	g_dhook_CBaseEntity_VPhysicsUpdate = DHooks_AddDynamicHook(gamedata, "CBaseEntity::VPhysicsUpdate");
}

void DHooks_Toggle(bool enable)
{
	for (int i = 0; i < g_dynamicDetours.Length; i++)
	{
		DetourData data;
		if (g_dynamicDetours.GetArray(i, data))
		{
			if (data.callbackPre != INVALID_FUNCTION)
			{
				if (enable)
				{
					data.detour.Enable(Hook_Pre, data.callbackPre);
				}
				else
				{
					data.detour.Disable(Hook_Pre, data.callbackPre);
				}
			}
			
			if (data.callbackPost != INVALID_FUNCTION)
			{
				if (enable)
				{
					data.detour.Enable(Hook_Post, data.callbackPost);
				}
				else
				{
					data.detour.Disable(Hook_Post, data.callbackPost);
				}
			}
		}
	}
	
	if (!enable)
	{
		// Remove virtual hooks
		for (int i = g_dynamicHookIds.Length - 1; i >= 0; i--)
		{
			int hookid = g_dynamicHookIds.Get(i);
			DynamicHook.RemoveHook(hookid);
		}
	}
}

void DHooks_OnClientPutInServer(int client)
{
	DHooks_HookEntity(g_dhook_CBasePlayer_Event_Killed, Hook_Pre, client, DHookCallback_CTFPlayer_Event_Killed_Pre);
	DHooks_HookEntity(g_dhook_CBasePlayer_Event_Killed, Hook_Post, client, DHookCallback_CTFPlayer_Event_Killed_Post);
}

void DHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (!strncmp(classname, "tf_projectile_", 14))
	{
		// Fixes jars not applying effects to teammates when hitting the world
		if (!strncmp(classname, "tf_projectile_jar", 17))
		{
			DHooks_HookEntity(g_dhook_CBaseGrenade_Explode, Hook_Pre, entity, DHookCallback_CTFProjectile_Jar_Explode_Pre);
			DHooks_HookEntity(g_dhook_CBaseGrenade_Explode, Hook_Post, entity, DHookCallback_CTFProjectile_Jar_Explode_Post);
		}
		
		// Fixes Scorch Shot knockback on teammates
		if (StrEqual(classname, "tf_projectile_flare"))
		{
			DHooks_HookEntity(g_dhook_CTFBaseRocket_Explode, Hook_Pre, entity, DHookCallback_CTFProjectile_Flare_Explode_Pre);
			DHooks_HookEntity(g_dhook_CTFBaseRocket_Explode, Hook_Post, entity, DHookCallback_CTFProjectile_Flare_Explode_Post);
		}
		
		// Fixes grenades rarely bouncing off friendly objects
		if (IsProjectileCTFWeaponBaseGrenade(entity))
		{
			DHooks_HookEntity(g_dhook_CBaseEntity_VPhysicsUpdate, Hook_Pre, entity, DHookCallback_CTFWeaponBaseGrenade_VPhysicsUpdate_Pre);
			DHooks_HookEntity(g_dhook_CBaseEntity_VPhysicsUpdate, Hook_Post, entity, DHookCallback_CTFWeaponBaseGrenade_VPhysicsUpdate_Post);
		}
		
		// Fixes projectiles sometimes not colliding with teammates
		DHooks_HookEntity(g_dhook_CBaseProjectile_CanCollideWithTeammates, Hook_Post, entity, DHookCallback_CBaseProjectile_CanCollideWithTeammates_Post);
	}
	
	// Fixes Sniper Rifles dealing no damage to teammates
	if (!strncmp(classname, "tf_weapon_sniperrifle", 21))
	{
		DHooks_HookEntity(g_dhook_CTFSniperRifle_GetCustomDamageType, Hook_Post, entity, DHookCallback_CTFSniperRifle_GetCustomDamageType_Post);
	}
	
	// Fixes pipebomb launchers not being able to knock around friendly pipebombs
	if (TF2Util_IsEntityWeapon(entity) && TF2Util_GetWeaponID(entity) == TF_WEAPON_PIPEBOMBLAUNCHER)
	{
		DHooks_HookEntity(g_dhook_CTFWeaponBase_SecondaryAttack, Hook_Pre, entity, DHookCallback_CTFPipebombLauncher_SecondaryAttack_Pre);
		DHooks_HookEntity(g_dhook_CTFWeaponBase_SecondaryAttack, Hook_Post, entity, DHookCallback_CTFPipebombLauncher_SecondaryAttack_Post);
	}
	
	// Fixes wrenches not being able to upgrade friendly objects and a few other melee weapons
	if (IsWeaponBaseMelee(entity))
	{
		DHooks_HookEntity(g_dhook_CTFWeaponBaseMelee_Smack, Hook_Pre, entity, DHookCallback_CTFWeaponBaseMelee_Smack_Pre);
		DHooks_HookEntity(g_dhook_CTFWeaponBaseMelee_Smack, Hook_Post, entity, DHookCallback_CTFWeaponBaseMelee_Smack_Post);
	}
}

static void DHooks_AddDynamicDetour(GameData gamedata, const char[] name, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	DynamicDetour detour = DynamicDetour.FromConf(gamedata, name);
	if (detour)
	{
		DetourData data;
		data.detour = detour;
		data.callbackPre = callbackPre;
		data.callbackPost = callbackPost;
		
		g_dynamicDetours.PushArray(data);
	}
	else
	{
		LogError("Failed to create detour setup handle: %s", name);
	}
}

static DynamicHook DHooks_AddDynamicHook(GameData gamedata, const char[] name)
{
	DynamicHook hook = DynamicHook.FromConf(gamedata, name);
	if (!hook)
	{
		LogError("Failed to create hook setup handle: %s", name);
	}
	
	return hook;
}

static void DHooks_HookEntity(DynamicHook hook, HookMode mode, int entity, DHookCallback callback)
{
	if (hook)
	{
		int hookid = hook.HookEntity(mode, entity, callback, DHookRemovalCB_OnHookRemoved);
		if (hookid != INVALID_HOOK_ID)
		{
			g_dynamicHookIds.Push(hookid);
		}
	}
}

public void DHookRemovalCB_OnHookRemoved(int hookid)
{
	int index = g_dynamicHookIds.FindValue(hookid);
	if (index != -1)
	{
		g_dynamicHookIds.Erase(index);
	}
}

static MRESReturn DHookCallback_CTFPlayer_Event_Killed_Pre(int player, DHookParam params)
{
	if (!IsFriendlyFireEnabled())
		return MRES_Ignored;
	
	// Switch back to the original team to force proper skin for ragdolls and other on-death effects
	Entity(player).ChangeToOriginalTeam();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayer_Event_Killed_Post(int player, DHookParam params)
{
	if (!IsFriendlyFireEnabled())
		return MRES_Ignored;
	
	Entity(player).ResetTeam();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFProjectile_Jar_Explode_Pre(int entity, DHookParam params)
{
	if (!IsFriendlyFireEnabled())
		return MRES_Ignored;
	
	int thrower = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (thrower != -1)
	{
		Entity(thrower).ChangeToSpectator();
		Entity(entity).ChangeToSpectator();
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFProjectile_Jar_Explode_Post(int entity, DHookParam params)
{
	if (!IsFriendlyFireEnabled())
		return MRES_Ignored;
	
	int thrower = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (thrower != -1)
	{
		Entity(thrower).ResetTeam();
		Entity(entity).ResetTeam();
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFProjectile_Flare_Explode_Pre(int entity, DHookParam params)
{
	if (!IsFriendlyFireEnabled())
		return MRES_Ignored;
	
	int other = params.Get(2);
	
	Entity(other).ChangeToSpectator();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFProjectile_Flare_Explode_Post(int entity, DHookParam params)
{
	if (!IsFriendlyFireEnabled())
		return MRES_Ignored;
	
	int other = params.Get(2);
	
	Entity(other).ResetTeam();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CBaseProjectile_CanCollideWithTeammates_Post(int entity, DHookReturn ret)
{
	if (!IsFriendlyFireEnabled())
		return MRES_Ignored;
	
	// Always make projectiles collide with teammates
	ret.Value = true;
	
	return MRES_Supercede;
}

static MRESReturn DHookCallback_CTFSniperRifle_GetCustomDamageType_Post(int entity, DHookReturn ret)
{
	if (!IsFriendlyFireEnabled())
		return MRES_Ignored;
	
	// Allows Sniper Rifles to hit teammates, without breaking Machina penetration
	int penetrateType = SDKCall_CTFSniperRifle_GetPenetrateType(entity);
	if (penetrateType == TF_CUSTOM_NONE)
	{
		ret.Value = TF_CUSTOM_NONE;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFWeaponBaseMelee_Smack_Pre(int entity)
{
	if (!IsFriendlyFireEnabled())
		return MRES_Ignored;
	
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
				if (!IsObjectFriendly(obj, owner))
					continue;
				
				Entity(obj).ChangeToSpectator();
			}
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFWeaponBaseMelee_Smack_Post(int entity)
{
	if (!IsFriendlyFireEnabled())
		return MRES_Ignored;
	
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (owner != -1)
	{
		Entity(owner).ResetTeam();
		
		if (TF2Util_GetWeaponID(entity) == TF_WEAPON_WRENCH)
		{
			int obj = -1;
			while ((obj = FindEntityByClassname(obj, "obj_*")) != -1)
			{
				if (!IsObjectFriendly(obj, owner))
					continue;
				
				Entity(obj).ResetTeam();
			}
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CBaseEntity_InSameTeam_Pre(int entity, DHookReturn ret, DHookParam params)
{
	if (!IsFriendlyFireEnabled())
		return MRES_Ignored;
	
	char classname[64];
	if (!GetEntityClassname(entity, classname, sizeof(classname)))
		return MRES_Ignored;
	
	// Ignore some entities
	if (StrEqual(classname, "func_respawnroom") || StrEqual(classname, "entity_revive_marker"))
		return MRES_Ignored;
	
	if (params.IsNull(1))
	{
		ret.Value = false;
		return MRES_Supercede;
	}
	
	int other = params.Get(1);
	
	// Allow Rescue Ranger healing bolts to work on friendly buildings
	if (StrEqual(classname, "tf_projectile_arrow") &&
		GetEntProp(entity, Prop_Send, "m_iProjectileType") == TF_PROJECTILE_BUILDING_REPAIR_BOLT &&
		IsBaseObject(other) &&
		IsObjectFriendly(other, GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")))
	{
		ret.Value = true;
		return MRES_Supercede;
	}
	
	// Unless we are the owner, assume every other entity is an enemy
	entity = FindParentOwnerEntity(entity);
	other = FindParentOwnerEntity(other);
	
	ret.Value = (entity == other);
	return MRES_Supercede;
}

static MRESReturn DHookCallback_CBaseEntity_PhysicsDispatchThink_Pre(int entity)
{
	if (!IsFriendlyFireEnabled())
		return MRES_Ignored;
	
	char classname[64];
	if (!GetEntityClassname(entity, classname, sizeof(classname)))
		return MRES_Ignored;
	
	if (StrEqual(classname, "obj_sentrygun"))
	{
		// CObjectSentrygun::SentryThink
		if (SDKCall_CBaseEntity_GetNextThink(entity, "SentryThink") != TICK_NEVER_THINK)
			return MRES_Ignored;
		
		g_thinkFunction = ThinkFunction_SentryThink;
		
		TFTeam myTeam = TF2_GetEntityTeam(entity);
		TFTeam enemyTeam = GetEnemyTeam(myTeam);
		Address pEnemyTeam = SDKCall_GetGlobalTeam(enemyTeam);
		
		// CObjectSentrygun::FindTarget uses CTFTeamManager to collect valid players.
		// Add all enemy players to the desired team.
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client))
			{
				TFTeam team = TF2_GetClientTeam(client);
				Entity(client).PreHookTeam = team;
				bool friendly = IsObjectFriendly(entity, client);
				
				if (friendly && team == enemyTeam)
				{
					SDKCall_CTeam_RemovePlayer(pEnemyTeam, client);
				}
				else if (!friendly && team != enemyTeam)
				{
					SDKCall_CTeam_AddPlayer(pEnemyTeam, client);
				}
				
				// Sentry Guns don't shoot spies disguised as the same team, spoof the disguise team
				if (!friendly)
				{
					Entity(client).PreHookDisguiseTeam = view_as<TFTeam>(GetEntProp(client, Prop_Send, "m_nDisguiseTeam"));
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
				TFTeam team = TF2_GetEntityTeam(obj);
				Entity(obj).PreHookTeam = team;
				bool friendly = IsObjectFriendly(entity, obj);
				
				if (friendly && team == enemyTeam)
				{
					SDKCall_CTeam_RemoveObject(pEnemyTeam, obj);
				}
				else if (!friendly && team != enemyTeam)
				{
					SDKCall_CTeam_AddObject(pEnemyTeam, obj);
				}
			}
		}
	}
	else if (StrEqual(classname, "obj_dispenser") || StrEqual(classname, "pd_dispenser"))
	{
		// CObjectDispenser::DispenseThink
		if (SDKCall_CBaseEntity_GetNextThink(entity, "DispenseThink") != TICK_NEVER_THINK)
			return MRES_Ignored;
		
		if (!GetEntProp(entity, Prop_Send, "m_bPlacing") && !GetEntProp(entity, Prop_Send, "m_bBuilding"))
		{
			g_thinkFunction = ThinkFunction_DispenseThink;
			
			// Disallow players able to be healed from dispenser
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					if (!IsObjectFriendly(entity, client))
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
		if (SDKCall_CBaseEntity_GetNextThink(entity, "BaseObjectThink") != TICK_NEVER_THINK)
			return MRES_Ignored;
		
		g_thinkFunction = ThinkFunction_SapperThink;
		
		// Always set team to spectator so we can place sappers on buildings of both teams
		SDKCall_CBaseEntity_ChangeTeam(entity, TFTeam_Spectator);
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CBaseEntity_PhysicsDispatchThink_Post(int entity)
{
	if (!IsFriendlyFireEnabled())
		return MRES_Ignored;
	
	switch (g_thinkFunction)
	{
		case ThinkFunction_SentryThink:
		{
			TFTeam myTeam = TF2_GetEntityTeam(entity);
			TFTeam enemyTeam = GetEnemyTeam(myTeam);
			Address pEnemyTeam = SDKCall_GetGlobalTeam(enemyTeam);
			
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					TFTeam team = Entity(client).PreHookTeam;
					Entity(client).PreHookTeam = TFTeam_Unassigned;
					bool friendly = IsObjectFriendly(entity, client);
					
					if (friendly && team == enemyTeam)
					{
						SDKCall_CTeam_AddPlayer(pEnemyTeam, client);
					}
					else if (!friendly && team != enemyTeam)
					{
						SDKCall_CTeam_RemovePlayer(pEnemyTeam, client);
					}
					
					if (!friendly)
					{
						SetEntProp(client, Prop_Send, "m_nDisguiseTeam", Entity(client).PreHookDisguiseTeam);
						Entity(client).PreHookDisguiseTeam = TFTeam_Unassigned;
					}
				}
			}
			
			int obj = -1;
			while ((obj = FindEntityByClassname(obj, "obj_*")) != -1)
			{
				if (!GetEntProp(obj, Prop_Send, "m_bPlacing"))
				{
					TFTeam team = Entity(obj).PreHookTeam;
					bool friendly = IsObjectFriendly(entity, obj);
					
					if (friendly && team == enemyTeam)
					{
						SDKCall_CTeam_AddObject(pEnemyTeam, obj);
					}
					else if (!friendly && team != enemyTeam)
					{
						SDKCall_CTeam_RemoveObject(pEnemyTeam, obj);
					}
					
					Entity(obj).PreHookTeam = TFTeam_Unassigned;
				}
			}
		}
		case ThinkFunction_DispenseThink:
		{
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					if (!IsObjectFriendly(entity, client))
					{
						Entity(client).ResetTeam();
					}
				}
			}
		}
	}
	
	g_thinkFunction = ThinkFunction_None;
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPipebombLauncher_SecondaryAttack_Pre(int weapon)
{
	if (!IsFriendlyFireEnabled())
		return MRES_Ignored;
	
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

static MRESReturn DHookCallback_CTFPipebombLauncher_SecondaryAttack_Post(int weapon)
{
	if (!IsFriendlyFireEnabled())
		return MRES_Ignored;
	
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

static MRESReturn DHookCallback_CTFWeaponBaseGrenade_VPhysicsUpdate_Pre(int entity, DHookParam params)
{
	if (!IsFriendlyFireEnabled())
		return MRES_Ignored;
	
	int thrower = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	TFTeam enemyTeam = GetEnemyTeam(TF2_GetEntityTeam(entity));
	
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
		if (!IsObjectFriendly(obj, thrower))
			continue;
		
		Entity(obj).SetTeam(enemyTeam);
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFWeaponBaseGrenade_VPhysicsUpdate_Post(int entity, DHookParam params)
{
	if (!IsFriendlyFireEnabled())
		return MRES_Ignored;
	
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
		if (!IsObjectFriendly(obj, thrower))
			continue;
		
		Entity(obj).ResetTeam();
	}
	
	return MRES_Ignored;
}
