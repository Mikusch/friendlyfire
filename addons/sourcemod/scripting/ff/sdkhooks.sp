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
	TF_WEAPON_BUFF_ITEM,		// CTFPlayerShared::PulseRageBuff
	TF_WEAPON_FLAMETHROWER,		// CTFFlameThrower::SecondaryAttack
	TF_WEAPON_FLAME_BALL,		// CWeaponFlameBall::SecondaryAttack
	TF_WEAPON_SNIPERRIFLE,		// CTFPlayer::FireBullet
	TF_WEAPON_KNIFE,			// CTFKnife::BackstabVMThink
	TF_WEAPON_RAYGUN_REVENGE,	// CTFFlareGun_Revenge::ExtinguishPlayerInternal
};

int g_enemyItemIDs[] =
{
	TF_WEAPON_HANDGUN_SCOUT_PRIMARY,	// CTFPistol_ScoutPrimary::Push
	TF_WEAPON_GRAPPLINGHOOK,			// CTFGrapplingHook::ActivateRune
};

static PostThinkType g_postThinkType;

void SDKHooks_OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_PreThink, SDKHookCB_Client_PreThink);
	SDKHook(client, SDKHook_PreThinkPost, SDKHookCB_Client_PreThinkPost);
	SDKHook(client, SDKHook_PostThink, SDKHookCB_Client_PostThink);
	SDKHook(client, SDKHook_PostThinkPost, SDKHookCB_Client_PostThinkPost);
	SDKHook(client, SDKHook_OnTakeDamage, SDKHookCB_Client_OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamagePost, SDKHookCB_Client_OnTakeDamagePost);
	SDKHook(client, SDKHook_SetTransmit, SDKHookCB_Client_SetTransmit);
}

void SDKHooks_OnEntityCreated(int entity, const char[] classname)
{
	// Makes objects solid to teammates
	if (strncmp(classname, "obj_", 4) == 0)
	{
		SDKHook(entity, SDKHook_SpawnPost, SDKHookCB_Object_SpawnPost);
	}
	
	// Prevents Dispensers from healing teammates
	if (StrEqual(classname, "obj_dispenser") || StrEqual(classname, "pd_dispenser"))
	{
		SDKHook(entity, SDKHook_StartTouch, SDKHookCB_ObjectDispenser_StartTouch);
		SDKHook(entity, SDKHook_StartTouchPost, SDKHookCB_ObjectDispenser_StartTouchPost);
	}
	
	// Fixes the cleaver and pipes dealing no damage to certain entities
	if (StrEqual(classname, "tf_projectile_cleaver") || StrEqual(classname, "tf_projectile_pipe"))
	{
		SDKHook(entity, SDKHook_Touch, SDKHookCB_Projectile_Touch);
		SDKHook(entity, SDKHook_TouchPost, SDKHookCB_Projectile_TouchPost);
	}
	
	// Allows detonating teammate's pipebombs
	if (StrEqual(classname, "tf_projectile_pipe_remote"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, SDKHookCB_ProjectilePipeRemote_OnTakeDamage);
		SDKHook(entity, SDKHook_OnTakeDamagePost, SDKHookCB_ProjectilePipeRemote_OnTakeDamagePost);
	}
	
	// Fixes Flame Throwers dealing no damage to teammates
	if (StrEqual(classname, "tf_flame_manager"))
	{
		SDKHook(entity, SDKHook_Touch, SDKHookCB_FlameManager_Touch);
		SDKHook(entity, SDKHook_TouchPost, SDKHookCB_FlameManager_TouchPost);
	}
	
	// Prevents Gas Passer clouds from coating the thrower
	if (StrEqual(classname, "tf_gas_manager"))
	{
		SDKHook(entity, SDKHook_Touch, SDKHookCB_GasManager_Touch);
	}
}

// CTFPlayerShared::OnPreDataChanged
void SDKHookCB_Client_PreThink(int client)
{
	if (!IsFriendlyFireEnabled())
		return;
	
	// Disable radius buffs like Buff Banner or King Rune
	Entity(client).ChangeToSpectator();
}

// CTFPlayerShared::OnPreDataChanged
void SDKHookCB_Client_PreThinkPost(int client)
{
	if (!IsFriendlyFireEnabled())
		return;
	
	Entity(client).ResetTeam();
}

// CTFWeaponBase::ItemPostFrame
void SDKHookCB_Client_PostThink(int client)
{
	if (!IsFriendlyFireEnabled())
		return;
	
	// CTFPlayer::DoTauntAttack
	if (TF2_IsPlayerInCondition(client, TFCond_Taunting))
	{
		g_postThinkType = PostThinkType_Spectator;
		
		// Allows taunt kill work on both teams
		Entity(client).ChangeToSpectator();
		return;
	}
	
	int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (activeWeapon == -1)
		return;
	
	// For functions that use GetEnemyTeam(), move everyone else to the enemy team
	for (int i = 0; i < sizeof(g_enemyItemIDs); i++)
	{
		if (TF2Util_GetWeaponID(activeWeapon) == g_enemyItemIDs[i])
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
void SDKHookCB_Client_PostThinkPost(int client)
{
	if (!IsFriendlyFireEnabled())
		return;
	
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

Action SDKHookCB_Client_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!IsFriendlyFireEnabled())
		return Plugin_Continue;
	
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

void SDKHookCB_Client_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	if (!IsFriendlyFireEnabled())
		return;
	
	if (IsEntityClient(attacker))
	{
		Entity(attacker).ResetTeam();
	}
	else
	{
		Entity(victim).ResetTeam();
	}
}

Action SDKHookCB_Client_SetTransmit(int entity, int client)
{
	if (!IsFriendlyFireEnabled())
		return Plugin_Continue;
	
	// Don't transmit invisible spies to living players
	if (entity == client || !IsPlayerAlive(client))
		return Plugin_Continue;
	
	if (GetPercentInvisible(entity) >= 1.0)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

Action SDKHookCB_ObjectDispenser_StartTouch(int entity, int other)
{
	if (!IsFriendlyFireEnabled())
		return Plugin_Continue;
	
	if (IsEntityClient(other) && !IsObjectFriendly(entity, other))
	{
		Entity(other).ChangeToSpectator();
	}
	
	return Plugin_Continue;
}

void SDKHookCB_ObjectDispenser_StartTouchPost(int entity, int other)
{
	if (!IsFriendlyFireEnabled())
		return;
	
	if (IsEntityClient(other) && !IsObjectFriendly(entity, other))
	{
		Entity(other).ResetTeam();
	}
}

void SDKHookCB_Object_SpawnPost(int entity)
{
	if (!IsFriendlyFireEnabled())
		return;
	
	// Enable collisions for both teams
	SetVariantInt(SOLID_TO_PLAYER_YES);
	AcceptEntityInput(entity, "SetSolidToPlayer");
}

Action SDKHookCB_Projectile_Touch(int entity, int other)
{
	if (!IsFriendlyFireEnabled())
		return Plugin_Continue;
	
	if (other == 0)
		return Plugin_Continue;
	
	int owner = FindParentOwnerEntity(entity);
	if (IsValidEntity(owner) && owner != other)
	{
		Entity(owner).ChangeToSpectator();
		Entity(entity).ChangeToSpectator();
		
		// Rescue Ranger healing bolts require buildings to be on the same team as them
		if (IsBaseObject(other) && IsObjectFriendly(other, owner))
		{
			Entity(other).ChangeToSpectator();
		}
	}
	
	return Plugin_Continue;
}

void SDKHookCB_Projectile_TouchPost(int entity, int other)
{
	if (!IsFriendlyFireEnabled())
		return;
	
	if (other == 0)
		return;
	
	int owner = FindParentOwnerEntity(entity);
	if (IsValidEntity(owner) && owner != other)
	{
		Entity(owner).ResetTeam();
		Entity(entity).ResetTeam();
		
		if (IsBaseObject(other) && IsObjectFriendly(other, owner))
		{
			Entity(other).ResetTeam();
		}
	}
}

Action SDKHookCB_ProjectilePipeRemote_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!IsFriendlyFireEnabled())
		return Plugin_Continue;
	
	if (attacker != -1)
	{
		// We might already be in spectate from another hook, do not allow damaging our own pipebombs
		if (FindParentOwnerEntity(victim) == attacker)
			return Plugin_Handled;
		
		// Allows destroying projectiles (e.g. pipebombs)
		Entity(attacker).ChangeToSpectator();
	}
	
	return Plugin_Continue;
}

void SDKHookCB_ProjectilePipeRemote_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	if (!IsFriendlyFireEnabled())
		return;
	
	if (attacker != -1)
	{
		if (FindParentOwnerEntity(victim) == attacker)
			return;
		
		Entity(attacker).ResetTeam();
	}
}

Action SDKHookCB_FlameManager_Touch(int entity, int other)
{
	if (!IsFriendlyFireEnabled())
		return Plugin_Continue;
	
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
	if (!IsFriendlyFireEnabled())
		return;
	
	int owner = FindParentOwnerEntity(entity);
	if (IsValidEntity(owner) && owner != other)
	{
		Entity(owner).ResetTeam();
	}
}

Action SDKHookCB_GasManager_Touch(int entity, int other)
{
	if (!IsFriendlyFireEnabled())
		return Plugin_Continue;
	
	if (FindParentOwnerEntity(entity) == other)
	{
		// Do not coat ourselves in our own gas
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}
