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

enum struct SDKHookData
{
	char classname[64];
	SDKHookType type;
	SDKHookCB callback;
}

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

static ArrayList g_hookData;
static StringMap g_hookParams_OnTakeDamage;
static PostThinkType g_postThinkType;

void SDKHooks_Initialize()
{
	g_hookData = new ArrayList(sizeof(SDKHookData));
	g_hookParams_OnTakeDamage = new StringMap();
	
	// Various fixes for player items
	SDKHooks_AddHook("player", SDKHook_PreThink, SDKHookCB_Client_PreThink);
	SDKHooks_AddHook("player", SDKHook_PreThinkPost, SDKHookCB_Client_PreThinkPost);
	SDKHooks_AddHook("player", SDKHook_PostThink, SDKHookCB_Client_PostThink);
	SDKHooks_AddHook("player", SDKHook_PostThinkPost, SDKHookCB_Client_PostThinkPost);
	SDKHooks_AddHook("player", SDKHook_OnTakeDamage, SDKHookCB_Client_OnTakeDamage);
	SDKHooks_AddHook("player", SDKHook_OnTakeDamagePost, SDKHookCB_Client_OnTakeDamagePost);
	SDKHooks_AddHook("player", SDKHook_SetTransmit, SDKHookCB_Client_SetTransmit);
	
	// Makes objects solid to teammates
	SDKHooks_AddHook("obj_*", SDKHook_SpawnPost, SDKHookCB_Object_SpawnPost);
	
	// Prevents Dispensers from healing teammates
	SDKHooks_AddHook("obj_dispenser", SDKHook_StartTouch, SDKHookCB_ObjectDispenser_StartTouch);
	SDKHooks_AddHook("pd_dispenser", SDKHook_StartTouchPost, SDKHookCB_ObjectDispenser_StartTouchPost);
	
	// Fixes the cleaver and pipes dealing no damage to certain entities
	SDKHooks_AddHook("tf_projectile_cleaver", SDKHook_Touch, SDKHookCB_Projectile_Touch);
	SDKHooks_AddHook("tf_projectile_cleaver", SDKHook_TouchPost, SDKHookCB_Projectile_TouchPost);
	SDKHooks_AddHook("tf_projectile_pipe", SDKHook_Touch, SDKHookCB_Projectile_Touch);
	SDKHooks_AddHook("tf_projectile_pipe", SDKHook_TouchPost, SDKHookCB_Projectile_TouchPost);
	
	// Allows detonating teammate's pipebombs
	SDKHooks_AddHook("tf_projectile_pipe_remote", SDKHook_OnTakeDamage, SDKHookCB_ProjectilePipeRemote_OnTakeDamage);
	SDKHooks_AddHook("tf_projectile_pipe_remote", SDKHook_OnTakeDamagePost, SDKHookCB_ProjectilePipeRemote_OnTakeDamagePost);
	
	// Fixes Flame Throwers dealing no damage to teammates
	SDKHooks_AddHook("tf_flame_manager", SDKHook_Touch, SDKHookCB_FlameManager_Touch);
	SDKHooks_AddHook("tf_flame_manager", SDKHook_TouchPost, SDKHookCB_FlameManager_TouchPost);
	
	// Prevents Gas Passer clouds from coating the thrower
	SDKHooks_AddHook("tf_gas_manager", SDKHook_Touch, SDKHookCB_GasManager_Touch);
}

void SDKHooks_Toggle(bool enable)
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "*")) != -1)
	{
		char classname[64];
		if (!GetEntityClassname(entity, classname, sizeof(classname)))
			continue;
		
		SDKHooks_HookEntity(entity, classname, enable);
	}
}

void SDKHooks_HookEntity(int entity, const char[] classname, bool hook)
{
	for (int i = 0; i < g_hookData.Length; i++)
	{
		SDKHookData data;
		if (!g_hookData.GetArray(i, data))
			continue;
		
		int index = StrContains(data.classname, "*");
		if (index != -1)
		{
			data.classname[index] = EOS;
		}
		
		if (index != -1 && !strncmp(classname, data.classname, index) || StrEqual(data.classname, classname))
		{
			if (hook)
			{
				SDKHook(entity, data.type, data.callback);
			}
			else
			{
				SDKUnhook(entity, data.type, data.callback);
			}
		}
	}
}

static void SDKHooks_AddHook(const char[] classname, SDKHookType type, SDKHookCB callback)
{
	SDKHookData data;
	strcopy(data.classname, sizeof(data.classname), classname);
	data.type = type;
	data.callback = callback;
	
	g_hookData.PushArray(data);
}

// CTFPlayerShared::OnPreDataChanged
static void SDKHookCB_Client_PreThink(int client)
{
	if (!IsFriendlyFireEnabled())
		return;
	
	// Disable radius buffs like Buff Banner or King Rune
	Entity(client).ChangeToSpectator();
}

// CTFPlayerShared::OnPreDataChanged
static void SDKHookCB_Client_PreThinkPost(int client)
{
	if (!IsFriendlyFireEnabled())
		return;
	
	Entity(client).ResetTeam();
}

// CTFWeaponBase::ItemPostFrame
static void SDKHookCB_Client_PostThink(int client)
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
		// Don't let losing team attack with those weapons
		if (GameRules_GetRoundState() == RoundState_TeamWin && TF2_GetClientTeam(client) != view_as<TFTeam>(GameRules_GetProp("m_iWinningTeam")))
			break;
		
		if (TF2Util_GetWeaponID(activeWeapon) == g_spectatorItemIDs[i])
		{
			g_postThinkType = PostThinkType_Spectator;
			
			SetActiveRound();
			Entity(client).ChangeToSpectator();
		}
	}
}

// CTFWeaponBase::ItemPostFrame
static void SDKHookCB_Client_PostThinkPost(int client)
{
	if (!IsFriendlyFireEnabled())
		return;
	
	// Change everything back to how it was accordingly
	switch (g_postThinkType)
	{
		case PostThinkType_Spectator:
		{
			Entity(client).ResetTeam();
			ResetActiveRound();
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
	if (!IsFriendlyFireEnabled())
		return Plugin_Continue;
	
	// Attacker and victim are commonly modified by other plugins, store them off
	g_hookParams_OnTakeDamage.SetValue("victim", victim);
	g_hookParams_OnTakeDamage.SetValue("attacker", attacker);
	
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

static void SDKHookCB_Client_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	if (!IsFriendlyFireEnabled())
		return;
	
	g_hookParams_OnTakeDamage.GetValue("victim", victim);
	g_hookParams_OnTakeDamage.GetValue("attacker", attacker);
	
	if (IsEntityClient(attacker))
	{
		Entity(attacker).ResetTeam();
	}
	else
	{
		Entity(victim).ResetTeam();
	}
}

static Action SDKHookCB_Client_SetTransmit(int entity, int client)
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

static Action SDKHookCB_ObjectDispenser_StartTouch(int entity, int other)
{
	if (!IsFriendlyFireEnabled())
		return Plugin_Continue;
	
	if (IsEntityClient(other) && !IsObjectFriendly(entity, other))
	{
		Entity(other).ChangeToSpectator();
	}
	
	return Plugin_Continue;
}

static void SDKHookCB_ObjectDispenser_StartTouchPost(int entity, int other)
{
	if (!IsFriendlyFireEnabled())
		return;
	
	if (IsEntityClient(other) && !IsObjectFriendly(entity, other))
	{
		Entity(other).ResetTeam();
	}
}

static void SDKHookCB_Object_SpawnPost(int entity)
{
	if (!IsFriendlyFireEnabled())
		return;
	
	// Enable collisions for both teams
	SetVariantInt(SOLID_TO_PLAYER_YES);
	AcceptEntityInput(entity, "SetSolidToPlayer");
}

static Action SDKHookCB_Projectile_Touch(int entity, int other)
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
	}
	
	return Plugin_Continue;
}

static void SDKHookCB_Projectile_TouchPost(int entity, int other)
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
	}
}

static Action SDKHookCB_ProjectilePipeRemote_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
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

static void SDKHookCB_ProjectilePipeRemote_OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
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

static Action SDKHookCB_FlameManager_Touch(int entity, int other)
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

static void SDKHookCB_FlameManager_TouchPost(int entity, int other)
{
	if (!IsFriendlyFireEnabled())
		return;
	
	int owner = FindParentOwnerEntity(entity);
	if (IsValidEntity(owner) && owner != other)
	{
		Entity(owner).ResetTeam();
	}
}

static Action SDKHookCB_GasManager_Touch(int entity, int other)
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
