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

static DynamicHook g_DHookCanCollideWithTeammates;

void DHooks_Initialize(GameData gamedata)
{
	//CreateDynamicDetour(gamedata, "CBaseEntity::PhysicsDispatchThink", DHookCallback_PhysicsDispatchThink_Pre, DHookCallback_PhysicsDispatchThink_Post);
	
	g_DHookCanCollideWithTeammates = CreateDynamicHook(gamedata, "CBaseProjectile::CanCollideWithTeammates");
}

void DHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (strncmp(classname, "tf_projectile_", 14) == 0)
	{
		g_DHookCanCollideWithTeammates.HookEntity(Hook_Post, entity, DHookCallback_CanCollideWithTeammates_Post);
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

public MRESReturn DHookCallback_PhysicsDispatchThink_Pre(int entity, DHookParam params)
{
	char classname[64];
	if (!GetEntityClassname(entity, classname, sizeof(classname)))
		return MRES_Ignored;
	
	if (strcmp(classname, "tf_projectile_rocket") == 0)
	{
		
		return MRES_Supercede;
	}
}

public MRESReturn DHookCallback_PhysicsDispatchThink_Post(int entity, DHookParam params)
{
	return MRES_Ignored;
}

public MRESReturn DHookCallback_CanCollideWithTeammates_Post(int entity, DHookReturn ret)
{
	// Always make projectiles collide with teammates
	ret.Value = true;
	return MRES_Supercede;
}
