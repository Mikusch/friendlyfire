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

enum PostThinkType
{
	PostThinkType_None,
	PostThinkType_Spectator,
	PostThinkType_EnemyTeam,
}

int g_spectatorItemIDs[] =
{
	TF_WEAPON_SNIPERRIFLE,			// CTFPlayer::FireBullet
	TF_WEAPON_SNIPERRIFLE_DECAP,	// CTFPlayer::FireBullet
	TF_WEAPON_SNIPERRIFLE_CLASSIC,	// CTFPlayer::FireBullet
	TF_WEAPON_KNIFE,				// CTFKnife::BackstabVMThink
};

// These only interact with teammates in a friendly way, so they are left alone unless teammates are enemies
int g_teammateSpectatorItemIDs[] =
{
	TF_WEAPON_BUFF_ITEM,		// CTFPlayerShared::PulseRageBuff
	TF_WEAPON_FLAMETHROWER,		// CTFFlameThrower::SecondaryAttack
	TF_WEAPON_FLAME_BALL,		// CWeaponFlameBall::SecondaryAttack
	TF_WEAPON_LASER_POINTER,	// CTFLaserPointer::UpdateLaserDot
	TF_WEAPON_MEDIGUN,			// CWeaponMedigun::AllowedToHealTarget
	TF_WEAPON_RAYGUN_REVENGE,	// CTFFlareGun_Revenge::ExtinguishPlayerInternal
};

int g_enemyItemIDs[] =
{
	TF_WEAPON_HANDGUN_SCOUT_PRIMARY,	// CTFPistol_ScoutPrimary::Push
	TF_WEAPON_ROCKETPACK,				// CTFRocketPack::Launch
};

// Grappling onto a teammate is not friendly fire, so it is left alone unless teammates are enemies
int g_teammateEnemyItemIDs[] =
{
	TF_WEAPON_GRAPPLINGHOOK,			// CTFGrapplingHook::ActivateRune
};

static PostThinkType g_postThinkType;
static bool g_isPreThinkSpoofed[MAXPLAYERS + 1];

void SDKHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (IsEntityClient(entity))
	{
		// Fixes various weapons and items in friendly fire
		PSM_SDKHook(entity, SDKHook_PreThink, SDKHookCB_Client_PreThink);
		PSM_SDKHook(entity, SDKHook_PreThinkPost, SDKHookCB_Client_PreThinkPost);
		PSM_SDKHook(entity, SDKHook_PostThink, SDKHookCB_Client_PostThink);
		PSM_SDKHook(entity, SDKHook_PostThinkPost, SDKHookCB_Client_PostThinkPost);
		PSM_SDKHook(entity, SDKHook_OnTakeDamage, SDKHookCB_Client_OnTakeDamage);
		PSM_SDKHook(entity, SDKHook_OnTakeDamagePost, SDKHookCB_Client_OnTakeDamagePost);
		
		// Makes cloaked spies fully invisible
		PSM_SDKHook(entity, SDKHook_SetTransmit, SDKHookCB_Client_SetTransmit);
	}
	else
	{
		if (!strncmp(classname, "obj_", 4))
		{
			// Makes objects solid to teammates
			PSM_SDKHook(entity, SDKHook_SpawnPost, SDKHookCB_Object_SpawnPost);
			
			// Lets teammates damage them while they are only damageable.
			// CBaseObject::TraceAttack drops the damage before OnTakeDamage ever runs, so both are needed.
			PSM_SDKHook(entity, SDKHook_TraceAttack, SDKHookCB_Object_TraceAttack);
			PSM_SDKHook(entity, SDKHook_TraceAttackPost, SDKHookCB_Object_TraceAttackPost);
			PSM_SDKHook(entity, SDKHook_OnTakeDamage, SDKHookCB_Object_OnTakeDamage);
			PSM_SDKHook(entity, SDKHook_OnTakeDamagePost, SDKHookCB_Object_OnTakeDamagePost);
		}
		
		if (!strncmp(classname, "tf_projectile_", 14))
		{
			if (StrEqual(classname, "tf_projectile_cleaver") || StrEqual(classname, "tf_projectile_pipe") || StrEqual(classname, "tf_projectile_arrow") || StrEqual(classname, "tf_projectile_energy_ring") || StrEqual(classname, "tf_projectile_balloffire"))
			{
				// Fixes these dealing no damage to teammates, they all skip anyone sharing their team
				PSM_SDKHook(entity, SDKHook_Touch, SDKHookCB_Projectile_Touch);
				PSM_SDKHook(entity, SDKHook_TouchPost, SDKHookCB_Projectile_TouchPost);
			}
			else if (StrEqual(classname, "tf_projectile_pipe_remote"))
			{
				// Allows detonating teammate's pipebombs
				PSM_SDKHook(entity, SDKHook_OnTakeDamage, SDKHookCB_ProjectilePipeRemote_OnTakeDamage);
				PSM_SDKHook(entity, SDKHook_OnTakeDamagePost, SDKHookCB_ProjectilePipeRemote_OnTakeDamagePost);
			}
		}
		else if (StrEqual(classname, "obj_dispenser") || StrEqual(classname, "pd_dispenser"))
		{
			// Prevents Dispensers from healing teammates
			PSM_SDKHook(entity, SDKHook_StartTouch, SDKHookCB_ObjectDispenser_StartTouch);
			PSM_SDKHook(entity, SDKHook_StartTouchPost, SDKHookCB_ObjectDispenser_StartTouchPost);
		}
		else if (StrEqual(classname, "tf_flame_manager"))
		{
			// Fixes Flame Throwers dealing no damage to teammates
			PSM_SDKHook(entity, SDKHook_Touch, SDKHookCB_FlameManager_Touch);
			PSM_SDKHook(entity, SDKHook_TouchPost, SDKHookCB_FlameManager_TouchPost);
		}
		else if (StrEqual(classname, "tf_gas_manager"))
		{
			// Prevents Gas Passer clouds from coating the thrower
			PSM_SDKHook(entity, SDKHook_Touch, SDKHookCB_GasManager_Touch);
		}
	}
}

// CTFPlayer::PreThink -> CTFPlayerShared::ConditionThink
static void SDKHookCB_Client_PreThink(int client)
{
	g_isPreThinkSpoofed[client] = false;

	// Disable radius buffs like the Buff Banner
	if (!AreTeammatesEnemies())
		return;

	if (!GetEntProp(client, Prop_Send, "m_bRageDraining"))
		return;

	g_isPreThinkSpoofed[client] = true;

	Entity(client).ChangeToSpectator();
}

// CTFPlayer::PreThink -> CTFPlayerShared::ConditionThink
static void SDKHookCB_Client_PreThinkPost(int client)
{
	if (!g_isPreThinkSpoofed[client])
		return;

	g_isPreThinkSpoofed[client] = false;

	Entity(client).ResetTeam();
}

// CTFWeaponBase::ItemPostFrame
static void SDKHookCB_Client_PostThink(int client)
{
	// CTFPlayer::DoTauntAttack
	if (TF2_IsPlayerInCondition(client, TFCond_Taunting))
	{
		g_postThinkType = PostThinkType_Spectator;
		
		// Allows taunt kills to work on both teams
		Entity(client).ChangeToSpectator();
		return;
	}
	
	int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (activeWeapon == -1)
		return;
	
	int weaponID = SDKCall_CTFWeaponBase_GetWeaponID(activeWeapon);
	bool teammatesAreEnemies = AreTeammatesEnemies();
	
	// For functions that use GetEnemyTeam(), move everyone else to the enemy team
	if (IsWeaponIDInList(weaponID, g_enemyItemIDs, sizeof(g_enemyItemIDs)) || (teammatesAreEnemies && IsWeaponIDInList(weaponID, g_teammateEnemyItemIDs, sizeof(g_teammateEnemyItemIDs))))
	{
		g_postThinkType = PostThinkType_EnemyTeam;

		TFTeam enemyTeam = GetEnemyTeam(TF2_GetClientTeam(client));

		for (int other = 1; other <= MaxClients; other++)
		{
			if (IsClientInGame(other) && other != client)
			{
				Entity(other).SetTeam(enemyTeam);
			}
		}

		return;
	}
	
	// For functions that do simple GetTeamNumber() checks, move ourselves to spectator team
	if (GameRules_GetRoundState() != RoundState_TeamWin || GetClientTeam(client) == GameRules_GetProp("m_iWinningTeam"))
	{
		if (IsWeaponIDInList(weaponID, g_spectatorItemIDs, sizeof(g_spectatorItemIDs)) || (teammatesAreEnemies && IsWeaponIDInList(weaponID, g_teammateSpectatorItemIDs, sizeof(g_teammateSpectatorItemIDs))))
		{
			g_postThinkType = PostThinkType_Spectator;

			Entity(client).ChangeToSpectator();
		}
	}
}

// CTFWeaponBase::ItemPostFrame
static void SDKHookCB_Client_PostThinkPost(int client)
{
	// Change everything back to how it was accordingly
	switch (g_postThinkType)
	{
		case PostThinkType_Spectator:
		{
			Entity(client).ResetTeam();
		}
		case PostThinkType_EnemyTeam:
		{
			for (int other = 1; other <= MaxClients; other++)
			{
				if (IsClientInGame(other) && other != client)
				{
					Entity(other).ResetTeam();
				}
			}
		}
	}
	
	g_postThinkType = PostThinkType_None;
}

static Action SDKHookCB_Client_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	Spoof_BeginFrame(victim);

	if (victim == attacker)
		return Plugin_Continue;

	if (GameRules_GetProp("m_bTruceActive"))
		return Plugin_Continue;

	// Falling reads the lander's own team for both the stomp and the Thermal Thruster shockwave,
	// so they keep it and everyone else moves instead
	if (damagetype & DMG_FALL)
	{
		TFTeam enemyTeam = GetEnemyTeam(TF2_GetClientTeam(victim));
		
		if (AreTeammatesEnemies())
		{
			for (int other = 1; other <= MaxClients; other++)
			{
				if (IsClientInGame(other) && other != victim)
				{
					Spoof_SetTeam(other, enemyTeam);
				}
			}
		}
		else
		{
			// Stomping is damage, but the shockwave around it is not, so only the one being landed on moves
			int ground = GetEntPropEnt(victim, Prop_Data, "m_hGroundEntity");
			if (IsEntityClient(ground))
			{
				Spoof_SetTeam(ground, enemyTeam);
			}
		}
		
		return Plugin_Continue;
	}

	// Without an attacking player there is nobody to move out of the way, so move the victim instead.
	// Mostly for boots_falling_stomp.
	Spoof_ChangeToSpectator(IsEntityClient(attacker) ? attacker : victim);
	
	return Plugin_Continue;
}

static void SDKHookCB_Client_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	Spoof_EndFrame();
}

static Action SDKHookCB_Client_SetTransmit(int entity, int client)
{
	// Teammates can always see each other's cloaked Spies unless teammates are enemies
	if (!AreTeammatesEnemies())
		return Plugin_Continue;
	
	// Don't transmit invisible spies to living players
	if (entity == client || !IsPlayerAlive(client))
		return Plugin_Continue;
	
	if (GetPercentInvisible(entity) >= 1.0)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

static Action SDKHookCB_ObjectDispenser_StartTouch(int entity, int other)
{
	if (IsEntityClient(other) && !IsObjectFriendly(entity, other))
	{
		Entity(other).ChangeToSpectator();
	}
	
	return Plugin_Continue;
}

static void SDKHookCB_ObjectDispenser_StartTouchPost(int entity, int other)
{
	if (IsEntityClient(other) && !IsObjectFriendly(entity, other))
	{
		Entity(other).ResetTeam();
	}
}

static void SDKHookCB_Object_SpawnPost(int entity)
{
	// Enable collisions for both teams, unless teammates are supposed to walk through their own buildings
	SDKHooks_SetObjectSolidToPlayers(entity, AreTeammatesEnemies());
}

// Moves an attacking teammate out of the way so a building will accept their damage
static void SpoofObjectAttacker(int victim, int attacker)
{
	if (AreTeammatesEnemies() || !IsEntityClient(attacker))
		return;

	// Buildings only take teammate damage, never damage from the one who built them
	if (GetEntPropEnt(victim, Prop_Send, "m_hBuilder") == attacker)
		return;

		return;

	if (GameRules_GetProp("m_bTruceActive"))
		return;

	if (Entity(victim).TeamCount > 0)
		return;

	Spoof_ChangeToSpectator(attacker);
}

static Action SDKHookCB_Object_TraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	Spoof_BeginFrame(victim);

	SpoofObjectAttacker(victim, attacker);

	return Plugin_Continue;
}

static void SDKHookCB_Object_TraceAttackPost(int victim, int attacker, int inflictor, float damage, int damagetype, int ammotype, int hitbox, int hitgroup)
{
	Spoof_EndFrame();
}

static Action SDKHookCB_Object_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	Spoof_BeginFrame(victim);

	SpoofObjectAttacker(victim, attacker);

	return Plugin_Continue;
}

static void SDKHookCB_Object_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	Spoof_EndFrame();
}

void SDKHooks_SetObjectSolidToPlayers(int entity, bool solid)
{
	SetVariantInt(solid ? SOLID_TO_PLAYER_YES : SOLID_TO_PLAYER_USE_DEFAULT);
	AcceptEntityInput(entity, "SetSolidToPlayer");
}

void SDKHooks_SetAllObjectsSolidToPlayers(bool solid)
{
	if (!g_isMapRunning)
		return;

	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "obj_*")) != -1)
	{
		SDKHooks_SetObjectSolidToPlayers(entity, solid);
	}
}

static Action SDKHookCB_Projectile_Touch(int entity, int other)
{
	Spoof_BeginFrame(entity);

	if (other == 0)
		return Plugin_Continue;

	int owner = FindParentOwnerEntity(entity);
	if (IsValidEntity(owner) && owner != other && !ShouldProjectileKeepTeams(entity, other, owner))
	{
		Spoof_ChangeToSpectator(owner);
		Spoof_ChangeToSpectator(entity);
	}

	return Plugin_Continue;
}

static void SDKHookCB_Projectile_TouchPost(int entity, int other)
{
	Spoof_EndFrame();
}

static Action SDKHookCB_ProjectilePipeRemote_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	Spoof_BeginFrame(victim);

	if (attacker == -1)
		return Plugin_Continue;

	// We might already be in spectate from another hook, do not allow damaging our own pipebombs
	if (FindParentOwnerEntity(victim) == attacker)
		return Plugin_Handled;

	// Allows destroying projectiles (e.g. pipebombs)
	Spoof_ChangeToSpectator(attacker);
	
	return Plugin_Continue;
}

static void SDKHookCB_ProjectilePipeRemote_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	Spoof_EndFrame();
}

static Action SDKHookCB_FlameManager_Touch(int entity, int other)
{
	Spoof_BeginFrame(entity);

	int owner = FindParentOwnerEntity(entity);
	if (IsValidEntity(owner) && owner != other)
	{
		// Fixes Flame Throwers during friendly fire
		Spoof_ChangeToSpectator(owner);
	}

	return Plugin_Continue;
}

static void SDKHookCB_FlameManager_TouchPost(int entity, int other)
{
	Spoof_EndFrame();
}

static Action SDKHookCB_GasManager_Touch(int entity, int other)
{
	if (FindParentOwnerEntity(entity) == other)
	{
		// Do not coat ourselves in our own gas
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}
