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

stock bool IsEntityClient(int entity)
{
	return 0 < entity <= MaxClients;
}

stock TFTeam TF2_GetTeam(int entity)
{
	return view_as<TFTeam>(GetEntProp(entity, Prop_Send, "m_iTeamNum"));
}

stock void TF2_SetTeam(int entity, TFTeam team)
{
	if (IsEntityClient(entity))
		LogError("Setting m_iTeam on players leads to crashes, use TF2_ChangeClientTeamAlive instead");
	
	SetEntProp(entity, Prop_Send, "m_iTeamNum", team);
}

stock int FindOwnerEntity(int entity)
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
		if (owner > 0 && owner != entity)
			return FindOwnerEntity(owner);
	}
	
	return entity;
}

void TF2_ChangeClientTeamAlive(int client, TFTeam team)
{
	// Change team without suiciding
	SetEntProp(client, Prop_Send, "m_lifeState", LIFE_DEAD);
	TF2_ChangeClientTeam(client, team);
	SetEntProp(client, Prop_Send, "m_lifeState", LIFE_ALIVE);
}
