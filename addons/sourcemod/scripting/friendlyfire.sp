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
#include <pluginstatemanager>

#define PLUGIN_VERSION	"1.4.1"

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

bool g_isMapRunning;

ConVar mp_friendlyfire;

ConVar sm_friendlyfire_medic_allow_healing;

int g_offset_CTakeDamageInfo_m_hAttacker;

#include "friendlyfire/dhooks.sp"
#include "friendlyfire/entity.sp"
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
	
	GameData gamedata = new GameData("friendlyfire");
	if (!gamedata)
		SetFailState("Could not find friendlyfire gamedata");

	g_offset_CTakeDamageInfo_m_hAttacker = GameConfGetOffsetOrElseThrow(gamedata, "CTakeDamageInfo::m_hAttacker");

	PSM_Init("sm_friendlyfire", gamedata);
	PSM_AddPluginStateChangedHook(OnPluginStateChanged);
	PSM_AddShouldEnableCallback(ShouldEnable);
	
	Entity.Init();
	
	ConVars_Init();
	DHooks_Init();
	SDKHooks_Init();
	
	SDKCalls_Init(gamedata);
	
	delete gamedata;
}

public void OnMapStart()
{
	g_isMapRunning = true;
}

public void OnMapEnd()
{
	g_isMapRunning = false;
}

public void OnConfigsExecuted()
{
	PSM_TogglePluginState();
}

public void OnPluginEnd()
{
	PSM_SetPluginState(false);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!PSM_IsEnabled() || !g_isMapRunning)
		return;
	
	DHooks_OnEntityCreated(entity, classname);
	SDKHooks_OnEntityCreated(entity, classname);
}

public void OnEntityDestroyed(int entity)
{
	if (!PSM_IsEnabled())
		return;
	
	PSM_SDKUnhook(entity);
	
	if (Entity.IsEntityTracked(entity))
	{
		Entity obj = Entity(entity);
		
		// If an entity is removed while it still has a team history, we need to reset its owner's team.
		// This can happen if the entity is deleted in-between pre-hook and post-hook callbacks e.g. from a projectile that collided with worldspawn.
		for (int i = 0; i < obj.TeamCount; i++)
		{
			int owner = FindParentOwnerEntity(entity);
			if (owner != -1)
				Entity(owner).ResetTeam();
		}
		
		obj.Destroy();
	}
}

public Action TF2_OnPlayerTeleport(int client, int teleporter, bool& result)
{
	if (!PSM_IsEnabled())
		return Plugin_Continue;
	
	result = IsObjectFriendly(teleporter, client);
	return Plugin_Handled;
}

static void ConVars_Init()
{
	CreateConVar("sm_friendlyfire", "1", "Enable the plugin?");
	CreateConVar("sm_friendlyfire_version", PLUGIN_VERSION, "Plugin version.", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	CreateConVar("sm_friendlyfire_avoidteammates", "0", "Controls how teammates interact when colliding.\n  0: Teammates block each other\n  1: Teammates pass through each other, but push each other away", _, true, 0.0, true, 1.0);
	sm_friendlyfire_medic_allow_healing = CreateConVar("sm_friendlyfire_medic_allow_healing", "0", "Whether Medics are allowed to heal teammates during friendly fire.", _, true, 0.0, true, 1.0);
	
	PSM_AddSyncedConVar("tf_avoidteammates", "sm_friendlyfire_avoidteammates");
	PSM_AddEnforcedConVar("tf_spawn_glows_duration", "0");

	mp_friendlyfire = FindConVar("mp_friendlyfire");
	mp_friendlyfire.AddChangeHook(OnFriendlyFireChanged);
}

static void OnPluginStateChanged(bool enable)
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "*")) != -1)
	{
		if (enable)
		{
			char classname[64];
			if (!GetEntityClassname(entity, classname, sizeof(classname)))
				continue;
			
			OnEntityCreated(entity, classname);
		}
		else
		{
			if (Entity.IsEntityTracked(entity))
				Entity(entity).Destroy();
		}
	}
}

static bool ShouldEnable()
{
	return mp_friendlyfire.BoolValue;
}

static void OnFriendlyFireChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	PSM_TogglePluginState();
}
