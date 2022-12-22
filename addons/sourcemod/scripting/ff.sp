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

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <tf2_stocks>
#include <tf2utils>

#define TF_DMG_CUSTOM_NONE	0

#define TICK_NEVER_THINK	-1.0

enum
{
	COLLISION_GROUP_NONE  = 0,
	COLLISION_GROUP_DEBRIS,			// Collides with nothing but world and static stuff
	COLLISION_GROUP_DEBRIS_TRIGGER, // Same as debris, but hits triggers
	COLLISION_GROUP_INTERACTIVE_DEBRIS,	// Collides with everything except other interactive debris or debris
	COLLISION_GROUP_INTERACTIVE,	// Collides with everything except interactive debris or debris
	COLLISION_GROUP_PLAYER,
	COLLISION_GROUP_BREAKABLE_GLASS,
	COLLISION_GROUP_VEHICLE,
	COLLISION_GROUP_PLAYER_MOVEMENT,  // For HL2, same as Collision_Group_Player, for
										// TF2, this filters out other players and CBaseObjects
	COLLISION_GROUP_NPC,			// Generic NPC group
	COLLISION_GROUP_IN_VEHICLE,		// for any entity inside a vehicle
	COLLISION_GROUP_WEAPON,			// for any weapons that need collision detection
	COLLISION_GROUP_VEHICLE_CLIP,	// vehicle clip brush to restrict vehicle movement
	COLLISION_GROUP_PROJECTILE,		// Projectiles!
	COLLISION_GROUP_DOOR_BLOCKER,	// Blocks entities not permitted to get near moving doors
	COLLISION_GROUP_PASSABLE_DOOR,	// Doors that the player shouldn't collide with
	COLLISION_GROUP_DISSOLVING,		// Things that are dissolving are in this group
	COLLISION_GROUP_PUSHAWAY,		// Nonsolid on client and server, pushaway in player code

	COLLISION_GROUP_NPC_ACTOR,		// Used so NPCs in scripts ignore the player.
	COLLISION_GROUP_NPC_SCRIPTED,	// USed for NPCs in scripts that should not collide with each other

	LAST_SHARED_COLLISION_GROUP
};

enum
{
	SOLID_TO_PLAYER_USE_DEFAULT = 0,
	SOLID_TO_PLAYER_YES,
	SOLID_TO_PLAYER_NO,
};

ConVar mp_friendlyfire;
ConVar tf_avoidteammates;

#include "ff/data.sp"

#include "ff/dhooks.sp"
#include "ff/sdkcalls.sp"
#include "ff/sdkhooks.sp"
#include "ff/util.sp"

public void OnPluginStart()
{
	mp_friendlyfire = FindConVar("mp_friendlyfire");
	tf_avoidteammates = FindConVar("tf_avoidteammates");
	
	GameData gamedata = new GameData("ff");
	if (!gamedata)
	{
		SetFailState("Could not find ff gamedata");
	}
	
	// Initialize everything based on gamedata
	DHooks_Initialize(gamedata);
	SDKCalls_Initialize(gamedata);
	delete gamedata;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			OnClientPutInServer(client);
		}
	}
}

public void OnConfigsExecuted()
{
	mp_friendlyfire.BoolValue = true;
	tf_avoidteammates.BoolValue = false;
}

public void OnPluginEnd()
{
	mp_friendlyfire.RestoreDefault();
	tf_avoidteammates.RestoreDefault();
}

public void OnClientPutInServer(int client)
{
	DHooks_OnClientPutInServer(client);
	SDKHooks_OnClientPutInServer(client);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	DHooks_OnEntityCreated(entity, classname);
	SDKHooks_OnEntityCreated(entity, classname);
}

public Action TF2_OnPlayerTeleport(int client, int teleporter, bool& result)
{
	result = TF2_IsObjectFriendly(teleporter, client);
	return Plugin_Handled;
}

public void OnEntityDestroyed(int entity)
{
	// If an entity was removed prematurely, reset its owner's team as far back as we need to.
	// This can happen with projectiles when they collide with the world, not calling the post-hook.
	for (int i = 0; i < Entity(entity).m_teamCount; i++)
	{
		int owner = FindParentOwnerEntity(entity);
		if (owner != -1)
		{
			Entity(owner).ResetTeam();
		}
	}
	
	Entity(entity).Destroy();
}
