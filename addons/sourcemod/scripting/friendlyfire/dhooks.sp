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
	ThinkFunction_MedigunHealTargetThink,
	ThinkFunction_TossJarThink,
	ThinkFunction_OrbThink,
	ThinkFunction_ZapThink,
}

static DynamicHook g_dhook_CBaseProjectile_CanCollideWithTeammates;
static DynamicHook g_dhook_CTFSniperRifle_GetCustomDamageType;
static DynamicHook g_dhook_CBaseGrenade_Explode;
static DynamicHook g_dhook_CTFBaseRocket_Explode;
static DynamicHook g_dhook_CTFProjectile_SpellFireball_Explode;
static DynamicHook g_dhook_CBasePlayer_Event_Killed;
static DynamicHook g_dhook_CTFWeaponBase_DeflectProjectiles;
static DynamicHook g_dhook_CTFWeaponBaseMelee_Smack;
static DynamicHook g_dhook_CTFWeaponBase_SecondaryAttack;
static DynamicHook g_dhook_CBaseEntity_Deflected;
static DynamicHook g_dhook_CBaseEntity_VPhysicsUpdate;

static ThinkFunction g_thinkFunction = ThinkFunction_None;

void DHooks_Init()
{
	PSM_AddDynamicDetourFromConf("CBaseEntity::InSameTeam", DHookCallback_CBaseEntity_InSameTeam_Pre, _, AreTeammatesEnemies, sm_ff_teammates_are_enemies);
	PSM_AddDynamicDetourFromConf("CBaseEntity::PhysicsDispatchThink", DHookCallback_CBaseEntity_PhysicsDispatchThink_Pre, DHookCallback_CBaseEntity_PhysicsDispatchThink_Post);
	PSM_AddDynamicDetourFromConf("CTFPlayer::ApplyGenericPushbackImpulse", DHookCallback_CTFPlayer_ApplyGenericPushbackImpulse_Pre, DHookCallback_CTFPlayer_ApplyGenericPushbackImpulse_Post);
	PSM_AddDynamicDetourFromConf("CTFPlayer::CanAttack", DHookCallback_CTFPlayer_CanAttack_Pre, DHookCallback_CTFPlayer_CanAttack_Post);
	PSM_AddDynamicDetourFromConf("CTFPlayerShared::StunPlayer", DHookCallback_CTFPlayerShared_StunPlayer_Pre, DHookCallback_CTFPlayerShared_StunPlayer_Post);
	
	g_dhook_CBaseProjectile_CanCollideWithTeammates = PSM_AddDynamicHookFromConf("CBaseProjectile::CanCollideWithTeammates");
	g_dhook_CTFSniperRifle_GetCustomDamageType = PSM_AddDynamicHookFromConf("CTFSniperRifle::GetCustomDamageType");
	g_dhook_CBaseGrenade_Explode = PSM_AddDynamicHookFromConf("CBaseGrenade::Explode");
	g_dhook_CTFBaseRocket_Explode = PSM_AddDynamicHookFromConf("CTFBaseRocket::Explode");
	g_dhook_CTFProjectile_SpellFireball_Explode = PSM_AddDynamicHookFromConf("CTFProjectile_SpellFireball::Explode");
	g_dhook_CBasePlayer_Event_Killed = PSM_AddDynamicHookFromConf("CBasePlayer::Event_Killed");
	g_dhook_CTFWeaponBase_DeflectProjectiles = PSM_AddDynamicHookFromConf("CTFWeaponBase::DeflectProjectiles");
	g_dhook_CTFWeaponBaseMelee_Smack = PSM_AddDynamicHookFromConf("CTFWeaponBaseMelee::Smack");
	g_dhook_CTFWeaponBase_SecondaryAttack = PSM_AddDynamicHookFromConf("CTFWeaponBase::SecondaryAttack");
	g_dhook_CBaseEntity_Deflected = PSM_AddDynamicHookFromConf("CBaseEntity::Deflected");
	g_dhook_CBaseEntity_VPhysicsUpdate = PSM_AddDynamicHookFromConf("CBaseEntity::VPhysicsUpdate");
}

void DHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (IsEntityClient(entity))
	{
		// Fixes on-death effects (e.g. ragdolls) showing spectator visuals.
		PSM_DHookEntity(g_dhook_CBasePlayer_Event_Killed, Hook_Pre, entity, DHookCallback_CTFPlayer_Event_Killed_Pre);
		PSM_DHookEntity(g_dhook_CBasePlayer_Event_Killed, Hook_Post, entity, DHookCallback_CTFPlayer_Event_Killed_Post);
	}
	else if (!strncmp(classname, "tf_projectile_", 14))
	{
		// Fixes projectiles sometimes not colliding with teammates.
		PSM_DHookEntity(g_dhook_CBaseProjectile_CanCollideWithTeammates, Hook_Post, entity, DHookCallback_CBaseProjectile_CanCollideWithTeammates_Post);
		
		// Fixes reflected projectiles being in the spectator team.
		PSM_DHookEntity(g_dhook_CBaseEntity_Deflected, Hook_Pre, entity, DHookCallback_CBaseEntity_Deflected_Pre);
		PSM_DHookEntity(g_dhook_CBaseEntity_Deflected, Hook_Post, entity, DHookCallback_CBaseEntity_Deflected_Post);
		
		if (IsEntityBaseGrenadeProjectile(entity))
		{
			// Fixes grenades rarely bouncing off friendly objects.
			PSM_DHookEntity(g_dhook_CBaseEntity_VPhysicsUpdate, Hook_Pre, entity, DHookCallback_CTFWeaponBaseGrenadeProj_VPhysicsUpdate_Pre);
			PSM_DHookEntity(g_dhook_CBaseEntity_VPhysicsUpdate, Hook_Post, entity, DHookCallback_CTFWeaponBaseGrenade_VPhysicsUpdate_Post);
		}
		
		if (!strncmp(classname, "tf_projectile_jar", 17))
		{
			// Fixes jars not applying effects to teammates when hitting the world.
			PSM_DHookEntity(g_dhook_CBaseGrenade_Explode, Hook_Pre, entity, DHookCallback_CTFProjectile_Jar_Explode_Pre);
			PSM_DHookEntity(g_dhook_CBaseGrenade_Explode, Hook_Post, entity, DHookCallback_CTFProjectile_Jar_Explode_Post);
		}
		else if (StrEqual(classname, "tf_projectile_flare"))
		{
			// Fixes Scorch Shot knockback on teammates.
			PSM_DHookEntity(g_dhook_CTFBaseRocket_Explode, Hook_Pre, entity, DHookCallback_CTFProjectile_Flare_Explode_Pre);
			PSM_DHookEntity(g_dhook_CTFBaseRocket_Explode, Hook_Post, entity, DHookCallback_CTFProjectile_Flare_Explode_Post);
		}
		else if (StrEqual(classname, "tf_projectile_spellfireball"))
		{
			// Fixes the Fireball spell not burning or knocking back teammates.
			PSM_DHookEntity(g_dhook_CTFProjectile_SpellFireball_Explode, Hook_Pre, entity, DHookCallback_CTFProjectile_SpellFireball_Explode_Pre);
			PSM_DHookEntity(g_dhook_CTFProjectile_SpellFireball_Explode, Hook_Post, entity, DHookCallback_CTFProjectile_SpellFireball_Explode_Post);
		}
		else if (StrEqual(classname, "tf_projectile_spellbats"))
		{
			// Fixes the Bats spell not stunning, bleeding or launching teammates.
			PSM_DHookEntity(g_dhook_CBaseGrenade_Explode, Hook_Pre, entity, DHookCallback_CTFProjectile_SpellBats_Explode_Pre);
			PSM_DHookEntity(g_dhook_CBaseGrenade_Explode, Hook_Post, entity, DHookCallback_CTFProjectile_SpellBats_Explode_Post);
		}
	}
	else if (IsEntityBaseCombatWeapon(entity))
	{
		// Fixes weapons being able to deflect entities during a truce.
		PSM_DHookEntity(g_dhook_CTFWeaponBase_DeflectProjectiles, Hook_Pre, entity, DHookCallback_CTFWeaponBase_DeflectProjectiles_Pre);
		PSM_DHookEntity(g_dhook_CTFWeaponBase_DeflectProjectiles, Hook_Post, entity, DHookCallback_CTFWeaponBase_DeflectProjectiles_Post);
		
		if (IsEntityBaseMelee(entity))
		{
			// Fixes wrenches not being able to upgrade friendly objects.
			PSM_DHookEntity(g_dhook_CTFWeaponBaseMelee_Smack, Hook_Pre, entity, DHookCallback_CTFWeaponBaseMelee_Smack_Pre);
			PSM_DHookEntity(g_dhook_CTFWeaponBaseMelee_Smack, Hook_Post, entity, DHookCallback_CTFWeaponBaseMelee_Smack_Post);
		}
		else
		{
			int weaponID = SDKCall_CTFWeaponBase_GetWeaponID(entity);
			if (weaponID == TF_WEAPON_SNIPERRIFLE || weaponID == TF_WEAPON_SNIPERRIFLE_DECAP || weaponID == TF_WEAPON_SNIPERRIFLE_CLASSIC)
			{
				// Fixes Sniper Rifles dealing no damage to teammates.
				PSM_DHookEntity(g_dhook_CTFSniperRifle_GetCustomDamageType, Hook_Post, entity, DHookCallback_CTFSniperRifle_GetCustomDamageType_Post);
			}
			else if (weaponID == TF_WEAPON_PIPEBOMBLAUNCHER)
			{
				// Fixes pipebomb launchers not being able to knock around friendly pipebombs.
				PSM_DHookEntity(g_dhook_CTFWeaponBase_SecondaryAttack, Hook_Pre, entity, DHookCallback_CTFPipebombLauncher_SecondaryAttack_Pre);
				PSM_DHookEntity(g_dhook_CTFWeaponBase_SecondaryAttack, Hook_Post, entity, DHookCallback_CTFPipebombLauncher_SecondaryAttack_Post);
			}
		}
	}
}

static MRESReturn DHookCallback_CTFPlayer_Event_Killed_Pre(int player, DHookParam params)
{
	Spoof_BeginFrame();
	
	// Switch back to the original team so ragdolls and other on-death effects use the right skin.
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
		// DeflectProjectiles checks the enemy team of each entity in the box.
		Spoof_ChangeToOriginalTeam(owner);

		TFTeam enemyTeam = GetEnemyTeam(TF2_GetClientTeam(owner));

		// Airblasting a teammate extinguishes them instead of pushing them around.
		if (AreTeammatesEnemies())
		{
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client) && client != owner)
				{
					Spoof_SetTeam(client, enemyTeam);
				}
			}
		}

		// CTFFlameThrower::DeflectEntity compares raw team numbers.
		// A teammate's projectile is not a valid airblast target until it looks like it belongs to the enemy team.
		int projectile = -1;
		while ((projectile = FindEntityByClassname(projectile, "tf_projectile_*")) != -1)
		{
			// Our own projectiles were never deflectable, leave them alone.
			if (FindParentOwnerEntity(projectile) == owner)
				continue;

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

	// ExplodeEffectOnTarget skips every target that shares our team number.
	Spoof_ChangeToSpectator(entity);

	// Move the caster along with the fireball so they still compare equal to it and stay excluded.
	int thrower = FindParentOwnerEntity(entity);
	if (thrower != entity)
	{
		Spoof_ChangeToSpectator(thrower);
	}

	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFProjectile_SpellFireball_Explode_Post(int entity, DHookParam params)
{
	Spoof_EndFrame();

	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFProjectile_SpellBats_Explode_Pre(int entity, DHookParam params)
{
	Spoof_BeginFrame();

	// ExplodeEffectOnTarget skips every target that shares our team number.
	Spoof_ChangeToSpectator(entity);

	int thrower = FindParentOwnerEntity(entity);
	if (thrower != entity)
	{
		Spoof_ChangeToSpectator(thrower);
	}

	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFProjectile_SpellBats_Explode_Post(int entity, DHookParam params)
{
	Spoof_EndFrame();

	return MRES_Ignored;
}

static MRESReturn DHookCallback_CBaseProjectile_CanCollideWithTeammates_Post(int entity, DHookReturn ret)
{
	if (!AreTeammatesEnemies())
	{
		// Grappling onto a teammate is not friendly fire.
		if (SDKCall_CBaseProjectile_GetProjectileType(entity) == TF_PROJECTILE_GRAPPLINGHOOK)
			return MRES_Ignored;

		// Jars keep their grace period, so they still fly past teammates that are not burning.
		// See CTFProjectile_Jar::PipebombTouch.
		if (IsJarProjectile(entity))
			return MRES_Ignored;
	}

	ret.Value = true;

	return MRES_Supercede;
}

static MRESReturn DHookCallback_CBaseEntity_Deflected_Pre(int entity, DHookParam params)
{
	Spoof_BeginFrame();
	
	// Make projectiles have the original team of the deflector.
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
	// Allow Sydney Sleeper shots to pass through healthy teammates and extinguish burning ones.
	// SourceMod's TF_CUSTOM_PENETRATE_HEADSHOT is a stale name for TF_DMG_CUSTOM_PENETRATE_NONBURNING_TEAMMATE.
	if (!AreTeammatesEnemies() && ret.Value == TF_CUSTOM_PENETRATE_HEADSHOT)
		return MRES_Ignored;

	// Allows Sniper Rifles to hit teammates, without breaking Machina penetration.
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
	Spoof_BeginFrame();

	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (owner == -1)
		return MRES_Ignored;

	// Wrenches need the owner in spectator to repair friendly buildings.
	bool isWrench = SDKCall_CTFWeaponBase_GetWeaponID(entity) == TF_WEAPON_WRENCH;
	if (!AreTeammatesEnemies() && !isWrench)
		return MRES_Ignored;

	// The owner being in spectator makes friendly buildings valid melee targets, so move them along.
	if (isWrench)
	{
		int obj = -1;
		while ((obj = FindEntityByClassname(obj, "obj_*")) != -1)
		{
			if (!IsObjectFriendly(obj, owner))
				continue;

			Spoof_ChangeToSpectator(obj);
		}
	}

	Spoof_ChangeToSpectator(owner);

	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFWeaponBaseMelee_Smack_Post(int entity)
{
	Spoof_EndFrame();

	return MRES_Ignored;
}

static MRESReturn DHookCallback_CBaseEntity_InSameTeam_Pre(int entity, DHookReturn ret, DHookParam params)
{
	if (!AreTeammatesEnemies())
		return MRES_Ignored;

	char classname[64];
	if (!GetEntityClassname(entity, classname, sizeof(classname)))
		return MRES_Ignored;
	
	// Special case, respawn rooms should work regardless.
	if (StrEqual(classname, "func_respawnroom"))
		return MRES_Ignored;
	
	if (params.IsNull(1))
		return MRES_Ignored;
	
	int other = params.Get(1);
	
	// Allow Rescue Ranger healing bolts to work on friendly buildings.
	if (StrEqual(classname, "tf_projectile_arrow") &&
		GetEntProp(entity, Prop_Send, "m_iProjectileType") == TF_PROJECTILE_BUILDING_REPAIR_BOLT &&
		IsEntityBaseObject(other) &&
		IsObjectFriendly(other, GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")))
	{
		ret.Value = true;
		return MRES_Supercede;
	}

	// Unless we are the owner, assume every other entity is an enemy.
	entity = FindParentOwnerEntity(entity);
	other = FindParentOwnerEntity(other);
	
	ret.Value = (entity == other);
	return MRES_Supercede;
}

static void SpoofWrangledSentryTargets(int sentry)
{
	int builder = GetEntPropEnt(sentry, Prop_Send, "m_hBuilder");
	if (builder == -1)
		return;

	int weapon = GetEntPropEnt(builder, Prop_Send, "m_hActiveWeapon");
	if (weapon == -1 || SDKCall_CTFWeaponBase_GetWeaponID(weapon) != TF_WEAPON_LASER_POINTER)
		return;

	TFTeam enemyTeam = GetEnemyTeam(TF2_GetClientTeam(builder));

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && client != builder)
		{
			Spoof_SetTeam(client, enemyTeam);
		}
	}
}

static MRESReturn DHookCallback_CBaseEntity_PhysicsDispatchThink_Pre(int entity)
{
	char classname[64];
	if (!GetEntityClassname(entity, classname, sizeof(classname)))
		return MRES_Ignored;

	// These orbs damage from a think and skip the owner's team, so the owner has to move out of the way.
	// Handled before the convar gate below, because they are purely offensive in both modes.
	if (StrEqual(classname, "tf_projectile_mechanicalarmorb"))
	{
		// CTFProjectile_MechanicalArmOrb::OrbThink, and the terminal burst from ExplodeAndRemove.
		if (!IsThinkRunning(entity, "OrbThink") && !IsThinkRunning(entity, "ExplodeAndRemoveThink"))
			return MRES_Ignored;

		g_thinkFunction = ThinkFunction_OrbThink;
		Spoof_BeginFrame();

		int owner = FindParentOwnerEntity(entity);
		if (owner != entity)
		{
			Spoof_ChangeToSpectator(owner);
		}

		return MRES_Ignored;
	}
	else if (StrEqual(classname, "tf_projectile_lightningorb"))
	{
		// CTFProjectile_SpellLightningOrb::ZapThink and VortexThink, and the terminal burst from ExplodeAndRemove.
		if (!IsThinkRunning(entity, "ZapThink") && !IsThinkRunning(entity, "VortexThink") && !IsThinkRunning(entity, "ExplodeAndRemoveThink"))
			return MRES_Ignored;

		g_thinkFunction = ThinkFunction_ZapThink;
		Spoof_BeginFrame();

		// VortexThink compares against the orb itself rather than the owner, so both have to move.
		Spoof_ChangeToSpectator(entity);

		int owner = FindParentOwnerEntity(entity);
		if (owner != entity)
		{
			Spoof_ChangeToSpectator(owner);
		}

		return MRES_Ignored;
	}

	// Sentry Gun targeting, Dispenser eligibility and Sappers are all team-based.
	if (!AreTeammatesEnemies())
		return MRES_Ignored;

	if (StrEqual(classname, "obj_sentrygun"))
	{
		// CObjectSentrygun::SentryThink
		if (!IsThinkRunning(entity, "SentrygunContext"))
			return MRES_Ignored;

		g_thinkFunction = ThinkFunction_SentryThink;
		Spoof_BeginFrame();

		TFTeam myTeam = TF2_GetEntityTeam(entity);
		TFTeam enemyTeam = GetSentryEnemyTeam(myTeam);
		Address pEnemyTeam = SDKCall_GetGlobalTeam(enemyTeam);

		// CObjectSentrygun::FindTarget uses CTFTeamManager to collect valid players.
		// Add all enemy players to the desired team.
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client))
			{
				TFTeam team = TF2_GetClientTeam(client);
				bool friendly = IsObjectFriendly(entity, client);

				// Keep shooting a Spy who disguises after being acquired.
				if (friendly && GetEntPropEnt(entity, Prop_Send, "m_hEnemy") == client)
					friendly = false;

				// Latch both inputs, the think can kill a disguised Spy and flip the answer under us.
				Entity(client).PreHookTeam = team;
				Entity(client).PreHookFriendly = friendly;

				if (friendly && team == enemyTeam)
				{
					SDKCall_CTeam_RemovePlayer(pEnemyTeam, client);
				}
				else if (!friendly && team != enemyTeam)
				{
					SDKCall_CTeam_AddPlayer(pEnemyTeam, client);
				}
				
				// Sentry Guns don't shoot Spies disguised as their own team, so spoof the disguise team.
				if (!friendly)
				{
					Entity(client).PreHookDisguiseTeam = view_as<TFTeam>(GetEntProp(client, Prop_Send, "m_nDisguiseTeam"));
					SetEntProp(client, Prop_Send, "m_nDisguiseTeam", TFTeam_Unassigned);
				}
			}
		}

		// Buildings work in a similar way.
		// NOTE: CBaseObject::ChangeTeam recreates the build points and breaks sapper placement, so we use AddObject/RemoveObject.
		int obj = -1;
		while ((obj = FindEntityByClassname(obj, "obj_*")) != -1)
		{
			if (obj != entity && !GetEntProp(obj, Prop_Send, "m_bPlacing"))
			{
				TFTeam team = TF2_GetEntityTeam(obj);
				bool friendly = IsObjectFriendly(entity, obj);

				Entity(obj).PreHookTeam = team;
				Entity(obj).PreHookFriendly = friendly;

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

		// Has to run last, the latching above reads real team numbers.
		SpoofWrangledSentryTargets(entity);
	}
	else if (StrEqual(classname, "obj_dispenser") || StrEqual(classname, "pd_dispenser"))
	{
		// CObjectDispenser::DispenseThink
		if (!IsThinkRunning(entity, "DispenseContext"))
			return MRES_Ignored;
		
		if (!GetEntProp(entity, Prop_Send, "m_bPlacing") && !GetEntProp(entity, Prop_Send, "m_bBuilding"))
		{
			g_thinkFunction = ThinkFunction_DispenseThink;
			Spoof_BeginFrame();

			// Stop the Dispenser from healing players that are not friendly to it.
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					if (!IsObjectFriendly(entity, client))
					{
						Spoof_ChangeToSpectator(client);
					}
				}
			}
		}
	}
	else if (StrEqual(classname, "obj_attachment_sapper"))
	{
		// CBaseObject::BaseObjectThink
		if (!IsThinkRunning(entity, "BaseObjectThink"))
			return MRES_Ignored;

		// Always set team to spectator so we can place sappers on buildings of both teams.
		SDKCall_CBaseEntity_ChangeTeam(entity, TFTeam_Spectator);
	}
	else if (StrEqual(classname, "tf_weapon_spellbook"))
	{
		// CTFSpellBook::TossJarThink
		if (!IsThinkRunning(entity, "TOSS_JAR_THINK"))
			return MRES_Ignored;

		g_thinkFunction = ThinkFunction_TossJarThink;
		Spoof_BeginFrame();

		// Self-cast spells like Overheal buff everyone on the caster's team in a radius.
		int owner = FindParentOwnerEntity(entity);
		if (owner != entity && IsEntityClient(owner))
		{
			TFTeam enemyTeam = GetEnemyTeam(TF2_GetClientTeam(owner));

			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client) && client != owner)
				{
					Spoof_SetTeam(client, enemyTeam);
				}
			}
		}
	}
	else if (StrEqual(classname, "tf_weapon_medigun"))
	{
		// CWeaponMedigun::HealTargetThink
		if (!IsThinkRunning(entity, "MedigunHealTargetThink") || GetEntPropEnt(entity, Prop_Send, "m_hHealingTarget") == -1)
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
			TFTeam enemyTeam = GetSentryEnemyTeam(myTeam);
			Address pEnemyTeam = SDKCall_GetGlobalTeam(enemyTeam);

			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					TFTeam team = Entity(client).PreHookTeam;
					bool friendly = Entity(client).PreHookFriendly;

					Entity(client).PreHookTeam = TFTeam_Unassigned;
					Entity(client).PreHookFriendly = false;

					if (friendly && team == enemyTeam)
					{
						SDKCall_CTeam_AddPlayer(pEnemyTeam, client);
					}
					else if (!friendly && team != enemyTeam)
					{
						SDKCall_CTeam_RemovePlayer(pEnemyTeam, client);
					}

					// Only undo our own write, the think may have killed the Spy and cleared his disguise.
					if (!friendly && view_as<TFTeam>(GetEntProp(client, Prop_Send, "m_nDisguiseTeam")) == TFTeam_Unassigned)
					{
						SetEntProp(client, Prop_Send, "m_nDisguiseTeam", Entity(client).PreHookDisguiseTeam);
					}

					Entity(client).PreHookDisguiseTeam = TFTeam_Unassigned;
				}
			}

			int obj = -1;
			while ((obj = FindEntityByClassname(obj, "obj_*")) != -1)
			{
				if (obj != entity && !GetEntProp(obj, Prop_Send, "m_bPlacing"))
				{
					TFTeam team = Entity(obj).PreHookTeam;
					bool friendly = Entity(obj).PreHookFriendly;

					Entity(obj).PreHookTeam = TFTeam_Unassigned;
					Entity(obj).PreHookFriendly = false;

					if (friendly && team == enemyTeam)
					{
						SDKCall_CTeam_AddObject(pEnemyTeam, obj);
					}
					else if (!friendly && team != enemyTeam)
					{
						SDKCall_CTeam_RemoveObject(pEnemyTeam, obj);
					}
				}
			}

			Spoof_EndFrame();
		}
		case ThinkFunction_DispenseThink:
		{
			Spoof_EndFrame();
		}
		case ThinkFunction_MedigunHealTargetThink:
		{
			Spoof_EndFrame();
		}
		case ThinkFunction_TossJarThink:
		{
			Spoof_EndFrame();
		}
		case ThinkFunction_OrbThink:
		{
			Spoof_EndFrame();
		}
		case ThinkFunction_ZapThink:
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
	Spoof_BeginFrame();

	// Fixes the winning team not being able to use certain weapons.
	Spoof_ChangeToOriginalTeam(player);

	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPlayer_CanAttack_Post(int player, DHookReturn ret, DHookParam params)
{
	Spoof_EndFrame();

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
	Spoof_BeginFrame();

	Spoof_ChangeToSpectator(weapon);

	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	if (owner != -1)
	{
		Spoof_ChangeToSpectator(owner);
	}
	
	int pipe = -1;
	while ((pipe = FindEntityByClassname(pipe, "tf_projectile_pipe_remote")) != -1)
	{
		if (GetEntPropEnt(pipe, Prop_Send, "m_hLauncher") == weapon)
		{
			Spoof_ChangeToSpectator(pipe);
		}
	}

	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFPipebombLauncher_SecondaryAttack_Post(int weapon)
{
	Spoof_EndFrame();

	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFWeaponBaseGrenadeProj_VPhysicsUpdate_Pre(int entity, DHookParam params)
{
	Spoof_BeginFrame();

	int thrower = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	TFTeam enemyTeam = GetEnemyTeam(TF2_GetEntityTeam(entity));

	// VPhysicsUpdate only explodes on what it sees as the enemy team.
	// Jars are the exception, they have to keep flying past teammates to extinguish them later on.
	if (AreTeammatesEnemies() || !IsJarProjectile(entity))
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (!IsClientInGame(client))
				continue;

			Spoof_SetTeam(client, enemyTeam);
		}
	}

	// Fixes projectiles bouncing off buildings instead of exploding on them.
	int obj = -1;
	while ((obj = FindEntityByClassname(obj, "obj_*")) != -1)
	{
		if (thrower != -1 && GetEntPropEnt(obj, Prop_Send, "m_hBuilder") == thrower)
			continue;

		if (TF2_GetEntityTeam(obj) == enemyTeam)
			continue;

		Spoof_SetTeam(obj, enemyTeam);
	}

	return MRES_Ignored;
}

static MRESReturn DHookCallback_CTFWeaponBaseGrenade_VPhysicsUpdate_Post(int entity, DHookParam params)
{
	Spoof_EndFrame();

	return MRES_Ignored;
}
