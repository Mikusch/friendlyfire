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
	ThinkFunction_MedigunHealTargetThink,
	ThinkFunction_TossJarThink,
}

static DynamicHook g_dhook_CBaseProjectile_CanCollideWithTeammates;
static DynamicHook g_dhook_CTFSniperRifle_GetCustomDamageType;
static DynamicHook g_dhook_CBaseGrenade_Explode;
static DynamicHook g_dhook_CTFBaseRocket_Explode;
static DynamicHook g_dhook_CBasePlayer_Event_Killed;
static DynamicHook g_dhook_CTFWeaponBase_DeflectProjectiles;
static DynamicHook g_dhook_CTFWeaponBaseMelee_Smack;
static DynamicHook g_dhook_CTFWeaponBase_SecondaryAttack;
static DynamicHook g_dhook_CBaseEntity_Deflected;
static DynamicHook g_dhook_CBaseEntity_VPhysicsUpdate;

static ThinkFunction g_thinkFunction = ThinkFunction_None;
static bool g_suspendInSameTeam;

void DHooks_Init()
{
	PSM_AddDynamicDetourFromConf("CBaseEntity::InSameTeam", DHookCallback_CBaseEntity_InSameTeam_Pre);
	PSM_AddDynamicDetourFromConf("CTFGameRules::TFVoiceManager", DHookCallback_CTFGameRules_TFVoiceManager_Pre, DHookCallback_CTFGameRules_TFVoiceManager_Post);
	PSM_AddDynamicDetourFromConf("CObjectTeleporter::RecieveTeleportingPlayer", DHookCallback_CObjectTeleporter_RecieveTeleportingPlayer_Pre, DHookCallback_CObjectTeleporter_RecieveTeleportingPlayer_Post);
	PSM_AddDynamicDetourFromConf("CBaseEntity::PhysicsDispatchThink", DHookCallback_CBaseEntity_PhysicsDispatchThink_Pre, DHookCallback_CBaseEntity_PhysicsDispatchThink_Post, AreTeammatesEnemies, sm_ff_teammates_are_enemies);
	PSM_AddDynamicDetourFromConf("CTFPlayer::ApplyGenericPushbackImpulse", DHookCallback_CTFPlayer_ApplyGenericPushbackImpulse_Pre, DHookCallback_CTFPlayer_ApplyGenericPushbackImpulse_Post);
	PSM_AddDynamicDetourFromConf("CTFPlayer::CanAttack", DHookCallback_CTFPlayer_CanAttack_Pre, DHookCallback_CTFPlayer_CanAttack_Post);
	PSM_AddDynamicDetourFromConf("CTFPlayerShared::StunPlayer", DHookCallback_CTFPlayerShared_StunPlayer_Pre, DHookCallback_CTFPlayerShared_StunPlayer_Post);
	
	g_dhook_CBaseProjectile_CanCollideWithTeammates = PSM_AddDynamicHookFromConf("CBaseProjectile::CanCollideWithTeammates");
	g_dhook_CTFSniperRifle_GetCustomDamageType = PSM_AddDynamicHookFromConf("CTFSniperRifle::GetCustomDamageType");
	g_dhook_CBaseGrenade_Explode = PSM_AddDynamicHookFromConf("CBaseGrenade::Explode");
	g_dhook_CTFBaseRocket_Explode = PSM_AddDynamicHookFromConf("CTFBaseRocket::Explode");
	g_dhook_CBasePlayer_Event_Killed = PSM_AddDynamicHookFromConf("CBasePlayer::Event_Killed");
	g_dhook_CTFWeaponBase_DeflectProjectiles = PSM_AddDynamicHookFromConf("CTFWeaponBase::DeflectProjectiles");
	g_dhook_CTFWeaponBaseMelee_Smack = PSM_AddDynamicHookFromConf("CTFWeaponBaseMelee::Smack");
	g_dhook_CTFWeaponBase_SecondaryAttack = PSM_AddDynamicHookFromConf("CTFWeaponBase::SecondaryAttack");
	g_dhook_CBaseEntity_Deflected = PSM_AddDynamicHookFromConf("CBaseEntity::Deflected");
	g_dhook_CBaseEntity_VPhysicsUpdate = PSM_AddDynamicHookFromConf("CBaseEntity::VPhysicsUpdate");
}

static MRESReturn DHookCallback_CTFGameRules_TFVoiceManager_Pre(DHookReturn ret, DHookParam params)
{
	g_suspendInSameTeam = !AreTeammatesEnemies();

	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFGameRules_TFVoiceManager_Post(DHookReturn ret, DHookParam params)
{
	g_suspendInSameTeam = false;

	return MRES_Ignored;
}

static MRESReturn DHookCallback_CObjectTeleporter_RecieveTeleportingPlayer_Pre(int entity, DHookParam params)
{
	g_suspendInSameTeam = !AreTeammatesEnemies();

	return MRES_Ignored;
}

static MRESReturn DHookCallback_CObjectTeleporter_RecieveTeleportingPlayer_Post(int entity, DHookParam params)
{
	g_suspendInSameTeam = false;

	return MRES_Ignored;
}

void DHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (IsEntityClient(entity))
	{
		// Fixes on-death effects (e.g. ragdolls) showing spectator visuals
		PSM_DHookEntity(g_dhook_CBasePlayer_Event_Killed, Hook_Pre, entity, DHookCallback_CTFPlayer_Event_Killed_Pre);
		PSM_DHookEntity(g_dhook_CBasePlayer_Event_Killed, Hook_Post, entity, DHookCallback_CTFPlayer_Event_Killed_Post);
	}
	else if (!strncmp(classname, "tf_projectile_", 14))
	{
		// Fixes projectiles sometimes not colliding with teammates
		PSM_DHookEntity(g_dhook_CBaseProjectile_CanCollideWithTeammates, Hook_Post, entity, DHookCallback_CBaseProjectile_CanCollideWithTeammates_Post);
		
		// Fixes reflected projectiles being in spectator team
		PSM_DHookEntity(g_dhook_CBaseEntity_Deflected, Hook_Pre, entity, DHookCallback_CBaseEntity_Deflected_Pre);
		PSM_DHookEntity(g_dhook_CBaseEntity_Deflected, Hook_Post, entity, DHookCallback_CBaseEntity_Deflected_Post);
		
		if (IsEntityBaseGrenadeProjectile(entity))
		{
			// Fixes grenades rarely bouncing off friendly objects
			PSM_DHookEntity(g_dhook_CBaseEntity_VPhysicsUpdate, Hook_Pre, entity, DHookCallback_CTFWeaponBaseGrenadeProj_VPhysicsUpdate_Pre);
			PSM_DHookEntity(g_dhook_CBaseEntity_VPhysicsUpdate, Hook_Post, entity, DHookCallback_CTFWeaponBaseGrenade_VPhysicsUpdate_Post);
		}
		
		if (!strncmp(classname, "tf_projectile_jar", 17))
		{
			// Fixes jars not applying effects to teammates when hitting the world
			PSM_DHookEntity(g_dhook_CBaseGrenade_Explode, Hook_Pre, entity, DHookCallback_CTFProjectile_Jar_Explode_Pre);
			PSM_DHookEntity(g_dhook_CBaseGrenade_Explode, Hook_Post, entity, DHookCallback_CTFProjectile_Jar_Explode_Post);
		}
		else if (StrEqual(classname, "tf_projectile_flare"))
		{
			// Fixes Scorch Shot knockback on teammates
			PSM_DHookEntity(g_dhook_CTFBaseRocket_Explode, Hook_Pre, entity, DHookCallback_CTFProjectile_Flare_Explode_Pre);
			PSM_DHookEntity(g_dhook_CTFBaseRocket_Explode, Hook_Post, entity, DHookCallback_CTFProjectile_Flare_Explode_Post);
		}
		else if (StrEqual(classname, "tf_projectile_spellfireball"))
		{
			// Fixes the Fireball spell not burning or knocking back teammates
			PSM_DHookEntity(g_dhook_CTFBaseRocket_Explode, Hook_Pre, entity, DHookCallback_CTFProjectile_SpellFireball_Explode_Pre);
			PSM_DHookEntity(g_dhook_CTFBaseRocket_Explode, Hook_Post, entity, DHookCallback_CTFProjectile_SpellFireball_Explode_Post);
		}
	}
	else if (IsEntityBaseCombatWeapon(entity))
	{
		// Fixes weapons able to deflect entities during truce
		PSM_DHookEntity(g_dhook_CTFWeaponBase_DeflectProjectiles, Hook_Pre, entity, DHookCallback_CTFWeaponBase_DeflectProjectiles_Pre);
		PSM_DHookEntity(g_dhook_CTFWeaponBase_DeflectProjectiles, Hook_Post, entity, DHookCallback_CTFWeaponBase_DeflectProjectiles_Post);
		
		if (IsEntityBaseMelee(entity))
		{
			// Fixes wrenches not being able to upgrade friendly objects, as well as a few other melee weapons
			PSM_DHookEntity(g_dhook_CTFWeaponBaseMelee_Smack, Hook_Pre, entity, DHookCallback_CTFWeaponBaseMelee_Smack_Pre);
			PSM_DHookEntity(g_dhook_CTFWeaponBaseMelee_Smack, Hook_Post, entity, DHookCallback_CTFWeaponBaseMelee_Smack_Post);
		}
		else
		{
			int weaponID = SDKCall_CTFWeaponBase_GetWeaponID(entity);
			if (weaponID == TF_WEAPON_SNIPERRIFLE || weaponID == TF_WEAPON_SNIPERRIFLE_DECAP || weaponID == TF_WEAPON_SNIPERRIFLE_CLASSIC)
			{
				// Fixes Sniper Rifles dealing no damage to teammates
				PSM_DHookEntity(g_dhook_CTFSniperRifle_GetCustomDamageType, Hook_Post, entity, DHookCallback_CTFSniperRifle_GetCustomDamageType_Post);
			}
			else if (weaponID == TF_WEAPON_PIPEBOMBLAUNCHER)
			{
				// Fixes pipebomb launchers not being able to knock around friendly pipebombs
				PSM_DHookEntity(g_dhook_CTFWeaponBase_SecondaryAttack, Hook_Pre, entity, DHookCallback_CTFPipebombLauncher_SecondaryAttack_Pre);
				PSM_DHookEntity(g_dhook_CTFWeaponBase_SecondaryAttack, Hook_Post, entity, DHookCallback_CTFPipebombLauncher_SecondaryAttack_Post);
			}
		}
	}
}

static MRESReturn DHookCallback_CTFPlayer_Event_Killed_Pre(int player, DHookParam params)
{
	Spoof_BeginFrame();
	
	// Switch back to the original team to force proper skin for ragdolls and other on-death effects
	Spoof_ChangeToOriginalTeam(player);

	int attacker = params.GetObjectVar(1, g_offset_CTakeDamageInfo_m_hAttacker, ObjectValueType_Ehandle);
	if (IsEntityClient(attacker) && attacker != player)
	{
		Spoof_ChangeToOriginalTeam(attacker);
	}

	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayer_Event_Killed_Post(int player, DHookParam params)
{
	Spoof_EndFrame();

	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFWeaponBase_DeflectProjectiles_Pre(int weapon, DHookReturn ret)
{
	Spoof_BeginFrame();

	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwner");
	if (IsEntityClient(owner))
	{
		// DeflectProjectiles checks the enemy team of each entity in the box
		Spoof_ChangeToOriginalTeam(owner);

		// Airblasting a teammate extinguishes them instead of pushing them around
		if (!AreTeammatesEnemies())
			return MRES_Ignored;

		TFTeam enemyTeam = GetEnemyTeam(TF2_GetClientTeam(owner));

		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && client != owner)
			{
				Spoof_SetTeam(client, enemyTeam);
			}
		}

		// CTFFlameThrower::DeflectEntity compares raw team numbers.
		// A teammate's projectile is not a valid airblast target until it looks like it belongs to the enemy team.
		int projectile = -1;
		while ((projectile = FindEntityByClassname(projectile, "tf_projectile_*")) != -1)
		{
			if (TF2_GetEntityTeam(projectile) != enemyTeam)
			{
				Spoof_SetTeam(projectile, enemyTeam);
			}
		}
	}

	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFWeaponBase_DeflectProjectiles_Post(int weapon, DHookReturn ret)
{
	Spoof_EndFrame();

	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFProjectile_Jar_Explode_Pre(int entity, DHookParam params)
{
	Spoof_BeginFrame();

	if (!AreTeammatesEnemies())
	{
		// A jar that lands on a teammate extinguishes them instead of coating them, which needs real teams.
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client))
			{
				Spoof_ChangeToOriginalTeam(client);
			}
		}

		return MRES_Ignored;
	}

	int thrower = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (thrower != -1)
	{
		Spoof_ChangeToSpectator(thrower);
		Spoof_ChangeToSpectator(entity);
	}

	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFProjectile_Jar_Explode_Post(int entity, DHookParam params)
{
	Spoof_EndFrame();

	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFProjectile_Flare_Explode_Pre(int entity, DHookParam params)
{
	Spoof_BeginFrame();
	
	if (!params.IsNull(2))
		Spoof_ChangeToSpectator(params.Get(2));
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFProjectile_Flare_Explode_Post(int entity, DHookParam params)
{
	Spoof_EndFrame();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFProjectile_SpellFireball_Explode_Pre(int entity, DHookParam params)
{
	Spoof_BeginFrame();

	// ExplodeEffectOnTarget skips every target that shares our team number
	Spoof_ChangeToSpectator(entity);

	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFProjectile_SpellFireball_Explode_Post(int entity, DHookParam params)
{
	Spoof_EndFrame();

	return MRES_Ignored;
}

static MRESReturn DHookCallback_CBaseProjectile_CanCollideWithTeammates_Post(int entity, DHookReturn ret)
{
	if (!AreTeammatesEnemies())
	{
		switch (SDKCall_CBaseProjectile_GetProjectileType(entity))
		{
			// Grappling onto a teammate is not friendly fire
			case TF_PROJECTILE_GRAPPLINGHOOK:
				return MRES_Ignored;

			// Jars keep their grace period, so they still fly past a teammate that is not burning instead of stopping on them.
			// See CTFProjectile_Jar::PipebombTouch.
			case TF_PROJECTILE_JAR, TF_PROJECTILE_JAR_MILK, TF_PROJECTILE_JAR_GAS, TF_PROJECTILE_FESTIVE_JAR, TF_PROJECTILE_BREADMONSTER_JARATE, TF_PROJECTILE_BREADMONSTER_MADMILK:
				return MRES_Ignored;
		}
	}

	// Always make projectiles collide with teammates
	ret.Value = true;

	return MRES_Supercede;
}

static MRESReturn DHookCallback_CBaseEntity_Deflected_Pre(int entity, DHookParam params)
{
	Spoof_BeginFrame();
	
	// Make projectiles have the original team of the deflector
	if (!params.IsNull(1))
		Spoof_ChangeToOriginalTeam(params.Get(1));
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CBaseEntity_Deflected_Post(int entity, DHookParam params)
{
	Spoof_EndFrame();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFSniperRifle_GetCustomDamageType_Post(int entity, DHookReturn ret)
{
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
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (owner != -1)
	{
		Entity(owner).ChangeToSpectator();

		// The owner being in spectator makes friendly buildings valid melee targets, so move them along.
		// Only Wrenches do this, every other melee weapon is supposed to damage them.
		if (SDKCall_CTFWeaponBase_GetWeaponID(entity) == TF_WEAPON_WRENCH)
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
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (owner != -1)
	{
		Entity(owner).ResetTeam();

		if (SDKCall_CTFWeaponBase_GetWeaponID(entity) == TF_WEAPON_WRENCH)
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
	char classname[64];
	if (!GetEntityClassname(entity, classname, sizeof(classname)))
		return MRES_Ignored;
	
	// Special case, respawn rooms should work regardless
	if (StrEqual(classname, "func_respawnroom"))
		return MRES_Ignored;
	
	if (params.IsNull(1))
		return MRES_Ignored;
	
	int other = params.Get(1);
	
	// Allow Rescue Ranger healing bolts to work on friendly buildings
	if (StrEqual(classname, "tf_projectile_arrow") &&
		GetEntProp(entity, Prop_Send, "m_iProjectileType") == TF_PROJECTILE_BUILDING_REPAIR_BOLT &&
		IsEntityBaseObject(other) &&
		IsObjectFriendly(other, GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")))
	{
		ret.Value = true;
		return MRES_Supercede;
	}

	// Suspended while the game asks about relations that are not about damage
	if (g_suspendInSameTeam)
		return MRES_Ignored;

	// Crusader's Crossbow bolts keep healing teammates when they are only damageable
	if (!AreTeammatesEnemies() && StrEqual(classname, "tf_projectile_healing_bolt"))
		return MRES_Ignored;

	// Unless we are the owner, assume every other entity is an enemy
	entity = FindParentOwnerEntity(entity);
	other = FindParentOwnerEntity(other);
	
	ret.Value = (entity == other);
	return MRES_Supercede;
}

static MRESReturn DHookCallback_CBaseEntity_PhysicsDispatchThink_Pre(int entity)
{
	// Sentry Gun targeting, Dispenser eligibility and Sappers are all team-based
	if (!AreTeammatesEnemies())
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
		Spoof_BeginFrame();

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

		// The Wrangler's auto-aim target is confirmed with a trace that ignores everyone on the builder's team,
		// so move them out of the way to allow snapping onto teammates.
		int builder = GetEntPropEnt(entity, Prop_Send, "m_hBuilder");
		if (builder != -1)
		{
			int weapon = GetEntPropEnt(builder, Prop_Send, "m_hActiveWeapon");
			if (weapon != -1 && SDKCall_CTFWeaponBase_GetWeaponID(weapon) == TF_WEAPON_LASER_POINTER)
			{
				Spoof_ChangeToSpectator(builder);
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
	else if (StrEqual(classname, "tf_weapon_spellbook"))
	{
		// CTFSpellBook::TossJarThink
		if (SDKCall_CBaseEntity_GetNextThink(entity, "TOSS_JAR_THINK") != TICK_NEVER_THINK)
			return MRES_Ignored;

		g_thinkFunction = ThinkFunction_TossJarThink;
		Spoof_BeginFrame();

		// Self-cast spells like Overheal buff everyone on the caster's team in a radius
		int owner = FindParentOwnerEntity(entity);
		if (owner != entity)
		{
			Spoof_ChangeToSpectator(owner);
		}
	}
	else if (StrEqual(classname, "tf_weapon_medigun"))
	{
		// CWeaponMedigun::HealTargetThink
		if (SDKCall_CBaseEntity_GetNextThink(entity, "MedigunHealTargetThink") != TICK_NEVER_THINK)
			return MRES_Ignored;

		g_thinkFunction = ThinkFunction_MedigunHealTargetThink;
		Spoof_BeginFrame();

		// An established healing beam is only re-validated here.
		// CWeaponMedigun::AllowedToHealTarget keeps letting us heal enemies that are disguised as our own team.
		int owner = FindParentOwnerEntity(entity);
		if (owner != entity)
		{
			Spoof_ChangeToSpectator(owner);
		}
	}

	return MRES_Ignored;
}

static MRESReturn DHookCallback_CBaseEntity_PhysicsDispatchThink_Post(int entity)
{
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

			Spoof_EndFrame();
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
		case ThinkFunction_MedigunHealTargetThink:
		{
			Spoof_EndFrame();
		}
		case ThinkFunction_TossJarThink:
		{
			Spoof_EndFrame();
		}
	}

	g_thinkFunction = ThinkFunction_None;
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayer_ApplyGenericPushbackImpulse_Pre(int player, DHookParam params)
{
	Spoof_BeginFrame();
	
	if (params.IsNull(2))
		return MRES_Ignored;

	Spoof_ChangeToOriginalTeam(params.Get(2));
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayer_ApplyGenericPushbackImpulse_Post(int player, DHookParam params)
{
	Spoof_EndFrame();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayer_CanAttack_Pre(int player, DHookReturn ret, DHookParam params)
{
	// Fixes the winning team not being able to use certain weapon
	Entity(player).ChangeToOriginalTeam();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayer_CanAttack_Post(int player, DHookReturn ret, DHookParam params)
{
	Entity(player).ResetTeam();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayerShared_StunPlayer_Pre(Address shared, DHookParam params)
{
	Spoof_BeginFrame();
	
	if (params.IsNull(4))
		return MRES_Ignored;
	
	int attacker = params.Get(4);
	if (IsEntityClient(attacker))
		Spoof_ChangeToOriginalTeam(attacker);
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayerShared_StunPlayer_Post(Address shared, DHookParam params)
{
	Spoof_EndFrame();
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPipebombLauncher_SecondaryAttack_Pre(int weapon)
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

static MRESReturn DHookCallback_CTFPipebombLauncher_SecondaryAttack_Post(int weapon)
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

static MRESReturn DHookCallback_CTFWeaponBaseGrenadeProj_VPhysicsUpdate_Pre(int entity, DHookParam params)
{
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
	if (AreTeammatesEnemies())
	{
		int obj = -1;
		while ((obj = FindEntityByClassname(obj, "obj_*")) != -1)
		{
			if (!IsObjectFriendly(obj, thrower))
				continue;
			
			Entity(obj).SetTeam(enemyTeam);
		}
	}
	
	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFWeaponBaseGrenade_VPhysicsUpdate_Post(int entity, DHookParam params)
{
	int thrower = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		Entity(client).ResetTeam();
	}
	
	if (AreTeammatesEnemies())
	{
		int obj = -1;
		while ((obj = FindEntityByClassname(obj, "obj_*")) != -1)
		{
			if (!IsObjectFriendly(obj, thrower))
				continue;
			
			Entity(obj).ResetTeam();
		}
	}
	
	return MRES_Ignored;
}
