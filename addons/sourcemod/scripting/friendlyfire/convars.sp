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

#define COMMAND_MAX_LENGTH	512

enum struct ConVarData
{
	char name[COMMAND_MAX_LENGTH];
	char value[COMMAND_MAX_LENGTH];
	char initialValue[COMMAND_MAX_LENGTH];
	bool enforce;
}

static StringMap g_conVars;

void ConVars_Initialize()
{
	g_conVars = new StringMap();
	
	CreateConVar("sm_friendlyfire_version", PLUGIN_VERSION, "Plugin version.", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	sm_friendlyfire_medic_allow_healing = CreateConVar("sm_friendlyfire_medic_allow_healing", "0", "Whether Medics are allowed to heal teammates during friendly fire.", _, true, 0.0, true, 1.0);
	
	mp_friendlyfire = FindConVar("mp_friendlyfire");
	mp_friendlyfire.AddChangeHook(ConVarChanged_FriendlyFire);
	
	ConVars_AddConVar("tf_avoidteammates", "0");
	ConVars_AddConVar("tf_spawn_glows_duration", "0");
}

void ConVars_Toggle(bool enable)
{
	if (enable)
	{
		mp_friendlyfire.AddChangeHook(ConVarChanged_FriendlyFire);
	}
	else
	{
		mp_friendlyfire.RemoveChangeHook(ConVarChanged_FriendlyFire);
	}
	
	StringMapSnapshot snapshot = g_conVars.Snapshot();
	for (int i = 0; i < snapshot.Length; i++)
	{
		int size = snapshot.KeyBufferSize(i);
		char[] key = new char[size];
		snapshot.GetKey(i, key, size);
		
		if (enable)
			ConVars_Enable(key);
		else
			ConVars_Disable(key);
	}
	delete snapshot;
}

static void ConVars_AddConVar(const char[] name, const char[] value, bool enforce = true)
{
	ConVar convar = FindConVar(name);
	if (convar)
	{
		// Store ConVar information
		ConVarData info;
		strcopy(info.name, sizeof(info.name), name);
		strcopy(info.value, sizeof(info.value), value);
		info.enforce = enforce;
		
		g_conVars.SetArray(name, info, sizeof(info));
	}
	else
	{
		LogError("Failed to find convar with name %s", name);
	}
}

static void ConVars_Enable(const char[] name)
{
	ConVarData data;
	if (g_conVars.GetArray(name, data, sizeof(data)))
	{
		ConVar convar = FindConVar(data.name);
		
		// Store the current value so we can later reset the ConVar to it
		convar.GetString(data.initialValue, sizeof(data.initialValue));
		g_conVars.SetArray(name, data, sizeof(data));
		
		// Update the current value
		convar.SetString(data.value);
		convar.AddChangeHook(OnConVarChanged);
	}
}

static void ConVars_Disable(const char[] name)
{
	ConVarData data;
	if (g_conVars.GetArray(name, data, sizeof(data)))
	{
		ConVar convar = FindConVar(data.name);
		
		g_conVars.SetArray(name, data, sizeof(data));
		
		// Restore the convar value
		convar.RemoveChangeHook(OnConVarChanged);
		convar.SetString(data.initialValue);
	}
}

static void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char name[COMMAND_MAX_LENGTH];
	convar.GetName(name, sizeof(name));
	
	ConVarData data;
	if (g_conVars.GetArray(name, data, sizeof(data)))
	{
		if (!StrEqual(newValue, data.value))
		{
			strcopy(data.initialValue, sizeof(data.initialValue), newValue);
			g_conVars.SetArray(name, data, sizeof(data));
			
			// Restore our value if needed
			if (data.enforce)
				convar.SetString(data.value);
		}
	}
}

static void ConVarChanged_FriendlyFire(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_isEnabled != convar.BoolValue)
	{
		TogglePlugin(convar.BoolValue);
	}
}
