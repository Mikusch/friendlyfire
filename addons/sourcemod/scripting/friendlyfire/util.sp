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

TFTeam TF2_GetEntityTeam(int entity)
{
	return view_as<TFTeam>(GetEntProp(entity, Prop_Data, "m_iTeamNum"));
}

// WARNING: This is unsafe and will lead to crashes!
// Use `Entity.SetTeam` together with `Entity.ResetTeam` instead.
void TF2_SetEntityTeam(int entity, TFTeam team)
{
	SetEntProp(entity, Prop_Send, "m_iTeamNum", team);
}

bool IsEntityClient(int entity)
{
	return 0 < entity <= MaxClients;
}

// Useful to get the parent owner for entities that have a chain of owners.
// e.g. `CTFFlameManager` -> `CTFFlameThrower` -> `CTFPlayer`.
int FindParentOwnerEntity(int entity)
{
	int parent = -1;
	
	if (HasEntProp(entity, Prop_Send, "m_hThrower"))
	{
		parent = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	}
	else if (HasEntProp(entity, Prop_Send, "m_hLauncher"))
	{
		parent = GetEntPropEnt(entity, Prop_Send, "m_hLauncher");
	}
	else if (HasEntProp(entity, Prop_Send, "m_hBuilder"))
	{
		parent = GetEntPropEnt(entity, Prop_Send, "m_hBuilder");
	}
	else if (HasEntProp(entity, Prop_Send, "m_hOwner"))
	{
		parent = GetEntPropEnt(entity, Prop_Send, "m_hOwner");
	}
	else if (HasEntProp(entity, Prop_Send, "m_hOwnerEntity"))
	{
		parent = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	}
	
	if (parent != -1 && parent != entity)
	{
		return FindParentOwnerEntity(parent);
	}
	else
	{
		return entity;
	}
}

TFTeam GetEnemyTeam(TFTeam team)
{
	switch (team)
	{
		case TFTeam_Red: { return TFTeam_Blue; }
		case TFTeam_Blue: { return TFTeam_Red; }
		default: { return team; }
	}
}

// CObjectSentrygun::FindTarget maps every team that is not BLUE to RED, unlike GetEnemyTeam.
TFTeam GetSentryEnemyTeam(TFTeam team)
{
	return team == TFTeam_Blue ? TFTeam_Red : TFTeam_Blue;
}

static int GetObjectBuilder(int obj)
{
	if (!HasEntProp(obj, Prop_Send, "m_hBuilder"))
		return -1;

	return GetEntPropEnt(obj, Prop_Send, "m_hBuilder");
}

bool IsObjectFriendly(int obj, int entity)
{
	if (!IsValidEntity(obj) || !IsValidEntity(entity))
		return false;

	// The original team has to be used here, because callers of this function commonly spoof team numbers.
	if (!AreTeammatesEnemies() && Entity(obj).GetOriginalTeam() == Entity(entity).GetOriginalTeam())
		return true;

	int builder = GetObjectBuilder(obj);

	if (IsEntityClient(entity))
	{
		// Spies can use any Teleporter, see CObjectTeleporter::PlayerCanBeTeleported.
		if (TF2_GetObjectType(obj) == TFObject_Teleporter && TF2_GetPlayerClass(entity) == TFClass_Spy)
			return true;

		// Buildings treat a Spy disguised as their own team as one of their own.
		if (TF2_IsPlayerInCondition(entity, TFCond_Disguised) && view_as<TFTeam>(GetEntProp(entity, Prop_Send, "m_nDisguiseTeam")) == Entity(obj).GetOriginalTeam())
			return true;

		if (builder == entity)
			return true;
	}
	else if (HasEntProp(entity, Prop_Send, "m_hBuilder"))
	{
		if (builder != -1 && builder == GetEntPropEnt(entity, Prop_Send, "m_hBuilder"))
			return true;
	}

	return false;
}

float GetPercentInvisible(int client)
{
	int offset = FindSendPropInfo("CTFPlayer", "m_flInvisChangeCompleteTime") - 8;
	return GetEntDataFloat(client, offset);
}

bool IsEntityBaseObject(int entity)
{
	return HasEntProp(entity, Prop_Data, "CBaseObjectUpgradeThink");
}

bool IsEntityBaseCombatWeapon(int entity)
{
	return HasEntProp(entity, Prop_Data, "CBaseCombatWeaponDefaultTouch");
}

bool IsEntityBaseMelee(int entity)
{
	return HasEntProp(entity, Prop_Data, "CTFWeaponBaseMeleeSmack");
}

bool IsEntityBaseGrenadeProjectile(int entity)
{
	return HasEntProp(entity, Prop_Data, "CTFWeaponBaseGrenadeProjDetonateThink");
}

// Keyed off the classname, because CTFProjectile_Cleaver and CTFProjectile_SpellBats inherit
// TF_PROJECTILE_JAR from CTFProjectile_Jar without ever assigning their own type.
bool IsJarProjectile(int entity)
{
	char classname[64];
	if (!GetEntityClassname(entity, classname, sizeof(classname)))
		return false;

	return !strncmp(classname, "tf_projectile_jar", 17);
}

bool ShouldProjectileKeepTeams(int entity, int other, int owner)
{
	if (!IsEntityBaseObject(other))
		return false;

	// Our own buildings are not a valid target in any mode.
	if (GetEntPropEnt(other, Prop_Send, "m_hBuilder") == owner)
		return true;

	// Rescue Ranger bolts repair friendly buildings instead of damaging them.
	return SDKCall_CBaseProjectile_GetProjectileType(entity) == TF_PROJECTILE_BUILDING_REPAIR_BOLT
		&& IsObjectFriendly(other, owner);
}

bool IsWeaponIDInList(int weaponID, const int[] list, int size)
{
	for (int i = 0; i < size; i++)
	{
		if (weaponID == list[i])
			return true;
	}
	
	return false;
}

int GameConfGetOffsetOrElseThrow(GameData gamedata, const char[] key)
{
	int offset = gamedata.GetOffset(key);
	if (offset == -1)
		SetFailState("Failed to get offset: %s", key);

	return offset;
}
