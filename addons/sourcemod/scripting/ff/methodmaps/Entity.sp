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

static ArrayList g_entityProperties;

enum struct EntityProperties
{
	int m_index;
	
	int team_count;
	TFTeam m_preHookTeam;
	TFTeam team[8];
	
	void Init(int entity)
	{
		this.m_index = entity;
		this.team_count = 0;
	}
	
	void Destroy()
	{
		// nothing yet!
	}
}

methodmap Entity
{
	public Entity(int entity)
	{
		if (!IsValidEntity(entity))
		{
			return view_as<Entity>(INVALID_ENT_REFERENCE);
		}
		
		if (!g_entityProperties)
		{
			g_entityProperties = new ArrayList(sizeof(EntityProperties));
		}
		
		// doubly convert it to ensure we store it as an entity reference
		entity = EntIndexToEntRef(EntRefToEntIndex(entity));
		
		if (g_entityProperties.FindValue(entity, EntityProperties::m_index) == -1)
		{
			// fill basic properties
			EntityProperties properties;
			properties.Init(entity);
			
			g_entityProperties.PushArray(properties);
		}
		
		return view_as<Entity>(entity);
	}
	
	property int m_index
	{
		public get()
		{
			return view_as<int>(this);
		}
	}
	
	property int m_listIndex
	{
		public get()
		{
			return g_entityProperties.FindValue(view_as<int>(this), EntityProperties::m_index);
		}
	}
	
	property int m_iTeamCount
	{
		public get()
		{
			return g_entityProperties.Get(this.m_listIndex, EntityProperties::team_count);
		}
		public set(int count)
		{
			g_entityProperties.Set(this.m_listIndex, count, EntityProperties::team_count);
		}
	}
	
	property TFTeam m_preHookTeam
	{
		public get()
		{
			return g_entityProperties.Get(this.m_listIndex, EntityProperties::m_preHookTeam);
		}
		public set(TFTeam team)
		{
			g_entityProperties.Set(this.m_listIndex, team, EntityProperties::m_preHookTeam);
		}
	}
	
	public TFTeam GetTeamInternal(int index)
	{
		// ArrayList.GetArray has no block parameter so we iterate everything
		for (int i = 0; i < sizeof(g_entityProperties); i++)
		{
			EntityProperties properties;
			if (g_entityProperties.GetArray(this.m_listIndex, properties))
			{
				return properties.team[index];
			}
		}
		
		LogError("Failed to get team number");
		return TFTeam_Unassigned;
	}
	
	public void SetTeamInternal(TFTeam team, int index)
	{
		// ArrayList.GetArray has no block parameter so we iterate everything
		for (int i = 0; i < sizeof(g_entityProperties); i++)
		{
			EntityProperties properties;
			if (g_entityProperties.GetArray(this.m_listIndex, properties) > 0)
			{
				properties.team[index] = team;
				g_entityProperties.SetArray(this.m_listIndex, properties);
				return;
			}
		}
		
		LogError("Failed to set team number");
	}
	
	public void SetTeam(TFTeam team)
	{
		int index = this.m_iTeamCount++;
		this.SetTeamInternal(TF2_GetTeam(this.m_index), index);
		TF2_SetTeam(this.m_index, team);
	}
	
	public void ChangeToSpectator()
	{
		this.SetTeam(TFTeam_Spectator);
	}
	
	public void ResetTeam()
	{
		int index = --this.m_iTeamCount;
		TFTeam team = this.GetTeamInternal(index);
		TF2_SetTeam(this.m_index, team);
	}
	
	public void Destroy()
	{
		if (this.m_listIndex == -1)
			return;
		
		EntityProperties properties;
		if (g_entityProperties.GetArray(this.m_listIndex, properties))
		{
			// properly dispose of contained handles
			properties.Destroy();
		}
		
		// finally, remove the entry from local storage
		g_entityProperties.Erase(this.m_listIndex);
	}
}
