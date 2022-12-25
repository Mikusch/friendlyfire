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

#define TICK_NEVER_THINK	-1.0
#define TF_DMG_CUSTOM_NONE	0

enum
{
	SOLID_TO_PLAYER_USE_DEFAULT = 0,
	SOLID_TO_PLAYER_YES,
	SOLID_TO_PLAYER_NO,
};

enum
{
	TF_PROJECTILE_NONE,
	TF_PROJECTILE_BULLET,
	TF_PROJECTILE_ROCKET,
	TF_PROJECTILE_PIPEBOMB,
	TF_PROJECTILE_PIPEBOMB_REMOTE,
	TF_PROJECTILE_SYRINGE,
	TF_PROJECTILE_FLARE,
	TF_PROJECTILE_JAR,
	TF_PROJECTILE_ARROW,
	TF_PROJECTILE_FLAME_ROCKET,
	TF_PROJECTILE_JAR_MILK,
	TF_PROJECTILE_HEALING_BOLT,
	TF_PROJECTILE_ENERGY_BALL,
	TF_PROJECTILE_ENERGY_RING,
	TF_PROJECTILE_PIPEBOMB_PRACTICE,
	TF_PROJECTILE_CLEAVER,
	TF_PROJECTILE_STICKY_BALL,
	TF_PROJECTILE_CANNONBALL,
	TF_PROJECTILE_BUILDING_REPAIR_BOLT,
	TF_PROJECTILE_FESTIVE_ARROW,
	TF_PROJECTILE_THROWABLE,
	TF_PROJECTILE_SPELL,
	TF_PROJECTILE_FESTIVE_JAR,
	TF_PROJECTILE_FESTIVE_HEALING_BOLT,
	TF_PROJECTILE_BREADMONSTER_JARATE,
	TF_PROJECTILE_BREADMONSTER_MADMILK,

	TF_PROJECTILE_GRAPPLINGHOOK,
	TF_PROJECTILE_SENTRY_ROCKET,
	TF_PROJECTILE_BREAD_MONSTER,

	TF_NUM_PROJECTILES
};

ConVar mp_friendlyfire;
ConVar tf_avoidteammates;
ConVar tf_spawn_glows_duration;

#include "friendlyfire/data.sp"
#include "friendlyfire/dhooks.sp"
#include "friendlyfire/sdkcalls.sp"
#include "friendlyfire/sdkhooks.sp"
#include "friendlyfire/util.sp"

public Plugin myinfo =
{
	name = "[TF2] Fixed Friendly Fire",
	author = "Mikusch",
	description = "Fixes mp_friendlyfire in Team Fortress 2.",
	version = "1.0.0",
	url = "https://github.com/Mikusch/friendlyfire"
}

public void OnPluginStart()
{
	mp_friendlyfire = FindConVar("mp_friendlyfire");
	mp_friendlyfire.AddChangeHook(ConVarChanged_FriendlyFire);
	tf_avoidteammates = FindConVar("tf_avoidteammates");
	tf_spawn_glows_duration = FindConVar("tf_spawn_glows_duration");
	
	RegPluginLibrary("friendlyfire");
	
	GameData gamedata = new GameData("friendlyfire");
	if (gamedata)
	{
		DHooks_Initialize(gamedata);
		SDKCalls_Initialize(gamedata);
		delete gamedata;
	}
	else
	{
		SetFailState("Could not find friendlyfire gamedata");
	}
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			OnClientPutInServer(client);
		}
	}
}

void ConVarChanged_FriendlyFire(ConVar convar, const char[] oldValue, const char[] newValue)
{
	OnFriendlyFireChanged(convar.BoolValue);
}

public void OnConfigsExecuted()
{
	OnFriendlyFireChanged(mp_friendlyfire.BoolValue);
}

public void OnPluginEnd()
{
	OnFriendlyFireChanged(false);
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
	result = IsObjectFriendly(teleporter, client);
	return Plugin_Handled;
}

public void OnEntityDestroyed(int entity)
{
	if (!IsValidEntity(entity))
		return;
	
	// If an entity was removed prematurely, reset its owner's team as far back as we need to.
	// This can happen with projectiles when they collide with the world, not calling the post-hook.
	for (int i = 0; i < Entity(entity).TeamCount; i++)
	{
		int owner = FindParentOwnerEntity(entity);
		if (owner != -1)
		{
			Entity(owner).ResetTeam();
		}
	}
	
	Entity(entity).Destroy();
}

static void OnFriendlyFireChanged(bool enabled)
{
	if (enabled)
	{
		tf_avoidteammates.BoolValue = false;
		tf_spawn_glows_duration.IntValue = 0;
	}
	else
	{
		tf_avoidteammates.RestoreDefault();
		tf_spawn_glows_duration.RestoreDefault();
	}
}
