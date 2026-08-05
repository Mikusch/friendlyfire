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
	bool preHookFriendly;
}

int GetEntityRefSafe(int entity)
{
	if (!IsValidEntity(entity))
		return INVALID_ENT_REFERENCE;

	return IsEntNetworkable(entity) ? EntIndexToEntRef(entity) : entity;
}

methodmap Entity
{
	public Entity(int entity)
	{
		int ref = GetEntityRefSafe(entity);
		if (ref == INVALID_ENT_REFERENCE)
		{
			return view_as<Entity>(ref);
		}

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
	
	property bool PreHookFriendly
	{
		public get()
		{
			return g_entityProperties.Get(this.ListIndex, EntityProperties::preHookFriendly) != 0;
		}
		public set(bool friendly)
		{
			g_entityProperties.Set(this.ListIndex, friendly, EntityProperties::preHookFriendly);
		}
	}
	
	public void SetTeam(TFTeam team)
	{
		int listIndex = this.ListIndex;
		if (listIndex == -1)
		{
			LogError("Failed to set team number for untracked entity %d", this);
			return;
		}
		
		EntityProperties properties;
		g_entityProperties.GetArray(listIndex, properties);
		
		this.CheckArrayBounds(properties.teamCount);
		
		properties.teamHistory[properties.teamCount++] = TF2_GetEntityTeam(this.Ref);
		g_entityProperties.SetArray(listIndex, properties);
		
		TF2_SetEntityTeam(this.Ref, team);
	}
	
	public void ChangeToSpectator()
	{
		this.SetTeam(TFTeam_Spectator);
	}
	
	// Creates a history entry regardless of whether we already are in our original team or not
	public void ChangeToOriginalTeam()
	{
		this.SetTeam(this.GetOriginalTeam());
	}
	
	public void ResetTeam()
	{
		int listIndex = this.ListIndex;
		if (listIndex == -1)
		{
			LogError("Failed to get team number for untracked entity %d", this);
			return;
		}
		
		EntityProperties properties;
		g_entityProperties.GetArray(listIndex, properties);
		
		this.CheckArrayBounds(properties.teamCount - 1);
		
		TFTeam team = properties.teamHistory[--properties.teamCount];
		g_entityProperties.SetArray(listIndex, properties);
		
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
	
	public TFTeam GetOriginalTeam()
	{
		return this.TeamCount > 0 ? this.GetTeamInternal(0) : TF2_GetEntityTeam(this.Ref);
	}
	
	public TFTeam GetTeamInternal(int index)
	{
		this.CheckArrayBounds(index);
		
		int listIndex = this.ListIndex;
		if (listIndex == -1)
		{
			LogError("Failed to get team number for entity %d (index %d)", this, index);
			return TFTeam_Unassigned;
		}
		
		EntityProperties properties;
		g_entityProperties.GetArray(listIndex, properties);
		
		return properties.teamHistory[index];
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
		return Entity.IsReferenceTracked(GetEntityRefSafe(entity));
	}
	
	public static bool IsReferenceTracked(int ref)
	{
		return g_entityProperties.FindValue(ref, EntityProperties::ref) != -1;
	}
	
	public static void Init()
	{
		g_entityProperties = new ArrayList(sizeof(EntityProperties));
	}
}

enum struct SpoofFrame
{
	int start;	// index into g_spoofedEntities where this frame begins
	int owner;	// reference of the entity whose hook opened the frame, or INVALID_ENT_REFERENCE
}

static ArrayList g_spoofedEntities;
static ArrayList g_spoofFrames;

void Spoof_Init()
{
	g_spoofedEntities = new ArrayList();
	g_spoofFrames = new ArrayList(sizeof(SpoofFrame));
}

// Every pre-hook using this has to call it before any other return path, so its post-hook always has a frame to close.
void Spoof_BeginFrame(int owner = INVALID_ENT_REFERENCE)
{
	SpoofFrame frame;
	frame.start = g_spoofedEntities.Length;
	frame.owner = GetEntityRefSafe(owner);

	g_spoofFrames.PushArray(frame);
}

void Spoof_EndFrame()
{
	int frames = g_spoofFrames.Length;
	if (!frames)
		return;

	int start = g_spoofFrames.Get(frames - 1, SpoofFrame::start);
	g_spoofFrames.Erase(frames - 1);

	for (int i = g_spoofedEntities.Length - 1; i >= start; i--)
	{
		int ref = g_spoofedEntities.Get(i);
		g_spoofedEntities.Erase(i);

		// The entity may have been removed in-between the two callbacks, taking its team history with it
		if (Entity.IsReferenceTracked(ref))
		{
			view_as<Entity>(ref).ResetTeam();
		}
	}
}

void Spoof_EndFramesForEntity(int entity)
{
	int ref = GetEntityRefSafe(entity);
	if (ref == INVALID_ENT_REFERENCE)
		return;

	while (g_spoofFrames.Length > 0 && g_spoofFrames.Get(g_spoofFrames.Length - 1, SpoofFrame::owner) == ref)
	{
		Spoof_EndFrame();
	}
}

void Spoof_SetTeam(int entity, TFTeam team)
{
	Entity target = Entity(entity);
	
	target.SetTeam(team);
	g_spoofedEntities.Push(target.Ref);
}

void Spoof_ChangeToSpectator(int entity)
{
	Spoof_SetTeam(entity, TFTeam_Spectator);
}

void Spoof_ChangeToOriginalTeam(int entity)
{
	Spoof_SetTeam(entity, Entity(entity).GetOriginalTeam());
}

void Spoof_Clear()
{
	while (g_spoofFrames.Length > 0)
	{
		Spoof_EndFrame();
	}

	// Anything that was spoofed outside of a frame
	for (int i = g_spoofedEntities.Length - 1; i >= 0; i--)
	{
		int ref = g_spoofedEntities.Get(i);
		if (Entity.IsReferenceTracked(ref))
		{
			view_as<Entity>(ref).ResetTeam();
		}
	}

	g_spoofedEntities.Clear();
	g_spoofFrames.Clear();
}
