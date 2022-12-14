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
	TF_WEAPON_BUFF_ITEM,	// CTFPlayerShared::PulseRageBuff
	TF_WEAPON_FLAMETHROWER,	// CBaseCombatWeapon::SecondaryAttack
	TF_WEAPON_FLAME_BALL,	// CWeaponFlameBall::SecondaryAttack
	TF_WEAPON_SNIPERRIFLE,	// CTFPlayer::FireBullet
	TF_WEAPON_KNIFE,		// CTFKnife::PrimaryAttack
	TF_WEAPON_STICKBOMB,	// CTFStickBomb::Smack
};

int g_enemyItemIDs[] =
{
	TF_WEAPON_HANDGUN_SCOUT_PRIMARY,	// CTFPistol_ScoutPrimary::Push
	TF_WEAPON_BAT,						// CTFWeaponBaseMelee::PrimaryAttack
	TF_WEAPON_GRAPPLINGHOOK,			// CTFGrapplingHook::ActivateRune
};

static bool g_inMeleePostThink;
static PostThinkType g_postThinkType;

void SDKHooks_OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_PreThink, SDKHookCB_PreThink);
	SDKHook(client, SDKHook_PreThinkPost, SDKHookCB_PreThinkPost);
	SDKHook(client, SDKHook_PostThink, SDKHookCB_PostThink);
	SDKHook(client, SDKHook_PostThinkPost, SDKHookCB_PostThinkPost);
	SDKHook(client, SDKHook_OnTakeDamage, SDKHookCB_OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamagePost, SDKHookCB_OnTakeDamagePost);
	SDKHook(client, SDKHook_SetTransmit, SDKHookCB_SetTransmit);
}

void SDKHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "obj_dispenser") || StrEqual(classname, "pd_dispenser"))
	{
		SDKHook(entity, SDKHook_StartTouch, SDKHookCB_Dispenser_StartTouch);
		SDKHook(entity, SDKHook_StartTouchPost, SDKHookCB_Dispenser_StartTouchPost);
	}
	if (strncmp(classname, "obj_", 4) == 0)
	{
		SDKHook(entity, SDKHook_SpawnPost, SDKHookCB_Object_SpawnPost);
		SDKHook(entity, SDKHook_OnTakeDamage, SDKHookCB_Object_OnTakeDamage);
	}
	if (strncmp(classname, "tf_projectile_", 14) == 0)
	{
		SDKHook(entity, SDKHook_Touch, SDKHookCB_Projectile_Touch);
		SDKHook(entity, SDKHook_TouchPost, SDKHookCB_Projectile_TouchPost);
	}
	else if (StrEqual(classname, "tf_flame_manager"))
	{
		SDKHook(entity, SDKHook_Touch, SDKHookCB_FlameManager_Touch);
		SDKHook(entity, SDKHook_TouchPost, SDKHookCB_FlameManager_TouchPost);
	}
	else if (StrEqual(classname, "tf_gas_manager"))
	{
		SDKHook(entity, SDKHook_Touch, SDKHookCB_GasManager_Touch);
	}
}

// CTFPlayerShared::OnPreDataChanged
void SDKHookCB_PreThink(int client)
{
	// Disable radius buffs like Buff Banner or King Rune
	Entity(client).ChangeToSpectator();
}

// CTFPlayerShared::OnPreDataChanged
void SDKHookCB_PreThinkPost(int client)
{
	Entity(client).ResetTeam();
}

// CTFWeaponBase::ItemPostFrame
void SDKHookCB_PostThink(int client)
{
	int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (activeWeapon == -1)
		return;
	
	// CTFWeaponBaseMelee::Smack
	if (TF2Util_GetWeaponSlot(activeWeapon) == TFWeaponSlot_Melee)
	{
		g_inMeleePostThink = true;
		
		int building = -1;
		while ((building = FindEntityByClassname(building, "obj_*")) != -1)
		{
			if (GetEntPropEnt(building, Prop_Send, "m_hBuilder") != client)
			{
				// Move all enemy buildings to spectator to allow them to take damage from us
				Entity(building).ChangeToSpectator();
			}
		}
	}
	
	// For functions that use GetEnemyTeam(), move everyone else to the enemy team
	for (int i = 0; i < sizeof(g_enemyItemIDs); i++)
	{
		if (TF2Util_GetWeaponID(activeWeapon) == g_enemyItemIDs[i])
		{
			g_postThinkType = PostThinkType_EnemyTeam;
			
			for (int other = 1; other <= MaxClients; other++)
			{
				if (IsClientInGame(other) && other != client)
				{
					Entity(other).SetTeam(GetEnemyTeam(TF2_GetClientTeam(client)));
				}
			}
		}
	}
	
	// For functions that do simple GetTeamNumber() checks, move ourselves to spectator team
	for (int i = 0; i < sizeof(g_spectatorItemIDs); i++)
	{
		if (TF2Util_GetWeaponID(activeWeapon) == g_spectatorItemIDs[i])
		{
			g_postThinkType = PostThinkType_Spectator;
			
			Entity(client).ChangeToSpectator();
		}
	}
}

// CTFWeaponBase::ItemPostFrame
void SDKHookCB_PostThinkPost(int client)
{
	if (g_inMeleePostThink)
	{
		g_inMeleePostThink = false;
		
		// Reset all buildings
		int building = -1;
		while ((building = FindEntityByClassname(building, "obj_*")) != -1)
		{
			if (GetEntPropEnt(building, Prop_Send, "m_hBuilder") != client)
			{
				Entity(building).ResetTeam();
			}
		}
	}
	
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

Action SDKHookCB_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (IsEntityClient(attacker))
	{
		Entity(attacker).ChangeToSpectator();
	}
	else
	{
		// Mostly for boots_falling_stomp
		Entity(victim).ChangeToSpectator();
	}
	
	return Plugin_Continue;
}

void SDKHookCB_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	if (IsEntityClient(attacker))
	{
		Entity(attacker).ResetTeam();
	}
	else
	{
		Entity(victim).ResetTeam();
	}
}

Action SDKHookCB_SetTransmit(int entity, int client)
{
	// Don't transmit invisible spies to living players
	if (entity == client || !IsPlayerAlive(client))
		return Plugin_Continue;
	
	if (TF2_GetPercentInvisible(entity) >= 1.0)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

Action SDKHookCB_Dispenser_StartTouch(int entity, int other)
{
	if (IsEntityClient(other) && !TF2_IsObjectFriendly(entity, other))
	{
		Entity(other).ChangeToSpectator();
	}
	
	return Plugin_Continue;
}

void SDKHookCB_Dispenser_StartTouchPost(int entity, int other)
{
	if (IsEntityClient(other) && !TF2_IsObjectFriendly(entity, other))
	{
		Entity(other).ResetTeam();
	}
}

void SDKHookCB_Object_SpawnPost(int entity)
{
	// Enable collisions for both teams
	SetEntityCollisionGroup(entity, TFCOLLISION_GROUP_OBJECT_SOLIDTOPLAYERMOVEMENT);
}

Action SDKHookCB_Object_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	// Don't allow buildings to take damage from friendly players
	if (TF2_IsObjectFriendly(victim, attacker))
		return Plugin_Stop;
	
	return Plugin_Continue;
}

Action SDKHookCB_Projectile_Touch(int entity, int other)
{
	int owner = FindParentOwnerEntity(entity);
	if (IsValidEntity(owner) && owner != other)
	{
		Entity(owner).ChangeToSpectator();
		Entity(entity).ChangeToSpectator();
	}
	
	return Plugin_Continue;
}

void SDKHookCB_Projectile_TouchPost(int entity, int other)
{
	int owner = FindParentOwnerEntity(entity);
	if (IsValidEntity(owner) && owner != other)
	{
		Entity(owner).ResetTeam();
		Entity(entity).ResetTeam();
	}
}

Action SDKHookCB_FlameManager_Touch(int entity, int other)
{
	int owner = FindParentOwnerEntity(entity);
	if (IsValidEntity(owner) && owner != other)
	{
		// Fixes Flame Throwers during friendly fire
		Entity(owner).ChangeToSpectator();
	}
	
	return Plugin_Continue;
}

void SDKHookCB_FlameManager_TouchPost(int entity, int other)
{
	int owner = FindParentOwnerEntity(entity);
	if (IsValidEntity(owner) && owner != other)
	{
		Entity(owner).ResetTeam();
	}
}

Action SDKHookCB_GasManager_Touch(int entity, int other)
{
	if (FindParentOwnerEntity(entity) == other)
	{
		// Do not coat ourselves in our own gas
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}
