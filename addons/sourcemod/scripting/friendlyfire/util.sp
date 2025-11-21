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

bool IsObjectFriendly(int obj, int entity)
{
	if (IsValidEntity(entity))
	{
		if (IsEntityClient(entity))
		{
			if (!sm_friendlyfire_teammates_are_enemies.BoolValue && TF2_GetEntityTeam(obj) == TF2_GetClientTeam(entity))
				return true;

			if (GetEntPropEnt(obj, Prop_Send, "m_hBuilder") == GetEntPropEnt(entity, Prop_Send, "m_hDisguiseTarget"))
				return true;
			else if (GetEntPropEnt(obj, Prop_Send, "m_hBuilder") == entity)	// obj_dispenser
				return true;
			else if (GetEntPropEnt(obj, Prop_Data, "m_hParent") == entity)	// pd_dispenser
				return true;
		}
		else if (HasEntProp(entity, Prop_Send, "m_hBuilder"))
		{
			if (!sm_friendlyfire_teammates_are_enemies.BoolValue && TF2_GetEntityTeam(obj) == TF2_GetEntityTeam(entity))
				return true;

			if (GetEntPropEnt(obj, Prop_Send, "m_hBuilder") == GetEntPropEnt(entity, Prop_Send, "m_hBuilder"))
				return true;
		}
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

bool IsEntityBaseMelee(int entity)
{
	return HasEntProp(entity, Prop_Data, "CTFWeaponBaseMeleeSmack");
}

bool IsEntityBaseGrenadeProjectile(int entity)
{
	return HasEntProp(entity, Prop_Data, "CTFWeaponBaseGrenadeProjDetonateThink");
}

int GameConfGetOffsetOrElseThrow(GameData gamedata, const char[] key)
{
	int offset = gamedata.GetOffset(key);
	if (offset == -1)
		SetFailState("Failed to get offset: %s", key);

	return offset;
}
