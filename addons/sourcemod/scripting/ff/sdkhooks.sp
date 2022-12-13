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

enum PostThinkType
{
	PostThinkType_None,
	PostThinkType_Spectator,
	PostThinkType_EnemyTeam,
}

static PostThinkType g_nPostThinkType = PostThinkType_None;

void SDKHooks_OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_PreThink, SDKHookCB_PreThink);
	SDKHook(client, SDKHook_PreThinkPost, SDKHookCB_PreThinkPost);
	SDKHook(client, SDKHook_PostThink, SDKHookCB_PostThink_Pre);
	SDKHook(client, SDKHook_PostThinkPost, SDKHookCB_PostThink_Post);
	SDKHook(client, SDKHook_OnTakeDamage, SDKHookCB_OnTakeDamage_Pre);
	SDKHook(client, SDKHook_OnTakeDamagePost, SDKHookCB_OnTakeDamage_Post);
}

// CTFPlayerShared::OnPreDataChanged
void SDKHookCB_PreThink(int client)
{
	// Disable radius buffs like Buff Banner or King Rune
	Player(client).ChangeToSpectator();
}

// CTFPlayerShared::OnPreDataChanged
void SDKHookCB_PreThinkPost(int client)
{
	Player(client).ResetTeam();
}

// CTFWeaponBase::ItemPostFrame
void SDKHookCB_PostThink_Pre(int client)
{
	int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (activeWeapon == -1)
		return;
	
	int weaponID = TF2Util_GetWeaponID(activeWeapon);
	if (weaponID == TF_WEAPON_HANDGUN_SCOUT_PRIMARY)
	{
		g_nPostThinkType = PostThinkType_EnemyTeam;
		
		// For everything using GetEnemyTeam, switch all other players to the enemy team
		for (int other = 1; other <= MaxClients; other++)
		{
			if (IsClientInGame(other) && other != client)
			{
				Player(other).SetTeam(GetEnemyTeam(TF2_GetClientTeam(client)));
			}
		}
	}
	else
	{
		if (weaponID == TF_WEAPON_BUILDER)
			return;
		
		g_nPostThinkType = PostThinkType_Spectator;
		
		int building = MaxClients + 1;
		while ((building = FindEntityByClassname(building, "obj_*")) != -1)
		{
			// Move enemy buildings to a team that is NOT spectator to be able to deal damage
			if (GetEntPropEnt(building, Prop_Send, "m_hBuilder") == client)
			{
				Entity(building).ChangeToSpectator();
			}
			else
			{
				Entity(building).SetTeam(TFTeam_Red);
			}
		}
		
		// For everything else, assume it does simple team checks
		Player(client).ChangeToSpectator();
	}
}

// CTFWeaponBase::ItemPostFrame
void SDKHookCB_PostThink_Post(int client)
{
	// Change everything back to how it was accordingly
	switch (g_nPostThinkType)
	{
		case PostThinkType_Spectator:
		{
			// Reset all buildings
			int building = MaxClients + 1;
			while ((building = FindEntityByClassname(building, "obj_*")) > MaxClients)
			{
				Entity(building).ResetTeam();
			}
			
			Player(client).ResetTeam();
		}
		case PostThinkType_EnemyTeam:
		{
			for (int other = 1; other <= MaxClients; other++)
			{
				if (IsClientInGame(other) && other != client)
					Player(other).ResetTeam();
			}
		}
	}
	
	g_nPostThinkType = PostThinkType_None;
}

Action SDKHookCB_OnTakeDamage_Pre(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (IsEntityClient(attacker))
	{
		Player(attacker).ChangeToSpectator();
	}
	else
	{
		// Mostly for boots_falling_stomp
		Player(victim).ChangeToSpectator();
	}
	
	return Plugin_Continue;
}

void SDKHookCB_OnTakeDamage_Post(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	if (IsEntityClient(attacker))
	{
		Player(attacker).ResetTeam();
	}
	else
	{
		Player(victim).ResetTeam();
	}
}

void SDKHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (strncmp(classname, "tf_projectile_", 14) == 0)
	{
		SDKHook(entity, SDKHook_Touch, SDKHookCB_ProjectileTouch);
		SDKHook(entity, SDKHook_TouchPost, SDKHookCB_ProjectileTouchPost);
	}
	else if (strcmp(classname, "tf_flame_manager") == 0)
	{
		SDKHook(entity, SDKHook_Touch, SDKHookCB_FlameManagerTouch);
		SDKHook(entity, SDKHook_TouchPost, SDKHookCB_FlameManagerTouchPost);
	}
}

Action SDKHookCB_ProjectileTouch(int entity, int other)
{
	int owner = FindParentOwnerEntity(entity);
	if (IsEntityClient(owner) && owner != other)
	{
		Player(owner).ChangeToSpectator();
		Entity(entity).ChangeToSpectator();
	}
	
	return Plugin_Continue;
}

void SDKHookCB_ProjectileTouchPost(int entity, int other)
{
	int owner = FindParentOwnerEntity(entity);
	if (IsEntityClient(owner) && owner != other)
	{
		Player(owner).ResetTeam();
		Entity(entity).ResetTeam();
	}
}

Action SDKHookCB_FlameManagerTouch(int entity, int other)
{
	// Allows Flame Throwers to work on both teams
	int owner = FindParentOwnerEntity(entity);
	if (IsEntityClient(owner))
	{
		Player(owner).ChangeToSpectator();
	}
	
	return Plugin_Continue;
}

void SDKHookCB_FlameManagerTouchPost(int entity, int other)
{
	int owner = FindParentOwnerEntity(entity);
	if (IsEntityClient(owner))
	{
		Player(owner).ResetTeam();
	}
}
