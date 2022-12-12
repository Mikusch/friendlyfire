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

void SDKHooks_OnClientConnected(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, SDKHookCB_OnTakeDamage_Pre);
	SDKHook(client, SDKHook_OnTakeDamagePost, SDKHookCB_OnTakeDamage_Post);
}

Action SDKHookCB_OnTakeDamage_Pre(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (IsEntityClient(attacker))
	{
		Player(attacker).ChangeToSpectator();
	}
	
	return Plugin_Continue;
}

void SDKHookCB_OnTakeDamage_Post(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	if (IsEntityClient(attacker))
	{
		Player(attacker).ResetTeam();
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
