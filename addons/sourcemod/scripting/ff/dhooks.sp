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
static DynamicHook g_DHookWantsLagCompensationOnEntity;
static DynamicHook g_DHookGetCustomDamageType;

void DHooks_Initialize(GameData gamedata)
{
	//CreateDynamicDetour(gamedata, "CBaseEntity::PhysicsDispatchThink", DHookCallback_PhysicsDispatchThink_Pre, DHookCallback_PhysicsDispatchThink_Post);
	
	g_DHookCanCollideWithTeammates = CreateDynamicHook(gamedata, "CBaseProjectile::CanCollideWithTeammates");
	g_DHookWantsLagCompensationOnEntity = CreateDynamicHook(gamedata, "CBasePlayer::WantsLagCompensationOnEntity");
	g_DHookGetCustomDamageType = CreateDynamicHook(gamedata, "CTFSniperRifle::GetCustomDamageType");
}

void DHooks_OnClientConnected(int client)
{
	g_DHookWantsLagCompensationOnEntity.HookEntity(Hook_Pre, client, DHookCallback_WantsLagCompensationOnEntity_Pre);
	g_DHookWantsLagCompensationOnEntity.HookEntity(Hook_Post, client, DHookCallback_WantsLagCompensationOnEntity_Post);
}

void DHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (strncmp(classname, "tf_projectile_", 14) == 0)
	{
		g_DHookCanCollideWithTeammates.HookEntity(Hook_Post, entity, DHookCallback_CanCollideWithTeammates_Post);
	}
	else if (strncmp(classname, "tf_weapon_sniperrifle", 21) == 0)
	{
		g_DHookGetCustomDamageType.HookEntity(Hook_Post, entity, DHookCallback_GetCustomDamageType_Post);
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

public MRESReturn DHookCallback_WantsLagCompensationOnEntity_Pre(int player, DHookReturn ret, DHookParam params)
{
	// Enables lag compensation on teammates
	Player(player).SetTeam(TFTeam_Spectator);
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_WantsLagCompensationOnEntity_Post(int player, DHookReturn ret, DHookParam params)
{
	Player(player).ResetTeam();
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_GetCustomDamageType_Post(int entity, DHookReturn ret)
{
	// Allows Sniper Rifles to hit teammates, without breaking Machina penetration
	// https://github.com/Mentrillum/Slender-Fortress-Modified-Versions/blob/7c162f2a82eb1d1058c56fb23faf1be942b965d0/addons/sourcemod/scripting/sf2/pvp.sp#L982-L995
	int penetrateType = SDKCall_GetPenetrateType(entity);
	if (penetrateType == TF_DMG_CUSTOM_NONE)
	{
		ret.Value = TF_DMG_CUSTOM_NONE;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}
