#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <tf2_stocks>
#include <pluginstatemanager>

#define PLUGIN_VERSION	"2.0.0"

#define TICK_NEVER_THINK	-1.0
#define TF_CUSTOM_NONE		0

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
	TF_PROJECTILE_JAR_GAS,
	TF_PROJECTILE_FLAME_BALL,

	TF_NUM_PROJECTILES
};

bool g_isMapRunning;

ConVar mp_friendlyfire;

ConVar sm_friendlyfire_teammates_are_enemies;

int g_offset_CTakeDamageInfo_m_hAttacker;

#include "friendlyfire/dhooks.sp"
#include "friendlyfire/sdkcalls.sp"
#include "friendlyfire/sdkhooks.sp"
#include "friendlyfire/spoof.sp"
#include "friendlyfire/util.sp"

public Plugin myinfo =
{
	name = "[TF2] Friendly Fire Fix",
	author = "Mikusch",
	description = "Fixes broken interactions during friendly fire in Team Fortress 2.",
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

	PSM_Init("sm_friendlyfire_enabled", gamedata);
	PSM_AddPluginStateChangedHook(OnPluginStateChanged);
	PSM_AddShouldEnableCallback(ShouldEnable);
	
	Spoof_Init();

	ConVars_Init();
	DHooks_Init();
	
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
	
	Spoof_OnEntityDestroyed(entity);

	PSM_SDKUnhook(entity);
}

public Action TF2_OnPlayerTeleport(int client, int teleporter, bool& result)
{
	if (!PSM_IsEnabled())
		return Plugin_Continue;

	if (!AreTeammatesEnemies())
		return Plugin_Continue;

	// Spies can use any Teleporter, see CObjectTeleporter::PlayerCanBeTeleported.
	if (TF2_GetPlayerClass(client) == TFClass_Spy)
		return Plugin_Continue;

	if (IsObjectFriendly(teleporter, client))
		return Plugin_Continue;

	result = false;
	return Plugin_Handled;
}

static void ConVars_Init()
{
	CreateConVar("sm_friendlyfire_enabled", "1", "Enable the plugin?");
	CreateConVar("sm_friendlyfire_version", PLUGIN_VERSION, "Plugin version.", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	sm_friendlyfire_teammates_are_enemies = CreateConVar("sm_friendlyfire_teammates_are_enemies", "0", "When set, your teammates act as enemies and all players are valid targets.", _, true, 0.0, true, 1.0);

	PSM_AddEnforcedConVar("tf_avoidteammates", "0", AreTeammatesEnemies, sm_friendlyfire_teammates_are_enemies);
	PSM_AddEnforcedConVar("tf_spawn_glows_duration", "0", AreTeammatesEnemies, sm_friendlyfire_teammates_are_enemies);
	PSM_AddConVarChangeHook(sm_friendlyfire_teammates_are_enemies, OnTeammatesAreEnemiesChanged);

	mp_friendlyfire = FindConVar("mp_friendlyfire");
	mp_friendlyfire.AddChangeHook(OnFriendlyFireChanged);
}

static void OnPluginStateChanged(bool enable)
{
	if (!g_isMapRunning)
		return;

	if (enable)
	{
		int entity = -1;
		while ((entity = FindEntityByClassname(entity, "*")) != -1)
		{
			char classname[64];
			if (!GetEntityClassname(entity, classname, sizeof(classname)))
				continue;

			OnEntityCreated(entity, classname);
		}
	}
	else
	{
		Spoof_Clear();
	}

	SetAllObjectsSolidToPlayers(enable && AreTeammatesEnemies());
}

static bool ShouldEnable()
{
	return mp_friendlyfire.BoolValue;
}

bool AreTeammatesEnemies()
{
	return sm_friendlyfire_teammates_are_enemies.BoolValue;
}

static void OnFriendlyFireChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	PSM_TogglePluginState();
}

static void OnTeammatesAreEnemiesChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!PSM_IsEnabled() || !g_isMapRunning)
		return;

	SetAllObjectsSolidToPlayers(AreTeammatesEnemies());
}
