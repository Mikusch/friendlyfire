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

#define PLUGIN_VERSION	"1.0.2"

#define TICK_NEVER_THINK	-1.0

#define TF_CUSTOM_NONE		0

#define TF_GAMETYPE_ARENA	4

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

bool g_isEnabled;

#include "friendlyfire/convars.sp"
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
	version = PLUGIN_VERSION,
	url = "https://github.com/Mikusch/friendlyfire"
}

public void OnPluginStart()
{
	RegPluginLibrary("friendlyfire");
	
	ConVars_Initialize();
	SDKHooks_Initialize();
	
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
}

public void OnConfigsExecuted()
{
	if (g_isEnabled != mp_friendlyfire.BoolValue)
	{
		TogglePlugin(mp_friendlyfire.BoolValue);
	}
}

public void OnPluginEnd()
{
	if (!g_isEnabled)
		return;
	
	TogglePlugin(!g_isEnabled);
}

public void OnClientPutInServer(int client)
{
	if (!g_isEnabled)
		return;
	
	DHooks_OnClientPutInServer(client);
	SDKHooks_OnClientPutInServer(client);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!g_isEnabled)
		return;
	
	DHooks_OnEntityCreated(entity, classname);
	SDKHooks_OnEntityCreated(entity, classname);
}

public void OnEntityDestroyed(int entity)
{
	if (!g_isEnabled)
		return;
	
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

public Action TF2_OnPlayerTeleport(int client, int teleporter, bool& result)
{
	if (!g_isEnabled)
		return Plugin_Continue;
	
	result = IsObjectFriendly(teleporter, client);
	return Plugin_Handled;
}

void TogglePlugin(bool enable)
{
	g_isEnabled = enable;
	
	ConVars_Toggle(enable);
	DHooks_Toggle(enable);
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		if (enable)
			OnClientPutInServer(client);
		else
			SDKHooks_UnhookClient(client);
	}
}
