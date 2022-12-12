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

static DynamicHook g_DHookCanCollideWithTeammates;
static DynamicHook g_DHookGetCustomDamageType;
static DynamicHook g_SecondaryAttack;
static DynamicHook g_Explode;

void DHooks_Initialize(GameData gamedata)
{
	CreateDynamicDetour(gamedata, "CBaseEntity::InSameTeam", DHook_InSameTeamPre, _);
	//CreateDynamicDetour(gamedata, "CBaseEntity::PhysicsDispatchThink", DHookCallback_PhysicsDispatchThink_Pre, DHookCallback_PhysicsDispatchThink_Post);
	
	g_DHookCanCollideWithTeammates = CreateDynamicHook(gamedata, "CBaseProjectile::CanCollideWithTeammates");
	g_DHookGetCustomDamageType = CreateDynamicHook(gamedata, "CTFSniperRifle::GetCustomDamageType");
	g_SecondaryAttack = CreateDynamicHook(gamedata, "CTFWeaponBaseGun::SecondaryAttack");
	g_Explode = CreateDynamicHook(gamedata, "CBaseGrenade::Explode");
}

void DHooks_OnClientConnected(int client)
{
	
}

void DHooks_OnEntityCreated(int entity, const char[] classname)
{
	if (strncmp(classname, "tf_projectile_", 14) == 0)
	{
		if (strncmp(classname, "tf_projectile_jar", 17) == 0)
		{
			g_Explode.HookEntity(Hook_Pre, entity, DHookCallback_Explode_Pre);
			g_Explode.HookEntity(Hook_Post, entity, DHookCallback_Explode_Post);
		}
		
		g_DHookCanCollideWithTeammates.HookEntity(Hook_Post, entity, DHookCallback_CanCollideWithTeammates_Post);
	}
	else if (strncmp(classname, "tf_weapon_sniperrifle", 21) == 0)
	{
		g_DHookGetCustomDamageType.HookEntity(Hook_Post, entity, DHookCallback_GetCustomDamageType_Post);
	}
	else if (strncmp(classname, "tf_weapon_", 10) == 0)
	{
		g_SecondaryAttack.HookEntity(Hook_Pre, entity, DHookCallback_SecondaryAttack_Pre);
		g_SecondaryAttack.HookEntity(Hook_Post, entity, DHookCallback_SecondaryAttack_Post);
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

MRESReturn DHookCallback_Explode_Pre(int entity, DHookParam params)
{
	int thrower = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (thrower != -1)
	{
		Entity(thrower).ChangeToSpectator();
	}
	// TODO GAS STILL COATS YOURSELF
	// HOOK PointManager::ShouldCollide
	Entity(entity).ChangeToSpectator();
	
	return MRES_Ignored;
}

MRESReturn DHookCallback_Explode_Post(int entity, DHookParam params)
{
	int thrower = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	if (thrower != -1)
	{
		Entity(thrower).ResetTeam();
	}
	
	Entity(entity).ResetTeam();
	
	return MRES_Ignored;
}

MRESReturn DHookCallback_CanCollideWithTeammates_Post(int entity, DHookReturn ret)
{
	// Always make projectiles collide with teammates
	ret.Value = true;
	
	return MRES_Supercede;
}

MRESReturn DHookCallback_GetCustomDamageType_Post(int entity, DHookReturn ret)
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

MRESReturn DHookCallback_SecondaryAttack_Pre(int entity)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (owner != -1)
	{
		Player(owner).ChangeToSpectator();
	}
	
	return MRES_Ignored;
}

MRESReturn DHookCallback_SecondaryAttack_Post(int entity)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (owner != -1)
	{
		Player(owner).ResetTeam();
	}
	
	return MRES_Ignored;
}

MRESReturn DHook_InSameTeamPre(int entity, DHookReturn ret, DHookParam param)
{
	if (param.IsNull(1))
	{
		ret.Value = false;
		return MRES_Supercede;
	}
	
	int other = param.Get(1);
	
	// Find the top-most owner.
	// Unless this matches us, assume everyone is an enemy!
	entity = FindParentOwnerEntity(entity);
	other = FindParentOwnerEntity(other);
	
	ret.Value = (entity == other);
	return MRES_Supercede;
}
