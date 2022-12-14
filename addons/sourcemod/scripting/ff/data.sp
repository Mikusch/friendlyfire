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

static ArrayList g_entityProperties;

/**
 * Property storage struct for Entity.
 */
enum struct EntityProperties
{
	int m_index;
	int m_teamCount;
	TFTeam m_preHookTeam;
	TFTeam m_teamHistory[8];
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
		
		// Convert it twice to ensure we store it as an entity reference
		entity = EntIndexToEntRef(EntRefToEntIndex(entity));
		
		if (g_entityProperties.FindValue(entity, EntityProperties::m_index) == -1)
		{
			// Fill basic properties
			EntityProperties properties;
			properties.m_index = entity;
			
			g_entityProperties.PushArray(properties);
		}
		
		return view_as<Entity>(entity);
	}
	
	property int ref
	{
		public get()
		{
			return view_as<int>(this);
		}
	}
	
	property int _listIndex
	{
		public get()
		{
			return g_entityProperties.FindValue(view_as<int>(this), EntityProperties::m_index);
		}
	}
	
	property int m_teamCount
	{
		public get()
		{
			return g_entityProperties.Get(this._listIndex, EntityProperties::m_teamCount);
		}
		public set(int count)
		{
			g_entityProperties.Set(this._listIndex, count, EntityProperties::m_teamCount);
		}
	}
	
	property TFTeam m_preHookTeam
	{
		public get()
		{
			return g_entityProperties.Get(this._listIndex, EntityProperties::m_preHookTeam);
		}
		public set(TFTeam team)
		{
			g_entityProperties.Set(this._listIndex, team, EntityProperties::m_preHookTeam);
		}
	}
	
	public void SetTeam(TFTeam team)
	{
		int index = this.m_teamCount++;
		this.SetTeamInternal(TF2_GetTeam(this.ref), index);
		TF2_SetTeam(this.ref, team);
	}
	
	public void ChangeToSpectator()
	{
		this.SetTeam(TFTeam_Spectator);
	}
	
	// Creates a history entry regardless of whether we already are in our original team or not
	public void ChangeToOriginalTeam()
	{
		if (this.m_teamCount > 0)
		{
			this.SetTeam(this.GetTeamInternal(0));
		}
		else
		{
			this.SetTeam(TF2_GetTeam(this.ref));
		}
	}
	
	public void ResetTeam()
	{
		int index = --this.m_teamCount;
		TFTeam team = this.GetTeamInternal(index);
		TF2_SetTeam(this.ref, team);
	}
	
	public TFTeam GetTeamInternal(int index)
	{
		for (int i = 0; i < sizeof(g_entityProperties); i++)
		{
			EntityProperties properties;
			if (g_entityProperties.GetArray(this._listIndex, properties))
			{
				return properties.m_teamHistory[index];
			}
		}
		
		LogError("Failed to get team number for entity %d (index %d)", this, index);
		return TFTeam_Unassigned;
	}
	
	public void SetTeamInternal(TFTeam team, int index)
	{
		for (int i = 0; i < sizeof(g_entityProperties); i++)
		{
			EntityProperties properties;
			if (g_entityProperties.GetArray(this._listIndex, properties) > 0)
			{
				properties.m_teamHistory[index] = team;
				g_entityProperties.SetArray(this._listIndex, properties);
				return;
			}
		}
		
		LogError("Failed to set team number for entity %d (index %d)", this, index);
	}
	
	public void Destroy()
	{
		if (this._listIndex == -1)
			return;
		
		// Remove the entry from local storage
		g_entityProperties.Erase(this._listIndex);
	}
}
