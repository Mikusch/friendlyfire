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

bool IsEntityClient(int entity)
{
	return 0 < entity <= MaxClients;
}

TFTeam TF2_GetTeam(int entity)
{
	return view_as<TFTeam>(GetEntProp(entity, Prop_Data, "m_iTeamNum"));
}

void TF2_SetTeam(int entity, TFTeam team)
{
	SetEntProp(entity, Prop_Send, "m_iTeamNum", team);
}

// Useful to get the parent owner for entities that have a chain of owners
// e.g. CTFFlameManager -> CTFFlameThrower -> CTFPlayer
int FindParentOwnerEntity(int entity)
{
	if (HasEntProp(entity, Prop_Send, "m_hThrower"))
	{
		// m_hThrower is usually the last in line
		return GetEntPropEnt(entity, Prop_Send, "m_hThrower");
	}
	else if (HasEntProp(entity, Prop_Send, "m_hOwnerEntity"))
	{
		// Loops through owner entities until it finds the most specific one
		int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if (owner != -1 && owner != entity)
		{
			return FindParentOwnerEntity(owner);
		}
	}
	
	return entity;
}
