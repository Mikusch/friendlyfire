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

static ArrayList g_EntityProperties;

enum struct EntityProperties
{
	int ref;
	int team_count;
	TFTeam team[8];
	
	void Initialize(int ref)
	{
		this.ref = ref;
		this.team_count = 0;
	}
}

methodmap Entity
{
	public Entity(int entity)
	{
		return view_as<Entity>(entity);
	}
	
	property int _ref
	{
		public get()
		{
			// Doubly convert it to ensure it is an entity reference
			return EntIndexToEntRef(EntRefToEntIndex(view_as<int>(this)));
		}
	}
	
	property int _listIndex
	{
		public get()
		{
			return g_EntityProperties.FindValue(this._ref, EntityProperties::ref);
		}
	}
	
	property int TeamCount
	{
		public get()
		{
			if (this._listIndex != -1)
				return g_EntityProperties.Get(this._listIndex, EntityProperties::team_count);
			
			return -1;
		}
		public set(int count)
		{
			if (this._listIndex != -1)
				g_EntityProperties.Set(this._listIndex, count, EntityProperties::team_count);
		}
	}
	
	public TFTeam GetTeamInternal(int index)
	{
		// ArrayList.GetArray has no block parameter so we iterate everything
		for (int i = 0; i < sizeof(g_EntityProperties); i++)
		{
			EntityProperties properties;
			if (g_EntityProperties.GetArray(this._listIndex, properties) > 0)
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
		for (int i = 0; i < sizeof(g_EntityProperties); i++)
		{
			EntityProperties properties;
			if (g_EntityProperties.GetArray(this._listIndex, properties) > 0)
			{
				properties.team[index] = team;
				g_EntityProperties.SetArray(this._listIndex, properties);
				return;
			}
		}
		
		LogError("Failed to set team number");
	}
	
	public void SetTeam(TFTeam team)
	{
		int index = this.TeamCount++;
		this.SetTeamInternal(TF2_GetTeam(this._ref), index);
		TF2_SetTeam(this._ref, team);
	}
	
	public void ChangeToSpectator()
	{
		this.SetTeam(TFTeam_Spectator);
	}
	
	public void ResetTeam()
	{
		int index = --this.TeamCount;
		TFTeam team = this.GetTeamInternal(index);
		TF2_SetTeam(this._ref, team);
	}
	
	public void Destroy()
	{
		if (this._listIndex != -1)
			g_EntityProperties.Erase(this._listIndex);
	}
	
	public static bool Create(int entity)
	{
		if (!IsValidEntity(entity))
			return false;
		
		int ref = Entity(entity)._ref;
		
		if (g_EntityProperties.FindValue(ref, EntityProperties::ref) == -1)
		{
			EntityProperties properties;
			properties.Initialize(ref);
			
			g_EntityProperties.PushArray(properties);
		}
		
		return true;
	}
	
	public static void InitializePropertyList()
	{
		g_EntityProperties = new ArrayList(sizeof(EntityProperties));
	}
}
