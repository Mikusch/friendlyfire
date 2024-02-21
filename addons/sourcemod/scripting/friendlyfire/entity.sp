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

#define MAX_HISTORY_ENTRIES		8

static ArrayList g_entityProperties;

/**
 * Property storage struct for Entity.
 */
enum struct EntityProperties
{
	int ref;
	
	int teamCount;
	TFTeam teamHistory[MAX_HISTORY_ENTRIES];
	
	TFTeam preHookTeam;
	TFTeam preHookDisguiseTeam;
}

methodmap Entity
{
	public Entity(int entity)
	{
		if (!IsValidEntity(entity))
		{
			return view_as<Entity>(INVALID_ENT_REFERENCE);
		}
		
		int ref = IsValidEdict(entity) ? EntIndexToEntRef(entity) : entity;
		
		if (!Entity.IsReferenceTracked(ref))
		{
			EntityProperties properties;
			properties.ref = ref;
			
			g_entityProperties.PushArray(properties);
		}
		
		return view_as<Entity>(ref);
	}
	
	property int Ref
	{
		public get()
		{
			return view_as<int>(this);
		}
	}
	
	property int ListIndex
	{
		public get()
		{
			return g_entityProperties.FindValue(this.Ref, EntityProperties::ref);
		}
	}
	
	property int TeamCount
	{
		public get()
		{
			return g_entityProperties.Get(this.ListIndex, EntityProperties::teamCount);
		}
		public set(int count)
		{
			g_entityProperties.Set(this.ListIndex, count, EntityProperties::teamCount);
		}
	}
	
	property TFTeam PreHookTeam
	{
		public get()
		{
			return g_entityProperties.Get(this.ListIndex, EntityProperties::preHookTeam);
		}
		public set(TFTeam team)
		{
			g_entityProperties.Set(this.ListIndex, team, EntityProperties::preHookTeam);
		}
	}
	
	property TFTeam PreHookDisguiseTeam
	{
		public get()
		{
			return g_entityProperties.Get(this.ListIndex, EntityProperties::preHookDisguiseTeam);
		}
		public set(TFTeam team)
		{
			g_entityProperties.Set(this.ListIndex, team, EntityProperties::preHookDisguiseTeam);
		}
	}
	
	public void SetTeam(TFTeam team)
	{
		int index = this.TeamCount++;
		this.SetTeamInternal(TF2_GetEntityTeam(this.Ref), index);
		TF2_SetEntityTeam(this.Ref, team);
	}
	
	public void ChangeToSpectator()
	{
		this.SetTeam(TFTeam_Spectator);
	}
	
	// Creates a history entry regardless of whether we already are in our original team or not
	public void ChangeToOriginalTeam()
	{
		if (this.TeamCount > 0)
		{
			this.SetTeam(this.GetTeamInternal(0));
		}
		else
		{
			this.SetTeam(TF2_GetEntityTeam(this.Ref));
		}
	}
	
	public void ResetTeam()
	{
		int index = --this.TeamCount;
		TFTeam team = this.GetTeamInternal(index);
		TF2_SetEntityTeam(this.Ref, team);
	}
	
	public void CheckArrayBounds(int index)
	{
		if (index < 0 || index >= sizeof(EntityProperties::teamHistory))
		{
			// If you hit this, you have a fatal bug in your code!
			// Ensure that every `SetTeam` call is paired with a `ResetTeam` call.
			SetFailState("Array index out-of-bounds (index %d, limit %d)", index, sizeof(EntityProperties::teamHistory));
		}
	}
	
	public TFTeam GetTeamInternal(int index)
	{
		this.CheckArrayBounds(index);
		
		for (int i = 0; i < sizeof(g_entityProperties); i++)
		{
			EntityProperties properties;
			if (g_entityProperties.GetArray(this.ListIndex, properties))
			{
				return properties.teamHistory[index];
			}
		}
		
		LogError("Failed to get team number for entity %d (index %d)", this, index);
		return TFTeam_Unassigned;
	}
	
	public void SetTeamInternal(TFTeam team, int index)
	{
		this.CheckArrayBounds(index);
		
		int listIndex = this.ListIndex;
		
		for (int i = 0; i < sizeof(g_entityProperties); i++)
		{
			EntityProperties properties;
			if (g_entityProperties.GetArray(listIndex, properties))
			{
				properties.teamHistory[index] = team;
				g_entityProperties.SetArray(listIndex, properties);
				return;
			}
		}
		
		LogError("Failed to set team number for entity %d (index %d)", this, index);
	}
	
	public void Destroy()
	{
		int listIndex = this.ListIndex;
		if (listIndex == -1)
			return;
		
		g_entityProperties.Erase(listIndex);
	}
	
	public static bool IsEntityTracked(int entity)
	{
		int ref = IsValidEdict(entity) ? EntIndexToEntRef(entity) : entity;
		return Entity.IsReferenceTracked(ref);
	}
	
	public static bool IsReferenceTracked(int ref)
	{
		return g_entityProperties.FindValue(ref, EntityProperties::ref) != -1;
	}
	
	public static void Initialize()
	{
		g_entityProperties = new ArrayList(sizeof(EntityProperties));
	}
}
